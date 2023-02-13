function(configure_host_build targetname)
  set(extra_args)
  if(${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.19.0")
    set(extra_args COMMAND_ERROR_IS_FATAL ANY)
  endif()

  #if(${CMAKE_VERSION} VERSION_LESS "3.24.0")
    unset(ENV{CC})
    unset(ENV{CXX})
  #endif()

  set(build_dir ${CMAKE_CURRENT_BINARY_DIR}/host_build)

  execute_process(
    COMMAND ${CMAKE_COMMAND} -E make_directory ${build_dir}
    COMMAND ${CMAKE_COMMAND} -S ${CMAKE_CURRENT_LIST_DIR} -B ${build_dir}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    RESULT_VARIABLE STATUS
    ${extra_args}
  )

  if(STATUS AND NOT STATUS EQUAL 0)
    message(FATAL_ERROR "configuring ${targetname} failed!")
  endif()

  add_custom_target(
    ${targetname}
    COMMAND ${CMAKE_COMMAND} --build ${build_dir}
    WORKING_DIRECTORY ${build_dir}
    BYPRODUCTS ${build_dir}/${targetname}
  )
endfunction()
