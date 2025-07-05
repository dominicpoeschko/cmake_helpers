function(find_or_fetch_package name)

    cmake_parse_arguments(PARSE_ARGV 1 PARSED_ARGS "CONFIG;QUIET" "GIT_REPOSITORY;GIT_TAG;VERSION;GIT_SHALLOW"
                          "COMPONENTS;PATCH_COMMAND")

    if(PARSED_ARGS_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "unknown argument ${PARSED_ARGS_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT PARSED_ARGS_GIT_REPOSITORY)
        message(FATAL_ERROR "find_or_fetch_package needs GIT_REPOSITORY")
    endif()

    if(NOT PARSED_ARGS_GIT_TAG)
        message(FATAL_ERROR "find_or_fetch_package needs GIT_TAG")
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

    set(QUIET_ARG QUIET)
    if(NOT PARSED_ARGS_QUIET)
        set(QUIET_ARG)
    endif()

    if(NOT PARSED_ARGS_QUIET)
        message(STATUS "Searching for ${name} package...")
    endif()
    find_package(${name} ${VERSION_ARG} ${CONFIG_ARG} ${COMPONENTS_ARG} QUIET)

    if(NOT ${name}_FOUND)
        if(NOT PARSED_ARGS_QUIET)
            message(STATUS "${name} not found locally, fetching from ${PARSED_ARGS_GIT_REPOSITORY}")
        endif()

        include(FetchContent)

        set(FETCH_ARGS GIT_REPOSITORY ${PARSED_ARGS_GIT_REPOSITORY} GIT_TAG ${PARSED_ARGS_GIT_TAG})

        if(NOT PARSED_ARGS_GIT_SHALLOW)
            list(APPEND FETCH_ARGS GIT_SHALLOW TRUE)
        else()
            list(APPEND FETCH_ARGS GIT_SHALLOW ${PARSED_ARGS_GIT_SHALLOW})
        endif()

        if(PARSED_ARGS_PATCH_COMMAND)
            list(APPEND FETCH_ARGS PATCH_COMMAND ${PARSED_ARGS_PATCH_COMMAND} UPDATE_DISCONNECTED 1)
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
