# Driver of the host_build test (cmake -P). Scenarios: a) no shared root: two trees, two private host trees (real
# directories) b) shared: two trees, one <root>/hello-<key>, both <tree>/hello_host_build link to it, built at the same
# time c) another forwarded value (USE_*) -> another key d) share turned off again: the link becomes a private host tree
cmake_minimum_required(VERSION 3.25)

# One build of the parallel step (run.cmake -DBUILD_ONE=<tree> -DLOG=<file>): its output goes to a file, because the
# parallel COMMANDs of one execute_process are a pipeline - a tree that writes into it after the next one has exited
# dies of SIGPIPE.
if(BUILD_ONE)
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build ${BUILD_ONE}
        RESULT_VARIABLE rc
        OUTPUT_FILE ${LOG}
        ERROR_FILE ${LOG})
    if(NOT rc EQUAL 0)
        file(READ ${LOG} out)
        message(FATAL_ERROR "build of ${BUILD_ONE} failed:\n${out}")
    endif()
    return()
endif()

foreach(v HELPERS_DIR CONSUMER_DIR WORK_DIR GENERATOR)
    if(NOT ${v})
        message(FATAL_ERROR "run.cmake: ${v} is required")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})
set(root ${WORK_DIR}/shared)

function(fail)
    message(FATAL_ERROR "host_build: ${ARGN}")
endfunction()

function(configure tree)
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S ${CONSUMER_DIR} -B ${WORK_DIR}/${tree} -G ${GENERATOR} -DHB_TEST_OUTER=ON
                -DHELPERS_DIR=${HELPERS_DIR} ${ARGN}
        RESULT_VARIABLE rc
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(NOT rc EQUAL 0)
        fail("configure ${tree} failed:\n${out}")
    endif()
endfunction()

function(build)
    set(commands)
    foreach(tree IN LISTS ARGN)
        list(
            APPEND
            commands
            COMMAND
            ${CMAKE_COMMAND}
            -DBUILD_ONE=${WORK_DIR}/${tree}
            -DLOG=${WORK_DIR}/${tree}.log
            -P
            ${CMAKE_CURRENT_LIST_FILE})
    endforeach()
    # Several COMMANDs run at the same time.
    execute_process(
        ${commands} RESULTS_VARIABLE rcs
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    foreach(rc IN LISTS rcs)
        if(NOT rc EQUAL 0)
            fail("build of ${ARGN} failed (${rcs}):\n${out}")
        endif()
    endforeach()
endfunction()

function(expect_private tree)
    set(d ${WORK_DIR}/${tree}/hello_host_build)
    if(IS_SYMLINK ${d} OR NOT IS_DIRECTORY ${d})
        fail("${tree}: expected a private host tree at ${d}")
    endif()
endfunction()

function(link_of tree out)
    set(d ${WORK_DIR}/${tree}/hello_host_build)
    if(NOT IS_SYMLINK ${d})
        fail("${tree}: expected a link at ${d}")
    endif()
    file(READ_SYMLINK ${d} target)
    set(${out}
        ${target}
        PARENT_SCOPE)
endfunction()

function(shared_trees out)
    file(
        GLOB dirs
        LIST_DIRECTORIES true
        ${root}/hello-*)
    list(FILTER dirs EXCLUDE REGEX "\\.lock$")
    set(${out}
        ${dirs}
        PARENT_SCOPE)
endfunction()

set(share -DHOST_BUILD_SHARED_ROOT=${root} -DHOST_BUILD_SHARED_TARGETS=hello)

# a) the default: private host trees
configure(a1)
configure(a2)
build(a1 a2)
expect_private(a1)
expect_private(a2)
if(EXISTS ${root})
    fail("a: ${root} created without HOST_BUILD_SHARED_ROOT")
endif()

# b) shared: one tree for both, built at the same time
configure(b1 ${share})
configure(b2 ${share})
link_of(b1 l1)
link_of(b2 l2)
shared_trees(trees)
list(LENGTH trees n)
if(NOT n EQUAL 1
   OR NOT l1 STREQUAL l2
   OR NOT l1 IN_LIST trees)
    fail("b: expected one shared tree linked from both, got ${trees} (links ${l1}, ${l2})")
endif()
build(b1 b2)
if(NOT EXISTS ${l1}/hello)
    fail("b: ${l1}/hello not built")
endif()
if(GENERATOR STREQUAL "Ninja")
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build ${l1} -- -n
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out)
    if(NOT out MATCHES "no work to do")
        fail("b: shared tree not up to date after the parallel build:\n${out}")
    endif()
endif()

# c) another forwarded value: another key
configure(c1 ${share} -DUSE_HB_TEST_OPTION=ON)
link_of(c1 l3)
shared_trees(trees)
list(LENGTH trees n)
if(NOT n EQUAL 2 OR l3 STREQUAL l1)
    fail("c: expected a second shared tree for USE_HB_TEST_OPTION, got ${trees}")
endif()
build(c1)

# d) share turned off: the link becomes a private host tree again, the shared tree stays
configure(b1 -DHOST_BUILD_SHARED_ROOT=)
expect_private(b1)
build(b1)
if(NOT EXISTS ${l1}/hello)
    fail("d: the shared tree lost its build when b1 left it")
endif()

message(STATUS "host_build: all scenarios passed")
