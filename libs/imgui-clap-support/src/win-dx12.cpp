#include "imgui-clap-support/imgui-clap-editor.h"

#include "imgui.h"
#include "backends/imgui_impl_dx12.h"
#include "backends/imgui_impl_win32.h"

#include <mutex>
#include <system_error>
#include <optional>

#include <d3d12.h>
#include <dxgi1_4.h>
#include <tchar.h>

#ifdef _DEBUG
#define DX12_ENABLE_DEBUG_LAYER
#endif

#ifdef DX12_ENABLE_DEBUG_LAYER
#include <dxgidebug.h>
#pragma comment(lib, "dxguid.lib")
#endif

// Forward declare message handler from imgui_impl_win32.cpp
extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam,
                                                             LPARAM lParam);
namespace ClapSupport
{

struct DX12Globals
{
    void retain() 
    { 
        std::scoped_lock lock(_mutex);

        if (_retainCount == 0)
        {
            init();
        }

        _retainCount++;
    }

    void release() 
    { 
        std::scoped_lock lock(_mutex);
        _retainCount--;

        if (_retainCount == 0)
        {
            deinit();
        }
    }

    static int const numOfFramesInFlight = 3;
    static int const numBackBuffers = 3;

    ID3D12Device* _device = nullptr;

  private:
    bool init() 
    {
#ifdef DX12_ENABLE_DEBUG_LAYER
        ID3D12Debug *pdx12Debug = nullptr;
        if (SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(&pdx12Debug))))
            pdx12Debug->EnableDebugLayer();
#endif

        D3D_FEATURE_LEVEL featureLevel = D3D_FEATURE_LEVEL_11_0;
        if (D3D12CreateDevice(nullptr, featureLevel, IID_PPV_ARGS(&_device)) != S_OK)
            return false;

            // [DEBUG] Setup debug interface to break on any warnings/errors
#ifdef DX12_ENABLE_DEBUG_LAYER
        if (pdx12Debug != nullptr)
        {
            ID3D12InfoQueue *pInfoQueue = nullptr;
            _device->QueryInterface(IID_PPV_ARGS(&pInfoQueue));
            pInfoQueue->SetBreakOnSeverity(D3D12_MESSAGE_SEVERITY_ERROR, true);
            pInfoQueue->SetBreakOnSeverity(D3D12_MESSAGE_SEVERITY_CORRUPTION, true);
            pInfoQueue->SetBreakOnSeverity(D3D12_MESSAGE_SEVERITY_WARNING, true);
            pInfoQueue->Release();
            pdx12Debug->Release();
        }
#endif

        return true;
    }

    void deinit() 
    {
        if (_device)
        {
            _device->Release();
            _device = nullptr;
        }
    }

    int _retainCount = 0;
    std::mutex _mutex;
};

DX12Globals globals;

struct FrameContext
{
    ID3D12CommandAllocator *CommandAllocator;
    UINT64 FenceValue;
};

LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

class DX12Context
{
public:

    DX12Context(imgui_clap_editor *editor, HWND windowHandleParent) : _editor(editor) 
    { 
        IMGUI_CHECKVERSION();

        _windowClass = {sizeof(WNDCLASSEX), CS_CLASSDC, WndProc, 0L,   0L,
                         GetModuleHandle(nullptr), nullptr, nullptr, nullptr, nullptr,
                         _T("ImGui-CLAP-DX12-WindowClass"), nullptr};
        ::RegisterClassEx(&_windowClass);

        RECT clientRect;
        ::GetClientRect(windowHandleParent, &clientRect);

        _windowHandle = ::CreateWindow(_windowClass.lpszClassName, _T("ImGui Clap Saw Demo"),
            WS_CHILD | WS_VISIBLE, 0, 0, clientRect.right - clientRect.left, clientRect.bottom - clientRect.top, windowHandleParent, NULL,
                                   _windowClass.hInstance, nullptr);
        ::SetWindowLongPtr(_windowHandle, GWLP_USERDATA, (LONG_PTR)this);

        ::SetParent(_windowHandle, windowHandleParent);
        ::UpdateWindow(_windowHandle);
        ::SetFocus(_windowHandle);

        _imguiContext = ImGui::CreateContext();
        ImGui::SetCurrentContext(_imguiContext);

        ImGuiIO &io = ImGui::GetIO();
        (void)io;
        // io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
        // io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

        // Setup Dear ImGui style
        ImGui::StyleColorsDark();
        // ImGui::StyleColorsLight();

        globals.retain();
        createHeapDescriptors();
        createCommandListAndQueue();
        createFences();
        createSwapChain(_windowHandle);
        createRenderTargets();

        // Setup Platform/Renderer backends
        ImGui_ImplWin32_Init(_windowHandle);
        ImGui_ImplDX12_Init(globals._device, 
                            DX12Globals::numOfFramesInFlight, 
                            DXGI_FORMAT_R8G8B8A8_UNORM,
                            _srvDescHeap,
                            _srvDescHeap->GetCPUDescriptorHandleForHeapStart(),
                            _srvDescHeap->GetGPUDescriptorHandleForHeapStart());

        createTimer();
    }

