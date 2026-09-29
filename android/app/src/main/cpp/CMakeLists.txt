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

# OpenCV Android SDK for dynamic Stage 4 CV workload
set(OpenCV_DIR
    "/home/naveen/android_libs/OpenCV-android-sdk/sdk/native/jni"
    CACHE PATH "OpenCV Android SDK CMake directory")

find_package(OpenCV REQUIRED COMPONENTS
        core
        imgproc
        features2d
        video
        calib3d)

message(STATUS "HSV2 OpenCV version: ${OpenCV_VERSION}")
message(STATUS "HSV2 OpenCV include dirs: ${OpenCV_INCLUDE_DIRS}")


set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fexceptions")
include_directories(
        librealsense/include
        librealsense/src
        librealsense/src/backend
        librealsense/src/ds5
        librealsense/src/types
        librealsense/src/core
)

add_library(
        hsv2_lite
        SHARED
        native-lib.cpp
        vio/imu_buffer.cpp
        vio/vio_engine.cpp)

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
        ${OpenCV_LIBS}
        ${log-lib}
        ${android-lib})
