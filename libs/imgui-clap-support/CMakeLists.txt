cmake_minimum_required(VERSION 3.17)
project(imgui-clap-support C CXX)

if (NOT IMGUI_SOURCE_DIR)
    message(FATAL "You must define IMGUI_SOURCE_DIR before including these extensions")
endif()
add_library(${PROJECT_NAME} STATIC
        ${IMGUI_SOURCE_DIR}/imgui.cpp
        ${IMGUI_SOURCE_DIR}/imgui_tables.cpp
        ${IMGUI_SOURCE_DIR}/imgui_widgets.cpp
        ${IMGUI_SOURCE_DIR}/imgui_draw.cpp
        )

target_include_directories(${PROJECT_NAME} PUBLIC include)
target_include_directories(${PROJECT_NAME} PUBLIC ${IMGUI_SOURCE_DIR})
target_link_libraries(${PROJECT_NAME} PUBLIC clap-core)

if (APPLE)
    set(APPLE_GLFW FALSE)
    if (${APPLE_GLFW})
        find_package(glfw3 REQUIRED)
        target_sources(${PROJECT_NAME} PUBLIC
            src/macos-glfw-metal.mm
            ${IMGUI_SOURCE_DIR}/backends/imgui_impl_metal.mm
            ${IMGUI_SOURCE_DIR}/backends/imgui_impl_glfw.cpp
            )
        target_link_libraries(${PROJECT_NAME} PUBLIC glfw "-framework CoreFoundation" "-framework GameController" "-framework Cocoa" "-framework Metal" "-framework MetalKit")
    else()
        target_sources(${PROJECT_NAME} PUBLIC
                src/macos-osxnative-metal.mm
                ${IMGUI_SOURCE_DIR}/backends/imgui_impl_metal.mm
                )
        target_link_libraries(${PROJECT_NAME} PUBLIC "-framework CoreFoundation" "-framework GameController" "-framework Cocoa" "-framework Metal" "-framework MetalKit")
    endif()
endif()

if(WIN32)
   target_sources(${PROJECT_NAME} PUBLIC
            src/win-dx12.cpp
            ${IMGUI_SOURCE_DIR}/backends/imgui_impl_win32.cpp
            ${IMGUI_SOURCE_DIR}/backends/imgui_impl_dx12.cpp
            )
endif()
