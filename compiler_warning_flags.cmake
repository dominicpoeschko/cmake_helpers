set(
  USE_ALL_WARNINGS
  true
  CACHE BOOL "Enable \"all\" warnings"
)

if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
  if(USE_ALL_WARNINGS)
    if(${CPP_STANDARD} GREATER 11)
      set(compat_flag)
    else()
      set(
        compat_flag
        -Wc++11-compat
        -Wc++11-compat-deprecated-writable-strings
        -Wc++11-compat-pedantic
      )
    endif()

    set(
      cxx_warning_flags
      -Wno-c++98-compat
      -Wno-c++98-compat-pedantic
      -Wno-c++20-compat
      -Wno-weak-vtables
      -Wno-c++17-extensions
      ${compat_flag}
      -Weverything
      -Wpedantic
      -Wno-padded
    )

    set(
      c_warning_flags
      -Weverything
      -Wpedantic
      -Wno-padded
    )
  else()
    set(
      cxx_warning_flags
      -Wall
      -Wextra
      -Wpedantic
    )

    set(
      c_warning_flags
      -Wall
      -Wextra
      -Wpedantic
    )
  endif()
elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  if(USE_ALL_WARNINGS)
    set(
      cxx_warning_flags
      -Wpedantic
      -Wall
      -Wcast-align
      -Wcast-qual
      -Wdisabled-optimization
      -Wextra
      -Wformat=2
      -Winit-self
      -Wlogical-op
      -Wmissing-declarations
      -Wmissing-include-dirs
      -Woverloaded-virtual
      -Wredundant-decls
      -Wshadow
      -Wsign-conversion
      -Wsign-promo
      -Wstrict-aliasing=1
      -Wstrict-null-sentinel
      -Wno-attributes
      #-Wstrict-overflow=2
      -Wundef
    )

    set(
      c_warning_flags
      -Wall
      -Wbad-function-cast
      -Wcast-align
      -Wcast-qual
      -Wextra
      -Wformat=2
      -Wformat-nonliteral
      -Winline
      -Wnested-externs
      -Wpedantic
      -Wpointer-arith
      -Wshadow
      -#Wstrict-overflow=5
      -Wundef
      -Wunreachable-code
      -Wwrite-strings
    )
  else()
    set(
      cxx_warning_flags
      -Wall
      -Wextra
      -Wpedantic
    )

    set(
      c_warning_flags
      -Wall
      -Wextra
      -Wpedantic
    )
  endif()
elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
  if(USE_ALL_WARNINGS)
    set(
      cxx_warning_flags
      /W4
      /permissive
    )

    set(
      c_warning_flags
      /W4
      /permissive
    )
  else()
    set(
      cxx_warning_flags
      /W4
    )

    set(
      c_warning_flags
      /W4
    )
  endif()

else()
  message(FATAL_ERROR "no valid compiler")
endif()

function(target_add_warning_flags target scope)
  target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:CXX>:${cxx_warning_flags}>)
  target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:C>:${c_warning_flags}>)
endfunction()
