# Driver of the build_options test (cmake -P): the consumer configured with different options, its compile and link
# lines read back.
# - Release defines NDEBUG; USE_NDEBUG=OFF keeps the assert()s (an optimised build as the firmware ships, CI's tests).
# - A gcc LTO link gets the warning flags, and -Werror with USE_WARNINGS_AS_ERRORS (gcc warns there); without LTO
#   not.
# - clang with libstdc++ gets LTO unless a sanitizer is on (GNU ld's LLVM plugin drops ASan's module ctors).
# - gcc's sanitizer builds turn off maybe-uninitialized and stringop-overflow (they misread instrumented code).
cmake_minimum_required(VERSION 3.25)

foreach(v HELPERS_DIR CONSUMER_DIR WORK_DIR GENERATOR)
    if(NOT ${v})
        message(FATAL_ERROR "run.cmake: ${v} is required")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})

function(fail)
    message(FATAL_ERROR "build_options: ${ARGN}")
endfunction()

# configure <tree> <options>...: sets <tree>_compile (the probe's compile line) and <tree>_link (its link flags)
function(configure tree)
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S ${CONSUMER_DIR} -B ${WORK_DIR}/${tree} -G ${GENERATOR}
                -DHELPERS_DIR=${HELPERS_DIR} ${ARGN}
        RESULT_VARIABLE rc
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(NOT rc EQUAL 0)
        fail("configure ${tree} failed:\n${out}")
    endif()
    file(READ ${WORK_DIR}/${tree}/compile_commands.json compile)
    file(READ ${WORK_DIR}/${tree}/build.ninja ninja)
    string(REGEX MATCH "build probe: [^\n]*\n(  [^\n]*\n)*" link "${ninja}")
    if(link STREQUAL "")
        fail("${tree}: no link edge for probe in build.ninja")
    endif()
    set(${tree}_compile "${compile}" PARENT_SCOPE)
    set(${tree}_link "${link}" PARENT_SCOPE)
endfunction()

function(expect tree what text needle)
    string(FIND "${text}" "${needle}" at)
    if(at EQUAL -1)
        fail("${tree}: no '${needle}' in its ${what}:\n${text}")
    endif()
endfunction()

function(expect_not tree what text needle)
    string(FIND "${text}" "${needle}" at)
    if(NOT at EQUAL -1)
        fail("${tree}: '${needle}' in its ${what}:\n${text}")
    endif()
endfunction()

configure(release -DUSE_LTO=OFF)
expect(release compile "${release_compile}" "-DNDEBUG")
expect(release compile "${release_compile}" "-O3")

configure(asserts -DUSE_LTO=OFF -DUSE_NDEBUG=OFF)
expect_not(asserts compile "${asserts_compile}" "-DNDEBUG")
expect(asserts compile "${asserts_compile}" "-O3")
expect_not(asserts link "${asserts_link}" "-Werror")

configure(lto -DUSE_LTO=ON -DUSE_WARNINGS_AS_ERRORS=ON)
file(GLOB compiler_file ${WORK_DIR}/lto/CMakeFiles/*/CMakeCXXCompiler.cmake)
file(STRINGS ${compiler_file} id REGEX "^set\\(CMAKE_CXX_COMPILER_ID \"")
string(REGEX REPLACE ".*\"(.*)\".*" "\\1" id "${id}")
expect(lto link "${lto_link}" "-flto=auto")
if(id STREQUAL "GNU")
    expect(lto link "${lto_link}" "-Werror")
    expect(lto link "${lto_link}" "-Wall")
    # gcc's middle-end warnings, off in its sanitizer builds (sanitizer.cmake) and on without one
    configure(gcc_asan -DUSE_LTO=OFF -DUSE_SANITIZER=address)
    expect(gcc_asan compile "${gcc_asan_compile}" "-Wno-maybe-uninitialized")
    expect(gcc_asan compile "${gcc_asan_compile}" "-Wno-stringop-overflow")
    expect(gcc_asan compile "${gcc_asan_compile}" "-Wno-disabled-optimization")
    expect(gcc_asan compile "${gcc_asan_compile}" "-Wno-uninitialized")
    expect_not(release compile "${release_compile}" "-Wno-maybe-uninitialized")
endif()

if(id STREQUAL "Clang")
    configure(clang_asan -DUSE_LTO=ON -DUSE_STD_LIB=libstdc++ -DUSE_SANITIZER=address)
    expect_not(clang_asan compile "${clang_asan_compile}" "-flto")
endif()
message(STATUS "build_options: ${id}, every check passed")
