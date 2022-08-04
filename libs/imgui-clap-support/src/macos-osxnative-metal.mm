#include "imgui-clap-support/imgui-clap-editor.h"

#include <Foundation/Foundation.h>
#include <Cocoa/Cocoa.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#import <Carbon/Carbon.h>

#include "imgui.h"
#include "backends/imgui_impl_metal.h"

#include <iostream>
#include <iomanip>

// copied from imgui/src/backends/imgui_impl_osx.mm

static inline CFTimeInterval GetMachAbsoluteTimeInSeconds()
{
    return static_cast<CFTimeInterval>(static_cast<double>(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e9);
}

static ImGuiKey ImGui_ImplOSX_KeyCodeToImGuiKey(int key_code)
{
    switch (key_code)
    {
        case kVK_ANSI_A: return ImGuiKey_A;
        case kVK_ANSI_S: return ImGuiKey_S;
        case kVK_ANSI_D: return ImGuiKey_D;
        case kVK_ANSI_F: return ImGuiKey_F;
        case kVK_ANSI_H: return ImGuiKey_H;
        case kVK_ANSI_G: return ImGuiKey_G;
        case kVK_ANSI_Z: return ImGuiKey_Z;
        case kVK_ANSI_X: return ImGuiKey_X;
        case kVK_ANSI_C: return ImGuiKey_C;
        case kVK_ANSI_V: return ImGuiKey_V;
        case kVK_ANSI_B: return ImGuiKey_B;
        case kVK_ANSI_Q: return ImGuiKey_Q;
        case kVK_ANSI_W: return ImGuiKey_W;
        case kVK_ANSI_E: return ImGuiKey_E;
        case kVK_ANSI_R: return ImGuiKey_R;
        case kVK_ANSI_Y: return ImGuiKey_Y;
        case kVK_ANSI_T: return ImGuiKey_T;
        case kVK_ANSI_1: return ImGuiKey_1;
        case kVK_ANSI_2: return ImGuiKey_2;
        case kVK_ANSI_3: return ImGuiKey_3;
        case kVK_ANSI_4: return ImGuiKey_4;
        case kVK_ANSI_6: return ImGuiKey_6;
        case kVK_ANSI_5: return ImGuiKey_5;
        case kVK_ANSI_Equal: return ImGuiKey_Equal;
        case kVK_ANSI_9: return ImGuiKey_9;
        case kVK_ANSI_7: return ImGuiKey_7;
        case kVK_ANSI_Minus: return ImGuiKey_Minus;
        case kVK_ANSI_8: return ImGuiKey_8;
        case kVK_ANSI_0: return ImGuiKey_0;
        case kVK_ANSI_RightBracket: return ImGuiKey_RightBracket;
        case kVK_ANSI_O: return ImGuiKey_O;
        case kVK_ANSI_U: return ImGuiKey_U;
        case kVK_ANSI_LeftBracket: return ImGuiKey_LeftBracket;
        case kVK_ANSI_I: return ImGuiKey_I;
        case kVK_ANSI_P: return ImGuiKey_P;
        case kVK_ANSI_L: return ImGuiKey_L;
        case kVK_ANSI_J: return ImGuiKey_J;
        case kVK_ANSI_Quote: return ImGuiKey_Apostrophe;
        case kVK_ANSI_K: return ImGuiKey_K;
        case kVK_ANSI_Semicolon: return ImGuiKey_Semicolon;
        case kVK_ANSI_Backslash: return ImGuiKey_Backslash;
        case kVK_ANSI_Comma: return ImGuiKey_Comma;
        case kVK_ANSI_Slash: return ImGuiKey_Slash;
        case kVK_ANSI_N: return ImGuiKey_N;
        case kVK_ANSI_M: return ImGuiKey_M;
        case kVK_ANSI_Period: return ImGuiKey_Period;
        case kVK_ANSI_Grave: return ImGuiKey_GraveAccent;
        case kVK_ANSI_KeypadDecimal: return ImGuiKey_KeypadDecimal;
        case kVK_ANSI_KeypadMultiply: return ImGuiKey_KeypadMultiply;
        case kVK_ANSI_KeypadPlus: return ImGuiKey_KeypadAdd;
        case kVK_ANSI_KeypadClear: return ImGuiKey_NumLock;
        case kVK_ANSI_KeypadDivide: return ImGuiKey_KeypadDivide;
        case kVK_ANSI_KeypadEnter: return ImGuiKey_KeypadEnter;
        case kVK_ANSI_KeypadMinus: return ImGuiKey_KeypadSubtract;
        case kVK_ANSI_KeypadEquals: return ImGuiKey_KeypadEqual;
        case kVK_ANSI_Keypad0: return ImGuiKey_Keypad0;
        case kVK_ANSI_Keypad1: return ImGuiKey_Keypad1;
        case kVK_ANSI_Keypad2: return ImGuiKey_Keypad2;
        case kVK_ANSI_Keypad3: return ImGuiKey_Keypad3;
        case kVK_ANSI_Keypad4: return ImGuiKey_Keypad4;
        case kVK_ANSI_Keypad5: return ImGuiKey_Keypad5;
        case kVK_ANSI_Keypad6: return ImGuiKey_Keypad6;
        case kVK_ANSI_Keypad7: return ImGuiKey_Keypad7;
        case kVK_ANSI_Keypad8: return ImGuiKey_Keypad8;
        case kVK_ANSI_Keypad9: return ImGuiKey_Keypad9;
        case kVK_Return: return ImGuiKey_Enter;
        case kVK_Tab: return ImGuiKey_Tab;
        case kVK_Space: return ImGuiKey_Space;
        case kVK_Delete: return ImGuiKey_Backspace;
        case kVK_Escape: return ImGuiKey_Escape;
        case kVK_CapsLock: return ImGuiKey_CapsLock;
        case kVK_Control: return ImGuiKey_LeftCtrl;
        case kVK_Shift: return ImGuiKey_LeftShift;
        case kVK_Option: return ImGuiKey_LeftAlt;
        case kVK_Command: return ImGuiKey_LeftSuper;
        case kVK_RightControl: return ImGuiKey_RightCtrl;
        case kVK_RightShift: return ImGuiKey_RightShift;
        case kVK_RightOption: return ImGuiKey_RightAlt;
        case kVK_RightCommand: return ImGuiKey_RightSuper;
//      case kVK_Function: return ImGuiKey_;
//      case kVK_F17: return ImGuiKey_;
//      case kVK_VolumeUp: return ImGuiKey_;
//      case kVK_VolumeDown: return ImGuiKey_;
//      case kVK_Mute: return ImGuiKey_;
//      case kVK_F18: return ImGuiKey_;
//      case kVK_F19: return ImGuiKey_;
//      case kVK_F20: return ImGuiKey_;
        case kVK_F5: return ImGuiKey_F5;
        case kVK_F6: return ImGuiKey_F6;
        case kVK_F7: return ImGuiKey_F7;
        case kVK_F3: return ImGuiKey_F3;
        case kVK_F8: return ImGuiKey_F8;
        case kVK_F9: return ImGuiKey_F9;
        case kVK_F11: return ImGuiKey_F11;
        case kVK_F13: return ImGuiKey_PrintScreen;
//      case kVK_F16: return ImGuiKey_;
//      case kVK_F14: return ImGuiKey_;
        case kVK_F10: return ImGuiKey_F10;
        case 0x6E: return ImGuiKey_Menu;
        case kVK_F12: return ImGuiKey_F12;
//      case kVK_F15: return ImGuiKey_;
        case kVK_Help: return ImGuiKey_Insert;
        case kVK_Home: return ImGuiKey_Home;
        case kVK_PageUp: return ImGuiKey_PageUp;
        case kVK_ForwardDelete: return ImGuiKey_Delete;
        case kVK_F4: return ImGuiKey_F4;
        case kVK_End: return ImGuiKey_End;
        case kVK_F2: return ImGuiKey_F2;
        case kVK_PageDown: return ImGuiKey_PageDown;
        case kVK_F1: return ImGuiKey_F1;
        case kVK_LeftArrow: return ImGuiKey_LeftArrow;
        case kVK_RightArrow: return ImGuiKey_RightArrow;
        case kVK_DownArrow: return ImGuiKey_DownArrow;
        case kVK_UpArrow: return ImGuiKey_UpArrow;
        default: return ImGuiKey_None;
    }
}

// copied end

@interface icsMetal : MTKView<MTKViewDelegate, NSTextInputClient>
@property imgui_clap_editor* editor;
@property CFRunLoopTimerRef idleTimer;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@property ImGuiContext *imguiContext;
@property bool wasAcceptingMouseMove;
@property NSTrackingRectTag trackingRectTag;
@property (retain) NSTextInputContext* textInputContext;
@property CFTimeInterval Time;

- (id)initWithEditor:(imgui_clap_editor *)ed  withParent:(NSView *)v;
- (void) startTimer;
- (void) stopTimer;
- (void) doIdle;
@end

void timerCallback(CFRunLoopTimerRef timer, void *info)
{
    icsMetal *view = (icsMetal *)info;
    [view doIdle];
}

@implementation  icsMetal
{
    float _posX;
    float _posY;
    NSRect _imeRect;
}

- (id)initWithEditor:(imgui_clap_editor *)editor withParent:(NSView *)parentView
{
    self = [super initWithFrame:[parentView bounds]];

    _editor = editor;

    self.device = MTLCreateSystemDefaultDevice();
    self.delegate = self;
    _commandQueue = [self.device newCommandQueue];
    self.trackingRectTag = 0;
    
    _idleTimer = nil;

    IMGUI_CHECKVERSION();
    _imguiContext = ImGui::CreateContext();
    ImGui::SetCurrentContext(_imguiContext);
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls
    // ImGui::GetIO().ConfigViewportsNoAutoMerge=true;
    
    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

    // Setup Renderer backend
    ImGui_ImplMetal_Init(self.device);
    
    // Instead of using the OSX backend, we handle all events in the view
    // Gamepad and Cursors are removed for now
    
    //
    io.BackendPlatformUserData = self;
    //io.BackendFlags |= ImGuiBackendFlags_HasMouseCursors;           // We can honor GetMouseCursor() values (optional)
    //io.BackendFlags |= ImGuiBackendFlags_HasSetMousePos;          // We can honor io.WantSetMousePos requests (optional, rarely used)
    io.BackendPlatformName = "imgui-clap-support-osx-native-metal";
    
    // Copyied from igui_impl_osx.mm:
    
    // Note that imgui.cpp also include default OSX clipboard handlers which can be enabled
    // by adding '#define IMGUI_ENABLE_OSX_DEFAULT_CLIPBOARD_FUNCTIONS' in imconfig.h and adding '-framework ApplicationServices' to your linker command-line.
    // Since we are already in ObjC land here, it is easy for us to add a clipboard handler using the NSPasteboard api.
    io.SetClipboardTextFn = [](void*, const char* str) -> void
    {
        NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
        [pasteboard setString:[NSString stringWithUTF8String:str] forType:NSPasteboardTypeString];
    };

    io.GetClipboardTextFn = [](void*) -> const char*
    {
        NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
        NSString* available = [pasteboard availableTypeFromArray: [NSArray arrayWithObject:NSPasteboardTypeString]];
        if (![available isEqualToString:NSPasteboardTypeString])
            return NULL;

        NSString* string = [pasteboard stringForType:NSPasteboardTypeString];
        if (string == nil)
            return NULL;

        const char* string_c = (const char*)[string UTF8String];
        size_t string_len = strlen(string_c);
        static ImVector<char> s_clipboard;
        s_clipboard.resize((int)string_len + 1);
        strcpy(s_clipboard.Data, string_c);
        return s_clipboard.Data;
    };
    
    // end

    // we can't capture self in the lambda because a funciton pointer is expected for SetPlatformImeDataFn
    // so we use the PlatformHandleRaw in the ViewPort which is not used according to the documentation
    self.textInputContext = [[NSTextInputContext alloc] initWithClient:self];
    auto vp = ImGui::GetMainViewport();
    vp->PlatformHandleRaw = self;

    io.SetPlatformImeDataFn = [](ImGuiViewport* viewport, ImGuiPlatformImeData* data) -> void
    {
        auto view = (icsMetal*)viewport->PlatformHandleRaw;
        
        if (data->WantVisible)
        {
            [view.textInputContext  activate];
        }
        else
        {
            [view.textInputContext  discardMarkedText];
            [view.textInputContext  invalidateCharacterCoordinates];
            [view.textInputContext  deactivate];
        }
        [view setImePosX:data->InputPos.x imePosY:data->InputPos.y + data->InputLineHeight];
    };

    // For mouse move class events
    NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect |
                             NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved);

    if (NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                        options:options
                                                          owner:self
                                                       userInfo:nil])
    {
        [self addTrackingArea:area];
        [area release];
    }
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

    // Start the Dear ImGui frame
    ImGui_ImplMetal_NewFrame(renderPassDescriptor);

    // Setup display size
    if (view)
    {
        const float dpi = (float)[view.window backingScaleFactor];
        io.DisplaySize = ImVec2((float)view.bounds.size.width, (float)view.bounds.size.height);
        io.DisplayFramebufferScale = ImVec2(dpi, dpi);
    }

    // Setup time step
    if (self.Time == 0.0)
        self.Time = GetMachAbsoluteTimeInSeconds();

    double current_time = GetMachAbsoluteTimeInSeconds();
    io.DeltaTime = (float)(current_time - self.Time);
    self.Time = current_time;

    // mouse cursor support
    // gamepad support
    
    [self updateImePosWithView:view];
    
    ImGui::NewFrame();
    
    self.editor->onRender();

    ImGui::Render();
    ImDrawData* draw_data = ImGui::GetDrawData();

    static ImVec4 clear_color = ImVec4(0.3f, 0.3f, 0.3f, 1.00f);
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

