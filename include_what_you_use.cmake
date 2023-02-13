set(
  USE_INCLUDE_WHAT_YOU_USE
  false
  CACHE BOOL "include-what-you-use"
)

if(USE_INCLUDE_WHAT_YOU_USE)
  find_program(
    INCLUDE_WHAT_YOU_USE_EXE
    NAMES "include-what-you-use"
    DOC "Path to include-what-you-use executable"
  )

  mark_as_advanced(FORCE INCLUDE_WHAT_YOU_USE_EXE)

  if(NOT INCLUDE_WHAT_YOU_USE_EXE)
    message(FATAL_ERROR "include-what-you-use not found.")
  else()
    set(
      common_include_what_you_use
      ${INCLUDE_WHAT_YOU_USE_EXE}
      #-Xiwyu --transitive_includes_only
      -Xiwyu --no_fwd_decls
      -Xiwyu --verbose=1
    )

    set(
      DO_INCLUDE_WHAT_YOU_USE_CXX
      ${common_include_what_you_use}
    )
    set(
      DO_INCLUDE_WHAT_YOU_USE_C
      ${common_include_what_you_use}
    )
  endif()
endif()

function(target_add_include_what_you_use_flags target)
  if(USE_INCLUDE_WHAT_YOU_USE)
    set_target_properties(${target} PROPERTIES CXX_INCLUDE_WHAT_YOU_USE "${DO_INCLUDE_WHAT_YOU_USE_CXX}")
    set_target_properties(${target} PROPERTIES C_INCLUDE_WHAT_YOU_USE "${DO_INCLUDE_WHAT_YOU_USE_C}")
    set_target_properties(${target} PROPERTIES LINK_WHAT_YOU_USE TRUE)
  endif()
endfunction()
