set(USE_FORCE_FETCH
    false
    CACHE BOOL "Force FindOrFetch to always fetch")

set(USE_GIT_BRANCH
    false
    CACHE BOOL "Use git clone with GIT_BRANCH instead of DOWNLOAD_URL when both are provided")

set(USE_GIT_TAG
    false
    CACHE BOOL "Use git clone with GIT_TAG instead of DOWNLOAD_URL when both are provided")

# The argument checks both functions share; `fn` names the caller in the messages. Reads PARSED_ARGS_* of the caller.
function(_find_or_fetch_check fn)
    if(PARSED_ARGS_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "unknown argument ${PARSED_ARGS_UNPARSED_ARGUMENTS}")
    endif()

    if(PARSED_ARGS_PATCH_FILE AND (PARSED_ARGS_PATCH_COMMAND OR PARSED_ARGS_UPDATE_COMMAND))
        message(
            FATAL_ERROR
                "Cannot specify PATCH_FILE together with PATCH_COMMAND or UPDATE_COMMAND. Use either PATCH_FILE or manual commands."
        )
    endif()

    if(PARSED_ARGS_GIT_REPOSITORY AND NOT PARSED_ARGS_GIT_TAG)
        message(FATAL_ERROR "${fn} needs GIT_TAG when using GIT_REPOSITORY")
    endif()
endfunction()

# The git ref to check out: GIT_BRANCH under USE_GIT_BRANCH, else GIT_TAG. Reads PARSED_ARGS_* of the caller.
function(_find_or_fetch_ref out)
    set(ref ${PARSED_ARGS_GIT_TAG})
    if(USE_GIT_BRANCH AND PARSED_ARGS_GIT_BRANCH)
        set(ref ${PARSED_ARGS_GIT_BRANCH})
    endif()
    set(${out}
        ${ref}
        PARENT_SCOPE)
endfunction()

# The FetchContent arguments of both functions, into <out>: the git form (when `use_git`) or the URL form, then the
# patch/update commands and SOURCE_SUBDIR. Reads PARSED_ARGS_* of the caller; `ref` is the git ref to check out.
function(_find_or_fetch_args out use_git ref)
    if(use_git)
        set(args GIT_REPOSITORY ${PARSED_ARGS_GIT_REPOSITORY} GIT_TAG ${ref})
        if(PARSED_ARGS_GIT_SHALLOW)
            list(APPEND args GIT_SHALLOW ${PARSED_ARGS_GIT_SHALLOW})
        endif()
        if(NOT PARSED_ARGS_QUIET)
            list(APPEND args GIT_PROGRESS TRUE)
        endif()
    else()
        set(args URL ${PARSED_ARGS_DOWNLOAD_URL})
        if(PARSED_ARGS_DOWNLOAD_HASH)
            list(APPEND args URL_HASH ${PARSED_ARGS_DOWNLOAD_HASH})
        endif()
        list(APPEND args DOWNLOAD_EXTRACT_TIMESTAMP ON)
    endif()

    if(PARSED_ARGS_PATCH_FILE)
        # cmake-format: off
        list(APPEND args
            PATCH_COMMAND git reset --hard HEAD && git clean -fdx && git apply --3way ${PARSED_ARGS_PATCH_FILE}
            UPDATE_COMMAND git fetch origin && git reset --hard ${ref} && git clean -fdx
                && git apply --3way ${PARSED_ARGS_PATCH_FILE}
            UPDATE_DISCONNECTED TRUE)
        # cmake-format: on
    endif()

    if(PARSED_ARGS_PATCH_COMMAND)
        list(APPEND args PATCH_COMMAND ${PARSED_ARGS_PATCH_COMMAND} UPDATE_DISCONNECTED TRUE)
    endif()

    if(PARSED_ARGS_UPDATE_COMMAND)
        list(APPEND args UPDATE_COMMAND ${PARSED_ARGS_UPDATE_COMMAND})
    endif()

    if(PARSED_ARGS_SOURCE_SUBDIR)
        list(APPEND args SOURCE_SUBDIR ${PARSED_ARGS_SOURCE_SUBDIR})
    endif()

    set(${out}
        ${args}
        PARENT_SCOPE)
endfunction()