- (BOOL)acceptsFirstResponder
{
    return YES;
}

// The event code is adapted from imgui/src/backends/imgui_impl_osx.mm, but adapted that it is captured from the window which holds the correct ImGuiContext

- (void)mouseDown:(NSEvent *)event
{
    [self otherMouseDown:event];
}

-(void)mouseUp:(NSEvent *)event
{
    [self otherMouseUp:event];
}

-(void)mouseDragged:(NSEvent *)event
{
    [self mouseMoved:event];
}

-(void) rightMouseUp:(NSEvent *)event
{
    [self otherMouseUp:event];
}

-(void) rightMouseDown:(NSEvent *)event
{
    [self otherMouseDown:event];
}

-(void) rightMouseDragged:(NSEvent *)event
{
    [self mouseMoved:event];
}

-(void)otherMouseUp:(NSEvent *)event
{
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();
    int button = (int)[event buttonNumber];
    if (button >= 0 && button < ImGuiMouseButton_COUNT)
        io.AddMouseButtonEvent(button, false);
    // return io.WantCaptureMouse;
    return;
}

-(void)otherMouseDown:(NSEvent *)event
{
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();
    int button = (int)[event buttonNumber];
    if (button >= 0 && button < ImGuiMouseButton_COUNT)
        io.AddMouseButtonEvent(button, true);
}

