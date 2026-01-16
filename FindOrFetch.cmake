set(USE_FORCE_FETCH
    false
    CACHE BOOL "Force FindOrFetch to always fetch")

set(USE_GIT_BRANCH
    false
    CACHE BOOL "Use git clone with GIT_BRANCH instead of DOWNLOAD_URL when both are provided")

function(find_or_fetch_package name)

    cmake_parse_arguments(
        PARSE_ARGV 1 PARSED_ARGS "CONFIG;QUIET"
        "GIT_REPOSITORY;GIT_TAG;VERSION;GIT_SHALLOW;GIT_BRANCH;DOWNLOAD_URL;DOWNLOAD_HASH;SOURCE_SUBDIR"
        "COMPONENTS;PATCH_COMMAND;UPDATE_COMMAND;PATCH_FILE")

    if(PARSED_ARGS_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "unknown argument ${PARSED_ARGS_UNPARSED_ARGUMENTS}")
    endif()

    if(PARSED_ARGS_PATCH_FILE AND (PARSED_ARGS_PATCH_COMMAND OR PARSED_ARGS_UPDATE_COMMAND))
        message(
            FATAL_ERROR
                "Cannot specify PATCH_FILE together with PATCH_COMMAND or UPDATE_COMMAND. Use either PATCH_FILE or manual commands."
        )
    endif()

    if(NOT PARSED_ARGS_DOWNLOAD_URL AND NOT PARSED_ARGS_GIT_REPOSITORY)
        message(FATAL_ERROR "find_or_fetch_package needs either DOWNLOAD_URL or GIT_REPOSITORY")
    endif()

    if(PARSED_ARGS_GIT_REPOSITORY AND NOT PARSED_ARGS_GIT_TAG)
        message(FATAL_ERROR "find_or_fetch_package needs GIT_TAG when using GIT_REPOSITORY")
    endif()

    # Determine fetch method: prefer git if USE_GIT_BRANCH is set and GIT_BRANCH is provided
    set(USE_GIT_FETCH FALSE)
    if(PARSED_ARGS_GIT_REPOSITORY)
        if(USE_GIT_BRANCH AND PARSED_ARGS_GIT_BRANCH)
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

    set(VERSION_ARG)
    if(PARSED_ARGS_VERSION)
        set(VERSION_ARG ${PARSED_ARGS_VERSION})
    endif()

    set(GIT_REF_ARG ${PARSED_ARGS_GIT_TAG})
    if(USE_GIT_BRANCH AND PARSED_ARGS_GIT_BRANCH)
        set(GIT_REF_ARG ${PARSED_ARGS_GIT_BRANCH})
    endif()

    if(NOT PARSED_ARGS_QUIET)
        message(STATUS "Searching for ${name} package...")
    endif()

    if(NOT USE_FORCE_FETCH)
        find_package(${name} ${VERSION_ARG} ${CONFIG_ARG} ${COMPONENTS_ARG} QUIET)
    endif()

    if(NOT ${name}_FOUND)
        if(NOT PARSED_ARGS_QUIET)
            if(USE_GIT_FETCH)
                message(STATUS "${name} not found locally, fetching from ${PARSED_ARGS_GIT_REPOSITORY}")
            else()
                message(STATUS "${name} not found locally, downloading from ${PARSED_ARGS_DOWNLOAD_URL}")
            endif()
        endif()

        include(FetchContent)

        if(USE_GIT_FETCH)
            set(FETCH_ARGS GIT_REPOSITORY ${PARSED_ARGS_GIT_REPOSITORY} GIT_TAG ${GIT_REF_ARG})

            if(PARSED_ARGS_GIT_SHALLOW)
                list(APPEND FETCH_ARGS GIT_SHALLOW ${PARSED_ARGS_GIT_SHALLOW})
            endif()

            if(NOT PARSED_ARGS_QUIET)
                list(APPEND FETCH_ARGS GIT_PROGRESS TRUE)
            endif()
        else()
            set(FETCH_ARGS URL ${PARSED_ARGS_DOWNLOAD_URL})
            if(PARSED_ARGS_DOWNLOAD_HASH)
                list(APPEND FETCH_ARGS URL_HASH ${PARSED_ARGS_DOWNLOAD_HASH})
            endif()
            list(APPEND FETCH_ARGS DOWNLOAD_EXTRACT_TIMESTAMP ON)
        endif()

        if(PARSED_ARGS_PATCH_FILE)
            list(
                APPEND
                FETCH_ARGS
                PATCH_COMMAND
                git
                reset
                --hard
                HEAD
                &&
                git
                clean
                -fdx
                &&
                git
                apply
                --3way
                ${PARSED_ARGS_PATCH_FILE}
                UPDATE_COMMAND
                git
                fetch
                origin
                &&
                git
                reset
                --hard
                ${GIT_REF_ARG}
                &&
                git
                clean
                -fdx
                &&
                git
                apply
                --3way
                ${PARSED_ARGS_PATCH_FILE}
                UPDATE_DISCONNECTED
                TRUE)
        endif()

        if(PARSED_ARGS_PATCH_COMMAND)
            list(APPEND FETCH_ARGS PATCH_COMMAND ${PARSED_ARGS_PATCH_COMMAND} UPDATE_DISCONNECTED TRUE)
        endif()

        if(PARSED_ARGS_UPDATE_COMMAND)
            list(APPEND FETCH_ARGS UPDATE_COMMAND ${PARSED_ARGS_UPDATE_COMMAND})
        endif()

        if(PARSED_ARGS_SOURCE_SUBDIR)
            list(APPEND FETCH_ARGS SOURCE_SUBDIR ${PARSED_ARGS_SOURCE_SUBDIR})
        endif()

        FetchContent_Declare(${name} ${FETCH_ARGS})
        FetchContent_MakeAvailable(${name})

        if(NOT PARSED_ARGS_QUIET)
            message(STATUS "Successfully fetched ${name}")
        endif()
    else()
        if(NOT PARSED_ARGS_QUIET)
            message(STATUS "Found ${name} locally")
        endif()
    endif()

