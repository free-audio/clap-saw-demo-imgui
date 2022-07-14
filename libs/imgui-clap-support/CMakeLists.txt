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
    target_sources(${PROJECT_NAME} PUBLIC
            src/apple-macos.mm
            ${IMGUI_SOURCE_DIR}/backends/imgui_impl_metal.mm
            ${IMGUI_SOURCE_DIR}/backends/imgui_impl_osx.mm
            )
    # FIX this game controller link obvs with an ifdef
    target_link_libraries(${PROJECT_NAME} PUBLIC "-framework CoreFoundation" "-framework GameController" "-framework Cocoa" "-framework Metal" "-framework MetalKit")
endif()