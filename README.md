# clap-saw-demo-imgui

This project is a port of the [clap-saw-demo](https://github.com/surge-synthesizer/clap-saw-demo)
VSTGUI example to have the same clap engine but use [Dear IMGUI](https://github.com/ocornut/imgui)
as the renderer for the clap gui. Currently it works on windows and macOS.

The project works by using the [clap-imgui-support](https://github.com/free-audio/clap-imgui-support)
library which provides an interface between the imgui rendering setup and the clap 
gui interface.

That library hides most of the details, providing a DirectX12 render setup on windows and
a Metal surface on macOS. Contributions from the linux community to make it work with
SDL/OpenGL or another appropriate imgui backend would be welcomed!

To use the imgui, make an editor class which subclasses `imgui_clap_editor` such as 
[the ClapSawDemoEditor here](https://github.com/free-audio/clap-saw-demo-imgui/blob/26bd59dd78dd8bf5f743d8fbe49ba2789ce30877/src/clap-saw-demo-editor.h#L14)
then implement the various mechanics to connect and render as shown in the cpp file. 


# Building the Example

Our CI pipeline shows the minimal build all paltforms which is

```shell
git clone --recurse-submodules https://github.com/free-audio/clap-saw-demo-imgui 
cd clap-saw-demo-imgui
cmake -Bbuild -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

To build, you will need visual studio installed on windows, and XCode and CMake 
installed on macOS.

As with all cmake projects you can integrate with your various IDE of choice. For instance
to use XCode directly you would do

```
cmake -B build -G Xcode
open build/clap-saw-demo-imgui.xcodeproj
```

