//
// Created by Paul Walker on 6/10/22.
//

#include "clap-saw-demo-editor.h"
#include "clap-saw-demo.h"

#include "imgui.h"

namespace sst::clap_saw_demo
{
/*
 * Part one of this implementation is the plugin adapters which allow a GUI to attach.
 * These are the ClapSawDemo methods. First up: Which windowing API do we support.
 * Pretty obviously, mac supports cocoa, windows supports win32, and linux supports
 * X11.
 */
bool ClapSawDemo::guiIsApiSupported(const char *api, bool isFloating) noexcept
{
    if (isFloating)
        return false;
#if IS_MAC
    if (strcmp(api, CLAP_WINDOW_API_COCOA) == 0)
        return true;
#endif

#if IS_WIN
    if (strcmp(api, CLAP_WINDOW_API_WIN32) == 0)
        return true;
#endif

#if IS_LINUX
    if (strcmp(api, CLAP_WINDOW_API_X11) == 0)
        return true;
#endif

    return false;
}

/*
 * GUICreate gets called when the host requests the plugin create its editor with
 * a given API. We ignore the API and isFloating here, because we handled them
 * above and assume our host follows the protocol that it only calls us with
 * values which are supported.
 *
 * The important thing from a VSTGUI perspective here is that we have to initialize
 * the VSTGUI static data structures. On Mac and Windows, this is an easy call and
 * we can use the VSTGUI::finally mechanism to clean up. On Linux there is a more
 * complicated global event loop to merge which, thanks to the way VSTGUI structures
 * their event loops, is a touch more awkward. As such the linux code is all in a different
 * cpp file for individual documentation (Please see the README for any linux disclaimers
 * and most recent status).
 */
bool ClapSawDemo::guiCreate(const char *api, bool isFloating) noexcept
{
    _DBGMARK;
    assert(!editor);
    editor = new ClapSawDemoEditor(toUiQ, fromUiQ, dataCopyForUI, [this]() { editorParamsFlush(); });
    const clap_host_timer_support_t *timer{nullptr};
    _host.getExtension(timer, CLAP_EXT_TIMER_SUPPORT);
    return imgui_clap_guiCreateWith(editor, timer);
}

/*
 * guiDestroy destroys the editor object and returns it to the
 * nullptr sentinel, to stop ::process sending events to the ui.
 */
void ClapSawDemo::guiDestroy() noexcept
{
    assert(editor);
    const clap_host_timer_support_t *timer{nullptr};
    _host.getExtension(timer, CLAP_EXT_TIMER_SUPPORT);
    imgui_clap_guiDestroyWith(editor, timer);
    delete editor;
    editor = nullptr;
}

/*
 * guiSetParent is the core API for a clap HOST which has a window to
 * reparent the editor to that host managed window. It sends a
 * `const clap_window *window` data structure which contains a union of
 * platform specific window pointers.
 *
 * VSTGUI handles reparenting through `VSTGUI::CFrame::open` which consumes
 * a pointer to a native window. This makes adapting easy. Our editor object
 * owns a `CFrame` as its base window, and setParent opens it with the new
 * parent platform specific item handed to it.
 */
bool ClapSawDemo::guiSetParent(const clap_window *window) noexcept
{
    assert(editor);
    auto res = imgui_clap_guiSetParentWith(editor, window);
    if (!res)
        return false;

    if (dataCopyForUI.isProcessing)
    {
        // and ask the engine to refresh from the processing thread
        refreshUIValues = true;
    }
    else
    {
        // Pull the parameters on the main thread
        for (const auto &[k, v] : paramToValue)
        {
            auto r = ToUI();
            r.type = ToUI::PARAM_VALUE;
            r.id = k;
            r.value = *v;
            toUiQ.try_enqueue(r);
        }
    }
    // And we are done!
    return true;
}

/*
 * guiSetScale is the core API that allows the Host to set the absolute GUI
 * scaling factor, and override any OS info. This is important to allow the UI
 * to correctly reflect what has been specified by the Host and not have to
 * work out the users intentions through some sort of magic.
 *
 * Obviously, the value will depend on how the host chooses to implement it.
 * The value is normalised, with 1.0 representing 100% scaling.
 */
bool ClapSawDemo::guiSetScale(double scale) noexcept
{
    _DBGCOUT << _D(scale) << std::endl;
    return false;
}

/*
 * Sizing is described in the gui extension, but this implementation
 * means that if the host drags to resize, we accept its size and resize our frame
 */
bool ClapSawDemo::guiSetSize(uint32_t width, uint32_t height) noexcept
{
    _DBGCOUT << _D(width) << _D(height) << std::endl;
    assert(editor);
    return imgui_clap_guiSetSizeWith(editor, width, height);
}

/*
 * Returns the size of the UI window, presumable so a host can better layout plugin UIs
 * if grouped together.
 */
bool ClapSawDemo::guiGetSize(uint32_t *width, uint32_t *height) noexcept
{
    *width = 700;
    *height = 500;
    return true;
}


bool ClapSawDemo::guiAdjustSize(uint32_t *width, uint32_t *height) noexcept
{
    return true;
}

ClapSawDemoEditor::ClapSawDemoEditor(ClapSawDemo::SynthToUI_Queue_t &i,
                                     ClapSawDemo::UIToSynth_Queue_t &o,
                                     const ClapSawDemo::DataCopyForUI &d, std::function<void()> pf)
: inbound(i), outbound(o), synthData(d), paramRequestFlush(std::move(pf))
{

}
void ClapSawDemoEditor::onRender() {
    ClapSawDemo::ToUI r;
    while (inbound.try_dequeue(r))
    {
        if (r.type == ClapSawDemo::ToUI::MType::PARAM_VALUE)
        {
            paramCopy[r.id] = r.value;
            paramInEdit[r.id] = false;
        }
    }

    ImGuiViewport* viewport = ImGui::GetMainViewport();
    ImGui::SetNextWindowPos(viewport->WorkPos);
    ImGui::SetNextWindowSize(viewport->WorkSize);

    bool is_open = true;
    ImGui::Begin("Imgui Saw Demo", &is_open , ImGuiWindowFlags_NoTitleBar);
    const char* title = "Imgui Saw Demo";
    ImGui::SetCursorPosX( (ImGui::GetWindowWidth() - ImGui::CalcTextSize(title).x) / 2.f);
    ImGui::Text( "%s", title );
    ImGui::Text( "Polyphony is %d", (int)synthData.polyphony);

    auto makeSliderForParam = [this](auto pid, const char* label, float min, float max)
    {
        float co = paramCopy[pid];
        auto wasInEdit = paramInEdit[pid];
        if (ImGui::SliderFloat(label, &co, min, max))
        {
            if (!wasInEdit)
            {
                paramInEdit[pid] = true;
                auto q = ClapSawDemo::FromUI();
                q.id = pid;
                q.type = ClapSawDemo::FromUI::MType::BEGIN_EDIT;
                q.value = co;
                outbound.try_enqueue(q);
            }
            if (co != paramCopy[pid])
            {
                auto q = ClapSawDemo::FromUI();
                q.id = pid;
                q.type = ClapSawDemo::FromUI::MType::ADJUST_VALUE;
                q.value = co;
                outbound.try_enqueue(q);
                paramCopy[pid] = co;
            }
        }
        else
        {
            if (wasInEdit)
            {
                paramInEdit[pid] = false;
                auto q = ClapSawDemo::FromUI();
                q.id = pid;
                q.type = ClapSawDemo::FromUI::MType::END_EDIT;
                q.value = co;
                outbound.try_enqueue(q);
            }
        }
    };

    makeSliderForParam(ClapSawDemo::pmUnisonCount, "uni count", 1, SawDemoVoice::max_uni);
    makeSliderForParam(ClapSawDemo::pmUnisonSpread, "uni spread", 0, 100);
    makeSliderForParam(ClapSawDemo::pmOscDetune, "osc detune", -200, 200);

    makeSliderForParam(ClapSawDemo::pmCutoff, "cutoff", 1, 127);
    makeSliderForParam(ClapSawDemo::pmResonance, "resonance", 0, 1);

    ImGui::End();
}

} // namespace sst::clap_saw_demo
