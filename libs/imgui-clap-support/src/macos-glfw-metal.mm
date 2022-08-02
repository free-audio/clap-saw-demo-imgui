#include "imgui-clap-support/imgui-clap-editor.h"

#include <functional>

#define Mac_GLFW_Metal 1

#if Mac_GLFW_Metal
#include <Foundation/Foundation.h>
#include <Cocoa/Cocoa.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#define GLFW_EXPOSE_NATIVE_COCOA
#endif

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#include "imgui.h"
#include "backends/imgui_impl_metal.h"
#include "backends/imgui_impl_glfw.h"

class icsGLFWContext
{
public:
    ~icsGLFWContext()
    {
    };
    
    void beforeDelete()
    {
        stopTimer();
 
#if __OBJC__
        @autoreleasepool
        {
#endif
            glfwDestroyWindow(_glfwWindowPtr);
            _glfwWindowPtr = nullptr;
            
#if Mac_GLFW_Metal
            if (_layer)
                [_layer release];
            if (_renderPassDescriptor)
                [_renderPassDescriptor release];
#endif
            
#if __OBJC__
        }
#endif
    }
    
    static bool createAndAttach(imgui_clap_editor *editor, NSView* inViewToAttach)
    {
        glfwSetErrorCallback(glfw_error_callback);
        if (!glfwInit())
            return false;
        
        editor->ctx = (void*)new icsGLFWContext(editor, inViewToAttach);
        
        return (editor->ctx != nullptr);
    }
    
    bool resize(int width, int height) {}
    
    static void glfw_error_callback(int error, const char* description)
    {
        fprintf(stderr, "Glfw Error %d: %s\n", error, description);
    }
    
private:
    
    void updateWindowPosition()
    {
        NSRect vr = [_nsView convertRect:[_nsView bounds] toView:nil];
        NSRect wr = [[_nsView window] convertRectToScreen:vr];
        wr.origin.y = CGDisplayBounds(CGMainDisplayID()).size.height-(wr.origin.y+wr.size.height);
        ImGui::SetNextWindowPos(ImVec2(wr.origin.x, wr.origin.y));
        ImGui::SetNextWindowSize(ImVec2(wr.size.width, wr.size.height));
    }
    
    void render()
    {
        struct _ScopeExit
        {
            _ScopeExit(std::function<void(void)> exitFunc) : _exitFunc(exitFunc) {}
            ~_ScopeExit() { _exitFunc(); }
            
        private:
            std::function<void (void)> _exitFunc;
        };
        
        if (_insideRendering) return;
        _insideRendering = true; // glfwPollEvents can reenter us by pumping timer messages
        _ScopeExit __se([this] { _insideRendering = false; });
        
#if __OBJC__
        @autoreleasepool
        {
#endif
        ImGui::SetCurrentContext(_imguiContext);

            
        static auto mtl_clear_color = MTLClearColorMake(1.0f, 0.5f, 0.5f, 1.0f);

        NSWindow *nsWindow = (NSWindow*)glfwGetCocoaWindow(_glfwWindowPtr);

        glfwPollEvents();

        int width, height;
        glfwGetFramebufferSize(_glfwWindowPtr, &width, &height);
        _layer.drawableSize = CGSizeMake(width, height);
        id<CAMetalDrawable> drawable = [_layer nextDrawable];
            
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        _renderPassDescriptor.colorAttachments[0].clearColor = mtl_clear_color;
        _renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
        _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"ImGui demo"];

        // Start the Dear ImGui frame
        ImGui_ImplMetal_NewFrame(_renderPassDescriptor);
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();     // Start the Dear ImGui frame
                
        _editor->onRender();

        // Rendering
        ImGui::Render();
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);

        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
            
#if __OBJC__
        }
