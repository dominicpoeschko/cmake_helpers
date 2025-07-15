function(configure_host_build targetname)

    cmake_parse_arguments(PARSE_ARGV 1 PARSED_ARGS "CLEAR_ENV" "" "")

    set(extra_args)
    if(${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.19.0")
        set(extra_args COMMAND_ERROR_IS_FATAL ANY)
    endif()

    if(PARSED_ARGS_CLEAR_ENV)
        unset(ENV{CC})
        unset(ENV{CXX})
    endif()

    set(build_dir ${CMAKE_CURRENT_BINARY_DIR}/host_build)

    get_cmake_property(all_variables VARIABLES)
    set(cmake_extra_args)
    foreach(variable_name ${all_variables})
        if(variable_name MATCHES "^USE")
            list(APPEND cmake_extra_args "-D${variable_name}=${${variable_name}}")
        endif()
        if(variable_name MATCHES "^CMAKE_BUILD_TYPE")
            list(APPEND cmake_extra_args "-D${variable_name}=${${variable_name}}")
        endif()
    endforeach()

    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${build_dir}
        COMMAND ${CMAKE_COMMAND} -S ${CMAKE_CURRENT_LIST_DIR} -B ${build_dir} ${cmake_extra_args}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        RESULT_VARIABLE STATUS ${extra_args})

    if(STATUS AND NOT STATUS EQUAL 0)
        message(FATAL_ERROR "configuring ${targetname} failed!")
    endif()

    add_custom_target(
        ${targetname}
        COMMAND ${CMAKE_COMMAND} --build ${build_dir}
        WORKING_DIRECTORY ${build_dir}
        BYPRODUCTS ${build_dir}/${targetname})
endfunction()
