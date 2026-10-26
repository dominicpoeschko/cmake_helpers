# A cross build's view of a host tool, as uc_log and svd_converter have it: the outer tree (HB_TEST_OUTER) builds
# `hello` through configure_host_build(), which configures this same file again as the host tree.
cmake_minimum_required(VERSION 3.25)
project(host_build_consumer LANGUAGES NONE)

if(NOT HB_TEST_OUTER)
    enable_language(CXX)
    add_executable(hello hello.cpp)
else()
    include(${HELPERS_DIR}/HostBuild.cmake)
    configure_host_build(hello)
    add_custom_target(run ALL COMMAND $<TARGET_PROPERTY:hello,HOST_EXECUTABLE_PATH>)
    add_dependencies(run hello)
endif()
