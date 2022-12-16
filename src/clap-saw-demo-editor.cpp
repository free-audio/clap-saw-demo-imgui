//
// Created by Paul Walker on 6/10/22.
//

#include "clap-saw-demo-editor.h"
#include "clap-saw-demo.h"
#include "clap/clap.h"

#include "imgui.h"

#define STR_INDIR(x) #x
#define STR(x) STR_INDIR(x)

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
    *width = 540;
    *height = 324;
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

void ClapSawDemoEditor::addSliderForParam(clap_id pid, const char* label, float min, float max)
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
}

void ClapSawDemoEditor::addSwitchForParam(clap_id pid, const char* label, bool reverse)
{
    bool co;
    
    if (reverse)
        co = paramCopy[pid] > 0.5f ? false : true;
    else
        co = paramCopy[pid] < 0.5f ? false : true;
    
    if (ImGui::Checkbox(label, &co))
    {
        auto q = ClapSawDemo::FromUI();
        q.id = pid;
        q.type = ClapSawDemo::FromUI::MType::ADJUST_VALUE;
        if (reverse)
            q.value = co ? 0.f : 1.f;
        else
            q.value = co ? 1.f : 0.f;
        outbound.try_enqueue(q);
        paramCopy[pid] = q.value;
    }
}

void ClapSawDemoEditor::addRadioButtonForParam(clap_id pid, std::vector<std::pair<int, const char*>> modes)
{
    int prevMode = paramCopy[pid];
    int editMode = prevMode;
    for (const auto& mode : modes)
    {
        ImGui::RadioButton(mode.second, &editMode, mode.first); ImGui::SameLine();
    }
    ImGui::NewLine();
    
    if (prevMode != editMode)
    {
        auto q = ClapSawDemo::FromUI();
        q.id = pid;
        q.type = ClapSawDemo::FromUI::MType::ADJUST_VALUE;
        q.value = editMode;
        outbound.try_enqueue(q);
        paramCopy[pid] = editMode;
    }
    
}

void ClapSawDemoEditor::dequeueParamUpdates()
{
    ClapSawDemo::ToUI r;
    while (inbound.try_dequeue(r))
    {
        if (r.type == ClapSawDemo::ToUI::MType::PARAM_VALUE)
        {
            paramCopy[r.id] = r.value;
            paramInEdit[r.id] = false;
        }
    }
}

void ClapSawDemoEditor::onRender()
{
    dequeueParamUpdates(); // Do not remove this

    ImGuiIO& io = ImGui::GetIO(); (void)io;
    
    bool is_open = true;
    ImGui::Begin("Imgui Saw Demo", &is_open , ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize |
                 ImGuiWindowFlags_NoDecoration);

    ImDrawList* draw_list = ImGui::GetWindowDrawList();
    
    // HEADER
    std::string titleStr = "CLAP SAW DEMO IMGUI";
        
    ImColor col32(.16f, .29f, .48f , 0.54f * 0.5f);
    draw_list->AddRectFilled(ImVec2(0, 0), ImVec2(ImGui::GetWindowWidth(), 26.f), col32);
    
    const char* title = titleStr.c_str();
    auto titleSize = ImGui::CalcTextSize(title);
    ImGui::SetCursorPosX( (ImGui::GetWindowWidth() - titleSize.x) / 2.f);

    ImGui::Text( "%s", title );

    ImGui::Separator();
    
    // PARAMETER UI
    
    ImGui::Text("Osc (Polyphony %d)", (int)synthData.polyphony);

    addSliderForParam(ClapSawDemo::pmUnisonCount, "uni count", 1, SawDemoVoice::max_uni);
    addSliderForParam(ClapSawDemo::pmUnisonSpread, "uni spread", 0, 100);
    addSliderForParam(ClapSawDemo::pmOscDetune, "osc detune", -200, 200);

    ImGui::Separator();
    
    addSliderForParam(ClapSawDemo::pmPreFilterVCA, "VCA", 0, 1);
    addSwitchForParam(ClapSawDemo::pmAmpIsGate, "Amp Envelope", true);
    
    ImGui::BeginDisabled(paramCopy[ClapSawDemo::pmAmpIsGate] > 0.5f);
    addSliderForParam(ClapSawDemo::pmAmpAttack, "Attack", 0, 1);
    addSliderForParam(ClapSawDemo::pmAmpRelease, "Release", 0, 1);
    ImGui::EndDisabled();
    
    ImGui::Separator();
    
    ImGui::Text("Filter");
    
    addRadioButtonForParam(ClapSawDemo::pmFilterMode, {
        { SawDemoVoice::StereoSimperSVF::Mode::LP, "LP"},
        { SawDemoVoice::StereoSimperSVF::Mode::BP, "BP"},
        { SawDemoVoice::StereoSimperSVF::Mode::HP, "HP"},
        { SawDemoVoice::StereoSimperSVF::Mode::NOTCH, "Notch"},
        { SawDemoVoice::StereoSimperSVF::Mode::PEAK, "Peak"},
        { SawDemoVoice::StereoSimperSVF::Mode::ALL, "All"} } );
    
    addSliderForParam(ClapSawDemo::pmCutoff, "cutoff", 1, 127);
    addSliderForParam(ClapSawDemo::pmResonance, "resonance", 0, 1);

    ImGui::Separator();

    // FOOTER
    
    std::string footerStr = "CLAP v";
    footerStr += std::to_string(CLAP_VERSION_MAJOR);
    footerStr += ".";
    footerStr += std::to_string(CLAP_VERSION_MINOR);
    footerStr += ".";
    footerStr += std::to_string(CLAP_VERSION_REVISION);
    footerStr += " - ";
    footerStr += io.BackendRendererName;
    footerStr += " - ";
    footerStr += io.BackendPlatformName;
    
    draw_list->AddRectFilled(ImVec2(0, ImGui::GetCursorPosY() - 6.f), ImVec2(ImGui::GetWindowWidth(), ImGui::GetCursorPosY()+26.f-6.f), col32);
 
    const char* footer = footerStr.c_str();
    ImGui::SetCursorPosX( (ImGui::GetWindowWidth() - ImGui::CalcTextSize(footer).x) / 2.f);
    ImGui::Text( "%s", footer );
}

} // namespace sst::clap_saw_demo
