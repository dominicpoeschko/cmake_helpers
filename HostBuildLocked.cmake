# Builds one target of a shared host build tree (HostBuild.cmake, HOST_BUILD_SHARED_ROOT) under the tree's lock, so that
# build trees building it at the same time wait for each other instead of running two builds in one directory.
#
# cmake -DHOST_BUILD_DIR=<shared tree> [-DHOST_BUILD_TARGET=<target>] -P HostBuildLocked.cmake
#
# Without HOST_BUILD_TARGET the tree's default target is built.
cmake_minimum_required(VERSION 3.19)

if(NOT HOST_BUILD_DIR)
    message(FATAL_ERROR "HostBuildLocked.cmake: HOST_BUILD_DIR is required")
endif()

set(target_args)
if(HOST_BUILD_TARGET)
    set(target_args --target ${HOST_BUILD_TARGET})
endif()

file(
    LOCK ${HOST_BUILD_DIR}.lock
    GUARD PROCESS
    TIMEOUT 3600)
execute_process(COMMAND ${CMAKE_COMMAND} --build ${HOST_BUILD_DIR} ${target_args} COMMAND_ERROR_IS_FATAL ANY)