    ~DX12Context() 
    { 
        globals.release();
    }

    void beforeDelete() 
    {   
        deleteTimer();
     
        setImGuiContext();

        ImGui_ImplDX12_Shutdown();
        ImGui_ImplWin32_Shutdown();
        ImGui::DestroyContext();
        _imguiContext = nullptr;

        cleanup();

        ::SetParent(_windowHandle, nullptr);
        ::DestroyWindow(_windowHandle);
        ::UnregisterClass(_windowClass.lpszClassName, _windowClass.hInstance);
    }

    void createTimer() 
    { 
        SetTimer(_windowHandle, 1, 30, nullptr);
    }

    void deleteTimer() 
    { 
        KillTimer(_windowHandle, 1);
    }

    FrameContext *WaitForNextFrameResources()
    {
        UINT nextFrameIndex = _frameIndex + 1;
        _frameIndex = nextFrameIndex;

        HANDLE waitableObjects[] = {_swapChainWaitableObject, nullptr};
        DWORD numWaitableObjects = 1;

        FrameContext *frameCtx = &_frameContext[nextFrameIndex % DX12Globals::numOfFramesInFlight];
        UINT64 fenceValue = frameCtx->FenceValue;
        if (fenceValue != 0) // means no fence was signaled
        {
            frameCtx->FenceValue = 0;
            _fence->SetEventOnCompletion(fenceValue, _fenceEvent);
            waitableObjects[1] = _fenceEvent;
            numWaitableObjects = 2;
        }

        WaitForMultipleObjects(numWaitableObjects, waitableObjects, TRUE, INFINITE);

        return frameCtx;
    }

    void render() 
    { 
        ImGui::SetCurrentContext(_imguiContext);

        ImGui_ImplDX12_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();
        
        _editor->onRender();

        // Rendering
        ImGui::Render();
        FrameContext *frameCtx = WaitForNextFrameResources();
        UINT backBufferIdx = _swapChain->GetCurrentBackBufferIndex();
        frameCtx->CommandAllocator->Reset();

        D3D12_RESOURCE_BARRIER barrier = {};
        barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        barrier.Transition.pResource = _mainRenderTargetResource[backBufferIdx];
        barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
        _commandList->Reset(frameCtx->CommandAllocator, nullptr);
        _commandList->ResourceBarrier(1, &barrier);

        // Render Dear ImGui graphics    
        ImVec4 clear_color = ImVec4(0.45f, 0.55f, 0.60f, 1.00f);
        const float clear_color_with_alpha[4] = {clear_color.x * clear_color.w,
                                                 clear_color.y * clear_color.w,
                                                 clear_color.z * clear_color.w, clear_color.w};
        _commandList->ClearRenderTargetView(_mainRenderTargetDescriptor[backBufferIdx],
                                                 clear_color_with_alpha, 0, nullptr);
        _commandList->OMSetRenderTargets(1, &_mainRenderTargetDescriptor[backBufferIdx],
                                              FALSE, nullptr);
        _commandList->SetDescriptorHeaps(1, &_srvDescHeap);
        ImGui_ImplDX12_RenderDrawData(ImGui::GetDrawData(), _commandList);
        barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        _commandList->ResourceBarrier(1, &barrier);
        _commandList->Close();

        _commandQueue->ExecuteCommandLists(1, (ID3D12CommandList *const *)&_commandList);

        // _swapChain->Present(1, 0); // Present with vsync
        _swapChain->Present(0, 0); // Present without vsync

        UINT64 fenceValue = _fenceLastSignaledValue + 1;
        _commandQueue->Signal(_fence, fenceValue);
        _fenceLastSignaledValue = fenceValue;
        frameCtx->FenceValue = fenceValue;
    }

    void setImGuiContext() 
    { 
        ImGui::SetCurrentContext(_imguiContext); 
    }

    HWND getWindowHandle()
    { 
        return _windowHandle;
    }

    bool resizeWindow(int width, int height) 
    { 
        if (_windowHandle == nullptr)
            return false;
        return ::SetWindowPos(_windowHandle, nullptr, 0, 0, width, height,
                              SWP_NOMOVE | SWP_NOOWNERZORDER | SWP_NOZORDER);
    }