-(void)otherMouseDragged:(NSEvent *)event
{
    [self mouseMoved:event];
}

-(void)mouseMoved:(NSEvent *)event
{
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();
    NSPoint mousePoint = event.locationInWindow;
    mousePoint = [self convertPoint:mousePoint fromView:nil];
    mousePoint = NSMakePoint(mousePoint.x, self.bounds.size.height - mousePoint.y);
    io.AddMousePosEvent((float)mousePoint.x, (float)mousePoint.y);
}

- (void)mouseEntered:(NSEvent *)event
{
    self.wasAcceptingMouseMove = [[self window] acceptsMouseMovedEvents];
    [[self window] setAcceptsMouseMovedEvents:YES];
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();
    io.AddFocusEvent(true);
}

- (void)mouseExited:(NSEvent *)event
{
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();
    io.AddFocusEvent(false);
    [[self window] setAcceptsMouseMovedEvents:self.wasAcceptingMouseMove];
}

- (void)viewDidMoveToWindow
{
    [self.window makeFirstResponder:self];
    self.trackingRectTag = [self addTrackingRect:self.bounds owner:self userData:NULL assumeInside:NO];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    auto oldWindow = self.window;
    
    if (oldWindow && self.trackingRectTag )
    {
        [self removeTrackingRect:self.trackingRectTag];
    }
}

