# A consumer of BuildOptions.cmake: one executable with the default build options, configured by run.cmake with
# different options and only inspected (compile_commands.json, build.ninja), never built.
cmake_minimum_required(VERSION 3.25)
project(build_options_consumer LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(${HELPERS_DIR}/BuildOptions.cmake)

add_executable(probe probe.cpp)
target_add_default_build_options(probe PRIVATE)
