# Basic Idea

imgui is a 'direct more' rnederer. You get called to make your rectangles every
so often. It has backends which do that.

So here's my idea for clap

Look at `libs/imgui-clap-support/include/imgui-clap-support/imgui-clap-editor.h`

This is an abstract class which suppors a few methods (onCreate/Destry/Render). We
would need to add resize later obviously. And holds a context.

There are a few free functions which set up the view.

This means all the *nasty* GLFW and so on code behind imggui can go away from the user

So the way I have this set up (since I only did mac tonigh) is `libs/imgui-clap-suport/src/apple-macos.mm`
actually uses the *METAL* renderer to render the simple UI which is speciiced in
`src/clap-saw-demo-editor.cpp` in `ClapSawDemoEditor::onRender`

Right now it is pretty trivial - it just shows text - but making this work like
vstgui is easy.

The free fuynctions in `imggui-clap-editor.h` bind the editor object to the implementation.
You can see in `clap-saw-demo-editor.cpp` we call them from the clap with isntances
of the object in question

So what's the upshot of this? Well it means if we finis `imggui-clap-support` (and finish
means: add a linux gl and windows gl or dx backend implementation to match the metal one,
move it to a submodule, add resize check for leaks and bugs, etc...) then a person writing a clap
could simply implement the small boilerplate to connect their editor object
up to the clap gui and voila.

Will share more tomorrow -late here now - but wanted to get this up.

# Building on Mac OS

Requirements: Xcode, CMake

```shell
# Checkout the code
git clone --recurse-submodules https://github.com/free-audio/clap-saw-demo-imgui 
cd clap-saw-demo-imgui
cmake -B build -G Xcode
open build/clap-saw-demo-imgui.xcodeproj
```
build in Xcode

# Building on Windows

TODO