-(void) flagsChanged:(NSEvent *)event
{
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();

    unsigned short key_code = [event keyCode];
    NSEventModifierFlags modifier_flags = [event modifierFlags];

    io.AddKeyEvent(ImGuiKey_ModShift, (modifier_flags & NSEventModifierFlagShift)   != 0);
    io.AddKeyEvent(ImGuiKey_ModCtrl,  (modifier_flags & NSEventModifierFlagControl) != 0);
    io.AddKeyEvent(ImGuiKey_ModAlt,   (modifier_flags & NSEventModifierFlagOption)  != 0);
    io.AddKeyEvent(ImGuiKey_ModSuper, (modifier_flags & NSEventModifierFlagCommand) != 0);

    ImGuiKey key = ImGui_ImplOSX_KeyCodeToImGuiKey(key_code);
    if (key != ImGuiKey_None)
    {
        // macOS does not generate down/up event for modifiers. We're trying
        // to use hardware dependent masks to extract that information.
        // 'imgui_mask' is left as a fallback.
        NSEventModifierFlags mask = 0;
        switch (key)
        {
            case ImGuiKey_LeftCtrl:   mask = 0x0001; break;
            case ImGuiKey_RightCtrl:  mask = 0x2000; break;
            case ImGuiKey_LeftShift:  mask = 0x0002; break;
            case ImGuiKey_RightShift: mask = 0x0004; break;
            case ImGuiKey_LeftSuper:  mask = 0x0008; break;
            case ImGuiKey_RightSuper: mask = 0x0010; break;
            case ImGuiKey_LeftAlt:    mask = 0x0020; break;
            case ImGuiKey_RightAlt:   mask = 0x0040; break;
            default:
                // return io.WantCaptureKeyboard;
                return;
        }

        NSEventModifierFlags modifier_flags = [event modifierFlags];
        io.AddKeyEvent(key, (modifier_flags & mask) != 0);
        io.SetKeyEventNativeData(key, key_code, -1); // To support legacy indexing (<1.87 user code)
    }
}

