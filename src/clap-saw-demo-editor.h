//
// Created by Paul Walker on 6/10/22.
//

#ifndef CLAP_SAW_DEMO_EDITOR_H
#define CLAP_SAW_DEMO_EDITOR_H
#include "clap-saw-demo.h"
#include "imgui-clap-support/imgui-clap-editor.h"
#include <unordered_map>

namespace sst::clap_saw_demo
{

struct ClapSawDemoEditor : public imgui_clap_editor
{
    ClapSawDemoEditor(ClapSawDemo::SynthToUI_Queue_t &, ClapSawDemo::UIToSynth_Queue_t &,
                      const ClapSawDemo::DataCopyForUI &, std::function<void()>);
    
    // Write your ImGui Code here
    void onRender() override;
    
    // GUI Helper functions

    // create a slider with start/end edit messagess
    void addSliderForParam(clap_id pid, const char* label, float min, float max);
    // a on/off switch for a parameter
    void addSwitchForParam(clap_id pid, const char* label, bool reverse);
    // this creates a radio button in one layout line
    void addRadioButtonForParam(clap_id pid, std::vector<std::pair<int, const char*>>);
    
    // Parameter Queues
    
    // queues for parameter updates from UI to DSP and other way round
    ClapSawDemo::SynthToUI_Queue_t &inbound;
    ClapSawDemo::UIToSynth_Queue_t &outbound;
    const ClapSawDemo::DataCopyForUI &synthData;
    std::function<void()> paramRequestFlush;
    
    // update the parameter state for UI, has to be called each frame
    void dequeueParamUpdates();

    // state copy of parameter values/edit state for UI
    std::unordered_map<clap_id, double> paramCopy;
    std::unordered_map<clap_id, bool> paramInEdit;
};

} // namespace sst::clap_saw_demo
#endif
