# Tests of the helpers. `cmake -S tests -B <dir> -G Ninja && ctest --test-dir <dir> --output-on-failure`
cmake_minimum_required(VERSION 3.25)
project(cmake_helpers_tests LANGUAGES NONE)

enable_testing()

# HostBuild.cmake: private host builds (the default) and shared ones (HOST_BUILD_SHARED_ROOT).
add_test(
    NAME host_build
    COMMAND
        ${CMAKE_COMMAND} -DHELPERS_DIR=${CMAKE_CURRENT_SOURCE_DIR}/..
        -DCONSUMER_DIR=${CMAKE_CURRENT_SOURCE_DIR}/host_build/consumer
        -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/host_build -DGENERATOR=${CMAKE_GENERATOR} -P
        ${CMAKE_CURRENT_SOURCE_DIR}/host_build/run.cmake)

# FindOrFetch.cmake: the FetchContent arguments of every form and the refusals (no network: a stand-in FetchContent).
add_test(
    NAME find_or_fetch
    COMMAND ${CMAKE_COMMAND} -DHELPERS_DIR=${CMAKE_CURRENT_SOURCE_DIR}/..
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/find_or_fetch -P ${CMAKE_CURRENT_SOURCE_DIR}/find_or_fetch/run.cmake)

# BuildOptions.cmake's flags: NDEBUG and USE_NDEBUG, the warning flags and -Werror on a gcc LTO link, clang's LTO with
# libstdc++ only without a sanitizer (configures a C++ consumer, builds nothing).
add_test(
    NAME build_options
    COMMAND
        ${CMAKE_COMMAND} -DHELPERS_DIR=${CMAKE_CURRENT_SOURCE_DIR}/..
        -DCONSUMER_DIR=${CMAKE_CURRENT_SOURCE_DIR}/build_options/consumer
        -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/build_options -DGENERATOR=${CMAKE_GENERATOR} -P
        ${CMAKE_CURRENT_SOURCE_DIR}/build_options/run.cmake)
