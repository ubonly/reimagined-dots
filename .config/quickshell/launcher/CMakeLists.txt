cmake_minimum_required(VERSION 3.20)

project(ReimaginedLauncher LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS Core)

add_executable(appctl
    src/AppDiscovery.cpp
    src/DesktopEntry.cpp
    src/IconResolver.cpp
    src/main.cpp
)

target_include_directories(appctl PRIVATE src)
target_link_libraries(appctl PRIVATE Qt6::Core)