    void resize(UINT width, UINT height) 
    {
        waitForLastSubmittedFrame();
        cleanupRenderTargets();
        resizeBuffers(width, height);
        createRenderTargets();
    }

private:
    bool createHeapDescriptors() 
    {
        D3D12_DESCRIPTOR_HEAP_DESC rtvDesc = {};
        rtvDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
        rtvDesc.NumDescriptors = DX12Globals::numBackBuffers;
        rtvDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
        rtvDesc.NodeMask = 1;
        if (globals._device->CreateDescriptorHeap(&rtvDesc, IID_PPV_ARGS(&_rtvDescHeap)) != S_OK)
            return false;

        SIZE_T rtvDescriptorSize =
            globals._device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
        D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = _rtvDescHeap->GetCPUDescriptorHandleForHeapStart();
        for (UINT i = 0; i < DX12Globals::numBackBuffers; i++)
        {
            _mainRenderTargetDescriptor[i] = rtvHandle;
            rtvHandle.ptr += rtvDescriptorSize;
        }

        D3D12_DESCRIPTOR_HEAP_DESC srvDesc = {};
        srvDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
        srvDesc.NumDescriptors = 1;
        srvDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
        if (globals._device->CreateDescriptorHeap(&srvDesc, IID_PPV_ARGS(&_srvDescHeap)) != S_OK)
            return false;

        return true;
    }

    bool createCommandListAndQueue() 
    {
        D3D12_COMMAND_QUEUE_DESC desc = {};
        desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
        desc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
        desc.NodeMask = 1;
        if (globals._device->CreateCommandQueue(&desc, IID_PPV_ARGS(&_commandQueue)) != S_OK)
            return false;
      
        for (UINT i = 0; i < DX12Globals::numOfFramesInFlight; i++)
            if (globals._device->CreateCommandAllocator(
                    D3D12_COMMAND_LIST_TYPE_DIRECT,
                    IID_PPV_ARGS(&_frameContext[i].CommandAllocator)) != S_OK)
                return false;

        if (globals._device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                               _frameContext[0].CommandAllocator, nullptr,
                                               IID_PPV_ARGS(&_commandList)) != S_OK ||
            _commandList->Close() != S_OK)
        {
            return false;
        }
        return true;
    }

    bool createFences() 
    {
        if (globals._device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&_fence)) != S_OK)
            return false;

        _fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);
        if (_fenceEvent == nullptr)
            return false;
        return true;
    }

    bool createSwapChain(HWND windowHandle) 
    {
        DXGI_SWAP_CHAIN_DESC1 sd;
        {
            ZeroMemory(&sd, sizeof(sd));
            sd.BufferCount = DX12Globals::numBackBuffers;
            sd.Width = 0;
            sd.Height = 0;
            sd.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
            sd.Flags = DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT;
            sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
            sd.SampleDesc.Count = 1;
            sd.SampleDesc.Quality = 0;
            sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
            sd.AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED;
            sd.Scaling = DXGI_SCALING_STRETCH;
            sd.Stereo = FALSE;
        };
        IDXGIFactory4 *dxgiFactory = nullptr;
        IDXGISwapChain1 *swapChain1 = nullptr;
        if (CreateDXGIFactory1(IID_PPV_ARGS(&dxgiFactory)) != S_OK)
            return false;
        if(dxgiFactory->CreateSwapChainForHwnd(_commandQueue, windowHandle, &sd, nullptr,
                                                             nullptr, &swapChain1) != S_OK)
                return false;
        if (swapChain1->QueryInterface(IID_PPV_ARGS(&_swapChain)) != S_OK)
                return false;
        swapChain1->Release();
        dxgiFactory->Release();

        _swapChain->SetMaximumFrameLatency(DX12Globals::numBackBuffers);
        _swapChainWaitableObject = _swapChain->GetFrameLatencyWaitableObject();
        
        return true;
    }

    void waitForLastSubmittedFrame() 
    {
        FrameContext *frameCtx = &_frameContext[_frameIndex % DX12Globals::numOfFramesInFlight];

        UINT64 fenceValue = frameCtx->FenceValue;
        if (fenceValue == 0)
            return; // No fence was signaled

        frameCtx->FenceValue = 0;
        if (_fence->GetCompletedValue() >= fenceValue)
            return;

        _fence->SetEventOnCompletion(fenceValue, _fenceEvent);
        WaitForSingleObject(_fenceEvent, INFINITE);
    }

    bool resizeBuffers(UINT width, UINT height) 
    {
        HRESULT result = _swapChain->ResizeBuffers(0, width, height, DXGI_FORMAT_UNKNOWN, DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT);
        assert(SUCCEEDED(result) && "Failed to resize swapchain.");
        return SUCCEEDED(result);
    }

    void createRenderTargets() 
    {
        for (UINT i = 0; i < DX12Globals::numBackBuffers; i++)
        {
            ID3D12Resource *backBuffer = nullptr;
            _swapChain->GetBuffer(i, IID_PPV_ARGS(&backBuffer));
            globals._device->CreateRenderTargetView(backBuffer, nullptr,
                                                    _mainRenderTargetDescriptor[i]);
            _mainRenderTargetResource[i] = backBuffer;
        }
    }

    void cleanupRenderTargets() 
    {
        for (UINT i = 0; i < DX12Globals::numBackBuffers; i++)
            if (_mainRenderTargetResource[i])
            {
                _mainRenderTargetResource[i]->Release();
                _mainRenderTargetResource[i] = nullptr;
            }
    }

    void cleanup() 
    {
        waitForLastSubmittedFrame();
        cleanupRenderTargets();

        if (_swapChain)
        {
            _swapChain->SetFullscreenState(false, nullptr);
            _swapChain->Release();
            _swapChain = nullptr;
        }
        if (_swapChainWaitableObject != nullptr)
        {
            ::CloseHandle(_swapChainWaitableObject);
        }
        for (UINT i = 0; i < DX12Globals::numOfFramesInFlight; i++)
            if (_frameContext[i].CommandAllocator)
            {
                _frameContext[i].CommandAllocator->Release();
                _frameContext[i].CommandAllocator = nullptr;
            }
        if (_commandQueue)
        {
            _commandQueue->Release();
            _commandQueue = nullptr;
        }
        if (_commandList)
        {
            _commandList->Release();
            _commandList = nullptr;
        }
        if (_rtvDescHeap)
        {
            _rtvDescHeap->Release();
            _rtvDescHeap = nullptr;
        }
        if (_srvDescHeap)
        {
            _srvDescHeap->Release();
            _srvDescHeap = nullptr;
        }
        if (_fence)
        {
            _fence->Release();
            _fence = nullptr;
        }
        if (_fenceEvent)
        {
            ::CloseHandle(_fenceEvent);
            _fenceEvent = nullptr;
        }
    }

    ImGuiContext* _imguiContext = nullptr;
    imgui_clap_editor* _editor = nullptr;

    WNDCLASSEX _windowClass = {};
    HWND _windowHandle = nullptr;

    UINT _frameIndex = 0;
    FrameContext _frameContext[DX12Globals::numOfFramesInFlight] = {};
    ID3D12Resource* _mainRenderTargetResource[DX12Globals::numBackBuffers] = {};
    D3D12_CPU_DESCRIPTOR_HANDLE _mainRenderTargetDescriptor[DX12Globals::numBackBuffers] = {};
    
    IDXGISwapChain3* _swapChain = nullptr;
    HANDLE _swapChainWaitableObject = nullptr;

    ID3D12CommandQueue* _commandQueue = nullptr;
    ID3D12GraphicsCommandList* _commandList = nullptr;

    ID3D12Fence* _fence = nullptr;
    HANDLE _fenceEvent = nullptr;
    UINT64 _fenceLastSignaledValue = 0;

    ID3D12DescriptorHeap* _rtvDescHeap = nullptr;
    ID3D12DescriptorHeap* _srvDescHeap = nullptr;
};

