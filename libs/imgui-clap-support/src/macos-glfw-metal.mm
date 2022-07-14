#include "imgui-clap-support/imgui-clap-editor.h"

#include <Foundation/Foundation.h>
#include <Cocoa/Cocoa.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>

#define GLFW_INCLUDE_NONE
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#include "imgui.h"
#include "backends/imgui_impl_metal.h"
#include "backends/imgui_impl_glfw.h"

#include <iostream>
#include <iomanip>


static void glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "Glfw Error %d: %s\n", error, description);
}

@interface icsGlfwMetal : MTKView<MTKViewDelegate>
@property imgui_clap_editor* editor;
@property CFRunLoopTimerRef idleTimer;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@property ImGuiContext *imguiContext;

- (id)initWithEditor:(imgui_clap_editor *)ed  withParent:(NSView *)v;
- (void) startTimer;
- (void) stopTimer;
- (void) doIdle;
@end

void timerCallback(CFRunLoopTimerRef timer, void *info)
{
    icsGlfwMetal *view = (icsGlfwMetal *)info;
    [view doIdle];
}

@implementation  icsGlfwMetal
- (id)initWithEditor:(imgui_clap_editor *)ed withParent:(NSView *)v
{
    self = [super initWithFrame:[v bounds]];

    _editor = ed;

    self.device = MTLCreateSystemDefaultDevice();
    self.delegate = self;
    _commandQueue = [self.device newCommandQueue];

    IMGUI_CHECKVERSION();
    _imguiContext = ImGui::CreateContext();
    ImGui::SetCurrentContext(_imguiContext);
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit())
        return nil;


    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
    glfwWindowHint(GLFW_DECORATED, GLFW_FALSE);
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
    GLFWwindow* window = glfwCreateWindow(1, 1, "Dear ImGui GLFW+Metal example", NULL, NULL);
    if (window == NULL)
        return nil;

    // Setup Renderer backend
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplMetal_Init(self.device);

    NSWindow *par = [v window];
    NSWindow *win = (NSWindow*)glfwGetCocoaWindow(window);
    [par addChildWindow:win ordered:NSWindowAbove];

    _idleTimer = nil;

    return self;
}

- (void)startTimer
{
    CFTimeInterval TIMER_INTERVAL = 1.0 / 60.0; // In SurgeGUISynthesizer.h it uses 50 ms
    CFRunLoopTimerContext TimerContext = {0, self, NULL, NULL, NULL};
    CFAbsoluteTime FireTime = CFAbsoluteTimeGetCurrent() + TIMER_INTERVAL;

    _idleTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, FireTime, TIMER_INTERVAL, 0, 0,
                                     timerCallback, &TimerContext);

    if (_idleTimer)
        CFRunLoopAddTimer(CFRunLoopGetMain(), _idleTimer, kCFRunLoopCommonModes);
}

- (void)stopTimer
{
    if (_idleTimer)
    {
        CFRunLoopRemoveTimer(CFRunLoopGetMain(), _idleTimer, kCFRunLoopCommonModes);
    }
    // At some point - last one out - we should delete the context
}

- (void)doIdle
{
    ImGui::SetCurrentContext(_imguiContext);
    [self setNeedsDisplay:YES];
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    std::cout << "RENDERING " << std::endl;
    ImGui::SetCurrentContext(_imguiContext);
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.backingScaleFactor ?: NSScreen.mainScreen.backingScaleFactor;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor == nil)
    {
        [commandBuffer commit];
        return;
    }

    glfwPollEvents();

    // Start the Dear ImGui frame
    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui_ImplGlfw_NewFrame();

    ImGui::NewFrame();

    self.editor->onRender();

    ImGui::Render();
    ImDrawData* draw_data = ImGui::GetDrawData();

    static ImVec4 clear_color = ImVec4(0.7f, 0.3f, 0.3f, 1.00f);
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder pushDebugGroup:@"Dear ImGui rendering"];
    ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];

    // Present
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size;
{
}
@end


bool imgui_clap_guiCreateWith(imgui_clap_editor *e,
                              const clap_host_timer_support_t *)
{
    IMGUI_CHECKVERSION();
    e->onGuiCreate();
    return true;
}
void imgui_clap_guiDestroyWith(imgui_clap_editor *e,
                               const clap_host_timer_support_t *)
{
    e->onGuiDestroy();
    auto mwin = (icsGlfwMetal *)(e->ctx);
    [mwin stopTimer];
    [mwin release];
    e->ctx = nullptr;
}
bool imgui_clap_guiSetParentWith(imgui_clap_editor *ed,
                                 const clap_window *win)
{
    auto nsv = (NSView *)win->cocoa;
    auto mwin = [[icsGlfwMetal alloc] initWithEditor:ed withParent: nsv];
    [nsv addSubview:mwin];
    [mwin startTimer];
    ed->ctx = mwin;

    return true;
}
bool imgui_clap_guiSetSizeWith(imgui_clap_editor *ed, int width, int height)
{
    auto mwin = (icsGlfwMetal *)(ed->ctx);
    [mwin setBounds:NSMakeRect(0, 0, width, height)];
    return true;
}