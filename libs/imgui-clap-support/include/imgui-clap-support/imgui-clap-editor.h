//
// Created by Paul Walker on 7/13/22.
//

#ifndef CLAP_SAW_DEMO_IMGUI_IMGUI_CLAP_EDITOR_H
#define CLAP_SAW_DEMO_IMGUI_IMGUI_CLAP_EDITOR_H

#include <memory>
#include "clap/ext/timer-support.h"
#include "clap/ext/gui.h"

struct imgui_clap_editor
{
    virtual ~imgui_clap_editor() = default;
    virtual void onGuiCreate() {}
    virtual void onGuiDestroy() {}
    virtual void onRender() {}

    void *ctx{nullptr};
};

bool imgui_clap_guiCreateWith(imgui_clap_editor *,
                              const clap_host_timer_support_t *);
void imgui_clap_guiDestroyWith(imgui_clap_editor *,
                               const clap_host_timer_support_t *);
bool imgui_clap_guiSetParentWith(imgui_clap_editor *,
                                 const clap_window *);
bool imgui_clap_guiSetSizeWith(imgui_clap_editor *, int width, int height);

#endif // CLAP_SAW_DEMO_IMGUI_IMGUI_CLAP_EDITOR_H