// Win32 message handler
// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to
// use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or
// clear/overwrite your copy of the mouse data.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main
// application, or clear/overwrite your copy of the keyboard data. Generally you may always pass all
// inputs to dear imgui, and hide them from your application based on those two flags.
LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    auto dx12context = (DX12Context*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
    if (dx12context)
        dx12context->setImGuiContext();

    switch (msg)
    {
        case WM_MOUSEMOVE:
        {
            auto focus = ::GetFocus();
            if (focus != hWnd && dx12context->getWindowHandle() == hWnd)
            {
                ::SetFocus(hWnd);
            }    
        }
            break;
        
        default:
            break;
    }

    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam))
        return true;

    switch (msg)
    {
        case WM_SIZE:
            if (globals._device != nullptr && wParam != SIZE_MINIMIZED)
                dx12context->resize((UINT)LOWORD(lParam), (UINT)HIWORD(lParam));
            return 0;
        case WM_SYSCOMMAND:
            if ((wParam & 0xfff0) == SC_KEYMENU) // Disable ALT application menu
                return 0;
            break;
        case WM_TIMER:
            dx12context->render();
            return 0;
        default:
            break;

    }
    return ::DefWindowProc(hWnd, msg, wParam, lParam);
}


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
    auto context = (ClapSupport::DX12Context *)e->ctx;
    context->beforeDelete();
    delete context;
    e->ctx = nullptr;
}
bool imgui_clap_guiSetParentWith(imgui_clap_editor *e,
                                 const clap_window *win)
{
    e->ctx = (void *)new ClapSupport::DX12Context(e, (HWND)win->win32);
    return true;
}
bool imgui_clap_guiSetSizeWith(imgui_clap_editor *e, int width, int height)
{
    if (auto context = (ClapSupport::DX12Context *)e->ctx)
    {
        return context->resizeWindow(width, height);
    }

    return false;
}