-(void) scrollWheel:(NSEvent *)event
{
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();

    // Ignore canceled events.
    //
    // From macOS 12.1, scrolling with two fingers and then decelerating
    // by tapping two fingers results in two events appearing:
    //
    // 1. A scroll wheel NSEvent, with a phase == NSEventPhaseMayBegin, when the user taps
    // two fingers to decelerate or stop the scroll events.
    //
    // 2. A scroll wheel NSEvent, with a phase == NSEventPhaseCancelled, when the user releases the
    // two-finger tap. It is this event that sometimes contains large values for scrollingDeltaX and
    // scrollingDeltaY. When these are added to the current x and y positions of the scrolling view,
    // it appears to jump up or down. It can be observed in Preview, various JetBrains IDEs and here.
    if (event.phase == NSEventPhaseCancelled)
        //return false;
        return;

    double wheel_dx = 0.0;
    double wheel_dy = 0.0;

    #if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
    {
        wheel_dx = [event scrollingDeltaX];
        wheel_dy = [event scrollingDeltaY];
        if ([event hasPreciseScrollingDeltas])
        {
            wheel_dx *= 0.1;
            wheel_dy *= 0.1;
        }
    }
    else
    #endif // MAC_OS_X_VERSION_MAX_ALLOWED
    {
        wheel_dx = [event deltaX];
        wheel_dy = [event deltaY];
    }
    if (wheel_dx != 0.0 || wheel_dy != 0.0)
        io.AddMouseWheelEvent((float)wheel_dx * 0.1f, (float)wheel_dy * 0.1f);
}


