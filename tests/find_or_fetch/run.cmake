# FindOrFetch.cmake without a network: the FetchContent arguments of every form (against expected.txt, the arguments the
# implementation before the shared builder produced), and the refusals. cmake -DHELPERS_DIR=<cmake_helpers>
# -DWORK_DIR=<dir> -P run.cmake
cmake_minimum_required(VERSION 3.25)
file(REMOVE_RECURSE "${WORK_DIR}")
file(MAKE_DIRECTORY "${WORK_DIR}")
set(failures 0)

# 1. the arguments handed to FetchContent, per form
execute_process(
    COMMAND ${CMAKE_COMMAND} -DHELPERS_DIR=${HELPERS_DIR} -DPROBE_OUT=${WORK_DIR}/probe.txt -P
            ${CMAKE_CURRENT_LIST_DIR}/probe.cmake
    RESULT_VARIABLE rc
    OUTPUT_QUIET
    ERROR_VARIABLE err)
execute_process(COMMAND ${CMAKE_COMMAND} -E compare_files ${CMAKE_CURRENT_LIST_DIR}/expected.txt ${WORK_DIR}/probe.txt
                RESULT_VARIABLE same)
if(NOT rc EQUAL 0 OR NOT same EQUAL 0)
    message(SEND_ERROR "probe: rc ${rc}, output differs from expected.txt (${WORK_DIR}/probe.txt)\n${err}")
    math(EXPR failures "${failures} + 1")
endif()

# 1. calls that must fail, each with the text it must fail with
function(must_fail name pattern body)
    file(
        WRITE "${WORK_DIR}/${name}.cmake"
        "list(PREPEND CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/probe_modules\")\n"
        "set(PROBE_OUT \"${WORK_DIR}/${name}.out\")\n" "include(\"${HELPERS_DIR}/FindOrFetch.cmake\")\n"
        "set(USE_FORCE_FETCH ON)\n" "${body}\n")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P ${WORK_DIR}/${name}.cmake
        RESULT_VARIABLE rc
        OUTPUT_QUIET
        ERROR_VARIABLE err)
    if(rc EQUAL 0 OR NOT err MATCHES "${pattern}")
        message(SEND_ERROR "${name}: rc ${rc}, expected a failure matching '${pattern}', got:\n${err}")
        set(failures
            1
            PARENT_SCOPE)
    else()
        message(STATUS "${name}: refused as expected")
    endif()
endfunction()

set(pre "set(FETCHCONTENT_SOURCE_DIR_X /pre/x)\n")
must_fail(populate_typo_prefetched "unknown argument GIT_TAGG"
          "${pre}populate_package(x GIT_REPOSITORY https://example.invalid/x.git GIT_TAGG v1)")
must_fail(populate_patch_file_and_command_prefetched "Cannot specify PATCH_FILE together with PATCH_COMMAND"
          "${pre}populate_package(x GIT_REPOSITORY u GIT_TAG v1 PATCH_FILE /p PATCH_COMMAND echo)")
must_fail(populate_no_tag_prefetched "populate_package needs GIT_TAG"
          "${pre}populate_package(x GIT_REPOSITORY https://example.invalid/x.git)")
must_fail(populate_no_repository_prefetched "populate_package needs GIT_REPOSITORY"
          "${pre}populate_package(x GIT_TAG v1)")
must_fail(fetch_patch_file_and_update "Cannot specify PATCH_FILE together with PATCH_COMMAND"
          "find_or_fetch_package(x GIT_REPOSITORY u GIT_TAG v1 PATCH_FILE /p UPDATE_COMMAND echo)")
must_fail(populate_prefetched_missing "points to a missing"
          "${pre}populate_package(x GIT_REPOSITORY https://example.invalid/x.git GIT_TAG v1)")
must_fail(populate_disconnected_no_source "no local source in disconnected mode"
          "set(FETCHCONTENT_FULLY_DISCONNECTED ON)\npopulate_package(x GIT_REPOSITORY u GIT_TAG v1)")
must_fail(fetch_typo "unknown argument SOURCE_SUBDIRR"
          "find_or_fetch_package(x GIT_REPOSITORY u GIT_TAG v1 SOURCE_SUBDIRR s)")
must_fail(fetch_no_source "find_or_fetch_package needs either DOWNLOAD_URL or GIT_REPOSITORY"
          "find_or_fetch_package(x)")
must_fail(fetch_no_tag "find_or_fetch_package needs GIT_TAG" "find_or_fetch_package(x GIT_REPOSITORY u)")

if(failures)
    message(FATAL_ERROR "find_or_fetch: failures")
endif()
message(STATUS "find_or_fetch: all cases pass")
