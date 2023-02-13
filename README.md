
# CMake Helpers
This repository provides a selection of helper tools for CMake.

## Usage
To use the helpers in this repository add the repository as `git submodule` to your project.

If you want to use all cmake_helpers in your project just include the `BuildOptions.cmake` file in your `CMakeLists.txt`:
```cmake
include(cmake_helpers/BuildOptions.cmake)
```

If you want to just use one helper of this selection include the needed helper in your `CMakeLists.txt`.

### FindOrFetch
FindOrFetch first tries to find the package on the system. If it can't find the feature it tries to fetch it with the CMake FetchContent functionality.
The following example shows the usage in the `CMakeLists.txt` with the `fmt` library in version 9:
```cmake
find_or_fetch_package(
    fmt 9 
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git                        
    GIT_TAG master
    )
```

> Note: This does not work with cross-compiling!

### HostBuild
The HostBuild helper tries to setup CMake for a cross compilation by configuring the compiler for the build. A default `CMakeLists.txt` example is given below:

```cmake
if(NOT CMAKE_CROSSCOMPILING)
    add_executable(
        example_executable
        src/main.cpp
    )
else()
    include(cmake_helpers/HostBuild.cmake)
    configure_host_build(example_executable)
endif()
```