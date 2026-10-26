
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
FindOrFetch first tries to find the package on the system. If it can't find the package it tries to fetch it with the CMake FetchContent functionality.
The following example shows the usage in the `CMakeLists.txt` with the `fmt` library in version 9:
```cmake
find_or_fetch_package(
    fmt 9 
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git                        
    GIT_TAG master
    )
```

> Note: This does not work with cross-compiling!

`populate_package(<name> GIT_REPOSITORY <url> GIT_TAG <ref> [GIT_SHALLOW] [GIT_BRANCH] [SOURCE_SUBDIR] [PATCH_FILE |
PATCH_COMMAND/UPDATE_COMMAND] [QUIET])` only populates the sources (`<name>_SOURCE_DIR`), it adds nothing to the
build. A `FETCHCONTENT_SOURCE_DIR_<NAME>` is taken as is - after the arguments are checked, so a wrong argument fails
with it set too. Both functions build their FetchContent arguments in one place (`_find_or_fetch_args`); the test
`find_or_fetch` pins them per argument form against `tests/find_or_fetch/expected.txt`.

### HostBuild
The HostBuild helper tries to set up CMake for cross compilation by configuring the compiler for the build. A default `CMakeLists.txt` example is given below:

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
#### Sharing host builds between build trees
Many cross build trees that build the same host tool can share one host build of it. Set, for example from a file every
tree includes:

```cmake
set(HOST_BUILD_SHARED_ROOT "/path/to/host_tools" CACHE PATH "" FORCE)
set(HOST_BUILD_SHARED_TARGETS "example_executable" CACHE STRING "" FORCE)
```

A listed tool is then configured once per configuration (source directory, forwarded cache values, generator, `CC`/`CXX`,
CMake version) in `<root>/<target>-<key>`, and each tree's `<target>_host_build` is a symbolic link to it. Configure
and build hold `<root>/<target>-<key>.lock`, so trees may build at the same time; build a shared tree by hand with
`cmake -DHOST_BUILD_DIR=<tree> -DHOST_BUILD_TARGET=<target> -P HostBuildLocked.cmake`. Empty `HOST_BUILD_SHARED_ROOT`
(the default) gives every tree its own host build.

### Tests
`cmake -S tests -B build -G Ninja && ctest --test-dir build --output-on-failure`
