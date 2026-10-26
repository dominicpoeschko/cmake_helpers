# Stand-in for CMake's FetchContent (found first through CMAKE_MODULE_PATH): records what FindOrFetch.cmake hands to
# FetchContent instead of fetching anything.
function(FetchContent_Declare name)
    file(APPEND "${PROBE_OUT}" "declare ${name}: ${ARGN}\n")
endfunction()
function(FetchContent_MakeAvailable)
    file(APPEND "${PROBE_OUT}" "make_available: ${ARGN}\n")
endfunction()
function(FetchContent_Populate name)
    file(APPEND "${PROBE_OUT}" "populate ${name}: ${ARGN}\n")
    set(${name}_SOURCE_DIR
        "populated-src"
        PARENT_SCOPE)
    set(${name}_BINARY_DIR
        "populated-build"
        PARENT_SCOPE)
    set(${name}_POPULATED
        TRUE
        PARENT_SCOPE)
endfunction()