- (void)setImePosX:(float)posX imePosY:(float)posY
{
    _posX = posX;
    _posY = posY;
}

- (void)updateImePosWithView:(NSView *)view
{
    NSWindow *window = view.window;
    if (!window)
        return;
    NSRect contentRect = [window contentRectForFrameRect:window.frame];
    NSRect rect = NSMakeRect(_posX, contentRect.size.height - _posY, 0, 0);
    _imeRect = [window convertRectToScreen:rect];
}

- (void)keyDown:(NSEvent*)event
{
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();

    if (![event isARepeat])
    {
        int key_code = (int)[event keyCode];
        ImGuiKey key = ImGui_ImplOSX_KeyCodeToImGuiKey(key_code);
        io.AddKeyEvent(key, event.type == NSEventTypeKeyDown);
        io.SetKeyEventNativeData(key, key_code, -1); // To support legacy indexing (<1.87 user code)
    }
    
    if (!io.WantCaptureKeyboard)
    {
        if (event.type == NSEventTypeKeyDown)
            [super keyDown:event];
        else
            [super keyUp:event];
    }

    if (event.type == NSEventTypeKeyDown)
    {
        // Call to the macOS input manager system.
        [self interpretKeyEvents:@[event]];
    }
}

- (void)keyUp:(NSEvent*)event
{
    [self keyDown:event];
}

// NSTextInputClient

- (void)insertText:(id)aString replacementRange:(NSRange)replacementRange
{
    ImGui::SetCurrentContext(self.imguiContext);
    ImGuiIO& io = ImGui::GetIO();

    NSString* characters;
    if ([aString isKindOfClass:[NSAttributedString class]])
        characters = [aString string];
    else
        characters = (NSString*)aString;

    io.AddInputCharactersUTF8(characters.UTF8String);
}

- (void)doCommandBySelector:(SEL)myselector
{
}

- (nullable NSAttributedString*)attributedSubstringForProposedRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange
{
    return nil;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point
{
    return 0;
}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange
{
    return _imeRect;
}

- (BOOL)hasMarkedText
{
    return NO;
}

- (NSRange)markedRange
{
    return NSMakeRange(NSNotFound, 0);
}

- (NSRange)selectedRange
{
    return NSMakeRange(NSNotFound, 0);
}

- (void)setMarkedText:(nonnull id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange
{
}

- (void)unmarkText
{
}

- (nonnull NSArray<NSAttributedStringKey>*)validAttributesForMarkedText
{
    return @[];
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
    auto mwin = (icsMetal *)(e->ctx);
    [mwin stopTimer];
    [mwin release];
    e->ctx = nullptr;
}
bool imgui_clap_guiSetParentWith_(imgui_clap_editor *ed,
                                 const clap_window *win)
{
    auto nsv = (NSView *)win->cocoa;
    auto mwin = [[icsMetal alloc] initWithEditor:ed withParent: nsv];
    [nsv addSubview:mwin];
    [mwin startTimer];
    ed->ctx = mwin;

    return true;
}

bool imgui_clap_guiSetParentWith(imgui_clap_editor *ed,
                                 const clap_window *win)
{
    auto nsv = (NSView *)win->cocoa;
    auto mwin = [[icsMetal alloc] initWithEditor:ed withParent: nsv];
    
    [nsv addSubview:mwin];
    [mwin startTimer];
    ed->ctx = mwin;

    return true;
}



bool imgui_clap_guiSetSizeWith(imgui_clap_editor *ed, int width, int height)
{
    auto mwin = (icsMetal *)(ed->ctx);
    [mwin setBounds:NSMakeRect(0, 0, width, height)];
    return true;
}
