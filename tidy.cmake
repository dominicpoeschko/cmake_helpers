# clang-tidy while compiling (USE_TIDY=ON): target_add_tidy_flags(<target> <scope>) sets the target's C/CXX_CLANG_TIDY.
# The checks come from a configuration file, never from a list here: TIDY_CONFIG_FILE when it is set (passed with
# --config-file; a host build configured inside another project receives it through HostBuild's ^TIDY forwarding), else
# clang-tidy's own lookup of the nearest .clang-tidy above each source. Findings are warnings in the build output of the
# objects that are rebuilt.

set(USE_TIDY
    OFF
    CACHE BOOL "run clang-tidy while compiling")
set(TIDY_CONFIG_FILE
    ""
    CACHE FILEPATH "clang-tidy configuration passed with --config-file (empty: clang-tidy's own .clang-tidy lookup)")

if(USE_TIDY)
    find_program(
        CLANG_TIDY_EXE
        NAMES "clang-tidy"
        DOC "Path to clang-tidy executable")
    mark_as_advanced(FORCE CLANG_TIDY_EXE)
    if(NOT CLANG_TIDY_EXE)
        message(FATAL_ERROR "USE_TIDY: clang-tidy not found")
    endif()
    set(DO_CLANG_TIDY "${CLANG_TIDY_EXE}" "--quiet")
    if(TIDY_CONFIG_FILE)
        if(NOT EXISTS "${TIDY_CONFIG_FILE}")
            message(FATAL_ERROR "USE_TIDY: TIDY_CONFIG_FILE ${TIDY_CONFIG_FILE} does not exist")
        endif()
        list(APPEND DO_CLANG_TIDY "--config-file=${TIDY_CONFIG_FILE}")
    endif()
endif()

function(target_add_tidy_flags target scope)
    if(USE_TIDY)
        set_target_properties(${target} PROPERTIES CXX_CLANG_TIDY "${DO_CLANG_TIDY}" C_CLANG_TIDY "${DO_CLANG_TIDY}")
    endif()
endfunction()