#endif
    }
    
    void startTimer()
    {        
        CFTimeInterval TIMER_INTERVAL = 1.0 / 60.0; // In SurgeGUISynthesizer.h it uses 50 ms
        CFRunLoopTimerContext TimerContext = {0, this, NULL, NULL, NULL};
        CFAbsoluteTime FireTime = CFAbsoluteTimeGetCurrent() + TIMER_INTERVAL;

        _idleTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, FireTime, TIMER_INTERVAL, 0, 0,
                                         timerCallback, &TimerContext);

        if (_idleTimer)
            CFRunLoopAddTimer(CFRunLoopGetMain(), _idleTimer, kCFRunLoopCommonModes);
    }

    void stopTimer()
    {
        if (_idleTimer)
        {
            CFRunLoopRemoveTimer(CFRunLoopGetMain(), _idleTimer, kCFRunLoopCommonModes);
        }
    }
    
    static void timerCallback(CFRunLoopTimerRef timer, void *info)
    {
        if (auto object = (icsGLFWContext *)info)
        {
            object->render();
        }
    }
    
    icsGLFWContext(imgui_clap_editor* editor, NSView* viewToAttachTo) : _editor(editor), _nsView(viewToAttachTo)
    {
        @autoreleasepool {
        
        IMGUI_CHECKVERSION();
        _imguiContext = ImGui::CreateContext();
        ImGui::SetCurrentContext(_imguiContext);
        ImGuiIO& io = ImGui::GetIO(); (void)io;
        //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;  // Enable Keyboard Controls
        //io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;   // Enable Gamepad Controls

        // Setup style
        //ImGui::StyleColorsDark();
        ImGui::StyleColorsLight();
        
#if Mac_GLFW_Metal
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        const char* title = "CLAP-SAW-DEMO-GLFW+Metal";
#endif
    
#if Mac_GLFW_OGL
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
        const char* title = "CLAP-SAW-DEMO-GLFW+OGL";
#endif
        
        glfwWindowHint(GLFW_DECORATED, GLFW_FALSE);
        glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
        
        NSWindow *nsParentWindow = [viewToAttachTo window];
        auto nsViewBounds = viewToAttachTo.bounds;
        auto screenViewBounds = [nsParentWindow convertRectToScreen:nsViewBounds];
        
        _glfwWindowPtr = glfwCreateWindow(screenViewBounds.size.width, screenViewBounds.size.height, title, NULL, NULL);
        if (_glfwWindowPtr == NULL)
            return;
    
        NSWindow *nsWindow = (NSWindow*)glfwGetCocoaWindow(_glfwWindowPtr);
        //TODO: have to use same display ID as window
        glfwSetWindowPos(_glfwWindowPtr, screenViewBounds.origin.x, CGDisplayBounds(CGMainDisplayID()).size.height - (screenViewBounds.origin.y + screenViewBounds.size.height));
        
        [nsParentWindow addChildWindow:nsWindow ordered:NSWindowAbove];
  
#if Mac_GLFW_Metal
        _device = MTLCreateSystemDefaultDevice();
        _commandQueue = [[_device newCommandQueue] retain];
        
        ImGui_ImplGlfw_InitForOther(_glfwWindowPtr, true);
        ImGui_ImplMetal_Init(_device);
        
        _layer = [[CAMetalLayer layer] retain];
        _layer.device = _device;
        _layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        nsWindow.contentView.layer = _layer;
        nsWindow.contentView.wantsLayer = YES;
        
        _renderPassDescriptor = [[MTLRenderPassDescriptor new] retain];
#endif
        startTimer();
            
        }
    }
    
    CFRunLoopTimerRef _idleTimer = nullptr;
    
    imgui_clap_editor* _editor = nullptr;
    
    GLFWwindow* _glfwWindowPtr = nullptr;
    bool _insideRendering = false;

    ImGuiContext* _imguiContext = nullptr;
    
    NSView* _nsView = nullptr;
    
    id <MTLDevice> _device = nullptr;
    id <MTLCommandQueue> _commandQueue = nullptr;
    MTLRenderPassDescriptor* _renderPassDescriptor = nullptr;
    CAMetalLayer* _layer = nullptr;
};

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
    auto obj = (icsGLFWContext *)(e->ctx);
    obj->beforeDelete();
    delete obj;
    e->ctx = nullptr;
}

bool imgui_clap_guiSetParentWith(imgui_clap_editor *e,
                                 const clap_window *win)
{
    return icsGLFWContext::createAndAttach(e, (NSView *)win->cocoa);
}

bool imgui_clap_guiSetSizeWith(imgui_clap_editor *e, int width, int height)
{
    if (auto object = (icsGLFWContext*)(e->ctx))
    {
        return object->resize(width, height);
    }
    return false;
}