function(find_or_fetch_package name)

    cmake_parse_arguments(
        PARSE_ARGV 1 PARSED_ARGS "CONFIG;QUIET"
        "GIT_REPOSITORY;GIT_TAG;VERSION;GIT_SHALLOW;GIT_BRANCH;DOWNLOAD_URL;DOWNLOAD_HASH;SOURCE_SUBDIR"
        "COMPONENTS;PATCH_COMMAND;UPDATE_COMMAND;PATCH_FILE")

    _find_or_fetch_check(find_or_fetch_package)
    if(NOT PARSED_ARGS_DOWNLOAD_URL AND NOT PARSED_ARGS_GIT_REPOSITORY)
        message(FATAL_ERROR "find_or_fetch_package needs either DOWNLOAD_URL or GIT_REPOSITORY")
    endif()

    # Determine fetch method: prefer git when USE_GIT_BRANCH/USE_GIT_TAG is set, or when no DOWNLOAD_URL is available.
    set(USE_GIT_FETCH FALSE)
    if(PARSED_ARGS_GIT_REPOSITORY)
        if(USE_GIT_BRANCH AND PARSED_ARGS_GIT_BRANCH)
            set(USE_GIT_FETCH TRUE)
        elseif(USE_GIT_TAG AND PARSED_ARGS_GIT_TAG)
            set(USE_GIT_FETCH TRUE)
        elseif(NOT PARSED_ARGS_DOWNLOAD_URL)
            set(USE_GIT_FETCH TRUE)
        endif()
    endif()

    set(CONFIG_ARG)
    if(PARSED_ARGS_CONFIG)
        set(CONFIG_ARG CONFIG)
    endif()

    set(COMPONENTS_ARG)
    if(PARSED_ARGS_COMPONENTS)
        set(COMPONENTS_ARG COMPONENTS ${PARSED_ARGS_COMPONENTS})
    endif()

    if(NOT PARSED_ARGS_QUIET)
        message(STATUS "Searching for ${name} package...")
    endif()

    if(NOT USE_FORCE_FETCH)
        find_package(${name} ${PARSED_ARGS_VERSION} ${CONFIG_ARG} ${COMPONENTS_ARG} QUIET)
    endif()

    if(${name}_FOUND)
        if(NOT PARSED_ARGS_QUIET)
            message(STATUS "Found ${name} locally")
        endif()
        return()
    endif()

    if(NOT PARSED_ARGS_QUIET)
        if(USE_GIT_FETCH)
            message(STATUS "${name} not found locally, fetching from ${PARSED_ARGS_GIT_REPOSITORY}")
        else()
            message(STATUS "${name} not found locally, downloading from ${PARSED_ARGS_DOWNLOAD_URL}")
        endif()
    endif()

    include(FetchContent)
    _find_or_fetch_ref(ref)
    _find_or_fetch_args(FETCH_ARGS ${USE_GIT_FETCH} "${ref}")

    # SYSTEM: a fetched dependency's headers are third-party code like those of a package find_package() found (imported
    # targets are SYSTEM already) - their warnings are not ours, and USE_WARNINGS_AS_ERRORS must not turn them into
    # errors in a consumer's translation units
    FetchContent_Declare(${name} ${FETCH_ARGS} SYSTEM)
    FetchContent_MakeAvailable(${name})

    if(NOT PARSED_ARGS_QUIET)
        message(STATUS "Successfully fetched ${name}")
    endif()

endfunction()

function(populate_package name)

    cmake_parse_arguments(
        PARSE_ARGV 1 PARSED_ARGS "QUIET" "GIT_REPOSITORY;GIT_TAG;GIT_SHALLOW;GIT_BRANCH;SOURCE_SUBDIR"
        "PATCH_COMMAND;UPDATE_COMMAND;PATCH_FILE")

    # every argument is checked before a pre-fetched source directory is taken: a typo fails with one set too
    _find_or_fetch_check(populate_package)
    if(NOT PARSED_ARGS_GIT_REPOSITORY)
        message(FATAL_ERROR "populate_package needs GIT_REPOSITORY")
    endif()

    # Check for pre-fetched source directory override
    string(TOUPPER "${name}" uppercase_name)
    if(FETCHCONTENT_SOURCE_DIR_${uppercase_name})
        if(NOT IS_DIRECTORY "${FETCHCONTENT_SOURCE_DIR_${uppercase_name}}")
            message(FATAL_ERROR "populate_package(${name}): FETCHCONTENT_SOURCE_DIR_${uppercase_name} points to "
                                "a missing directory: ${FETCHCONTENT_SOURCE_DIR_${uppercase_name}}")
        endif()
        set(${name}_SOURCE_DIR
            "${FETCHCONTENT_SOURCE_DIR_${uppercase_name}}"
            PARENT_SCOPE)
        set(${name}_BINARY_DIR
            "${CMAKE_CURRENT_BINARY_DIR}/${name}-build"
            PARENT_SCOPE)
        set(${name}_POPULATED
            TRUE
            PARENT_SCOPE)
        if(NOT PARSED_ARGS_QUIET)
            message(STATUS "Using pre-fetched ${name} from ${FETCHCONTENT_SOURCE_DIR_${uppercase_name}}")
        endif()
        return()
    endif()

    # The direct FetchContent_Populate(name ...details...) form below bypasses CMake's disconnected-mode handling.
    # Enforce it here before any download or update.
    if(FETCHCONTENT_FULLY_DISCONNECTED)
        message(FATAL_ERROR "populate_package(${name}): no local source in disconnected mode. "
                            "Set FETCHCONTENT_SOURCE_DIR_${uppercase_name} to the prepared dependency directory.")
    endif()

    if(NOT PARSED_ARGS_QUIET)
        message(STATUS "Fetching ${name} from ${PARSED_ARGS_GIT_REPOSITORY}")
    endif()

    include(FetchContent)
    _find_or_fetch_ref(ref)
    _find_or_fetch_args(FETCH_ARGS TRUE "${ref}")

    # Put sources in _deps folder like FetchContent_MakeAvailable does
    list(APPEND FETCH_ARGS SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/_deps/${name}-src BINARY_DIR
         ${CMAKE_CURRENT_BINARY_DIR}/_deps/${name}-build)

    FetchContent_Populate(${name} ${FETCH_ARGS})

    # Propagate FetchContent variables to parent scope
    set(${name}_SOURCE_DIR
        ${${name}_SOURCE_DIR}
        PARENT_SCOPE)
    set(${name}_BINARY_DIR
        ${${name}_BINARY_DIR}
        PARENT_SCOPE)
    set(${name}_POPULATED
        ${${name}_POPULATED}
        PARENT_SCOPE)

    if(NOT PARSED_ARGS_QUIET)
        message(STATUS "Successfully fetched ${name}")
    endif()

endfunction()
