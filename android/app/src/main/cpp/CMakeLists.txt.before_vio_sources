# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html

# Sets the minimum version of CMake required to build the native library.
cmake_minimum_required(VERSION 3.10.2)

# Declares and names the project.
project("hsv2_lite")

# Creates and names a library, sets it as either STATIC
# or SHARED, and provides the relative paths to its source code.
# You can define multiple libraries, and CMake builds them for you.
# Gradle automatically packages shared libraries with your APK.
# librealsense Android build flags
set(FORCE_RSUSB_BACKEND ON CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_GRAPHICAL_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_WITH_OPENMP OFF CACHE BOOL "" FORCE)
set(BUILD_WITH_TM2 OFF CACHE BOOL "" FORCE)

add_subdirectory(librealsense)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fexceptions")
include_directories(librealsense/include)

add_library(
        hsv2_lite
        SHARED
        native-lib.cpp)

find_library(
        log-lib
        log)

find_library(
        android-lib
        android)

target_compile_options(hsv2_lite PRIVATE -fexceptions -frtti)

target_link_libraries(
        hsv2_lite
        realsense2
        ${log-lib}
        ${android-lib})
