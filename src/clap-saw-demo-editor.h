//
// Created by Paul Walker on 6/10/22.
//

#ifndef CLAP_SAW_DEMO_EDITOR_H
#define CLAP_SAW_DEMO_EDITOR_H
#include "clap-saw-demo.h"
#include "imgui-clap-support/imgui-clap-editor.h"

namespace sst::clap_saw_demo
{
struct ClapSawDemoEditor : public imgui_clap_editor
{
    ClapSawDemoEditor() = default;

    void onRender() override;
};
} // namespace sst::clap_saw_demo
#endif