endfunction()

function(populate_package name)

    cmake_parse_arguments(
        PARSE_ARGV 1 PARSED_ARGS "QUIET" "GIT_REPOSITORY;GIT_TAG;GIT_SHALLOW;GIT_BRANCH;SOURCE_SUBDIR"
        "PATCH_COMMAND;UPDATE_COMMAND;PATCH_FILE")

    # Check for pre-fetched source directory override
    string(TOUPPER "${name}" uppercase_name)
    if(DEFINED FETCHCONTENT_SOURCE_DIR_${uppercase_name})
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

    if(PARSED_ARGS_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "unknown argument ${PARSED_ARGS_UNPARSED_ARGUMENTS}")
    endif()

    if(PARSED_ARGS_PATCH_FILE AND (PARSED_ARGS_PATCH_COMMAND OR PARSED_ARGS_UPDATE_COMMAND))
        message(
            FATAL_ERROR
                "Cannot specify PATCH_FILE together with PATCH_COMMAND or UPDATE_COMMAND. Use either PATCH_FILE or manual commands."
        )
    endif()

    if(NOT PARSED_ARGS_GIT_REPOSITORY)
        message(FATAL_ERROR "populate_package needs GIT_REPOSITORY")
    endif()

    if(NOT PARSED_ARGS_GIT_TAG)
        message(FATAL_ERROR "populate_package needs GIT_TAG")
    endif()

    set(GIT_REF_ARG ${PARSED_ARGS_GIT_TAG})
    if(USE_GIT_BRANCH AND PARSED_ARGS_GIT_BRANCH)
        set(GIT_REF_ARG ${PARSED_ARGS_GIT_BRANCH})
    endif()

    if(NOT PARSED_ARGS_QUIET)
        message(STATUS "Fetching ${name} from ${PARSED_ARGS_GIT_REPOSITORY}")
    endif()

    include(FetchContent)

    set(FETCH_ARGS GIT_REPOSITORY ${PARSED_ARGS_GIT_REPOSITORY} GIT_TAG ${GIT_REF_ARG})

    if(PARSED_ARGS_GIT_SHALLOW)
        list(APPEND FETCH_ARGS GIT_SHALLOW ${PARSED_ARGS_GIT_SHALLOW})
    endif()

    if(NOT PARSED_ARGS_QUIET)
        list(APPEND FETCH_ARGS GIT_PROGRESS TRUE)
    endif()

    if(PARSED_ARGS_PATCH_FILE)
        list(
            APPEND
            FETCH_ARGS
            PATCH_COMMAND
            git
            reset
            --hard
            HEAD
            &&
            git
            clean
            -fdx
            &&
            git
            apply
            --3way
            ${PARSED_ARGS_PATCH_FILE}
            UPDATE_COMMAND
            git
            fetch
            origin
            &&
            git
            reset
            --hard
            ${GIT_REF_ARG}
            &&
            git
            clean
            -fdx
            &&
            git
            apply
            --3way
            ${PARSED_ARGS_PATCH_FILE}
            UPDATE_DISCONNECTED
            TRUE)
    endif()

    if(PARSED_ARGS_PATCH_COMMAND)
        list(APPEND FETCH_ARGS PATCH_COMMAND ${PARSED_ARGS_PATCH_COMMAND} UPDATE_DISCONNECTED TRUE)
    endif()

    if(PARSED_ARGS_UPDATE_COMMAND)
        list(APPEND FETCH_ARGS UPDATE_COMMAND ${PARSED_ARGS_UPDATE_COMMAND})
    endif()

    if(PARSED_ARGS_SOURCE_SUBDIR)
        list(APPEND FETCH_ARGS SOURCE_SUBDIR ${PARSED_ARGS_SOURCE_SUBDIR})
    endif()

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
