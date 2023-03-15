set(
  USE_STDLIB_DEBUG
  false
  CACHE BOOL "Set debug flags for used stdlib"
)

set(
  STD_LIB
  libstdc++
  CACHE STRING "Choose the stdlib to use, options are: libc++ libstdc++"
)
set_property(CACHE STD_LIB PROPERTY STRINGS libc++ libstdc++)

set(
  std_lib_libcpp_debug_cxx_flags
  -D_LIBCPP_DEBUG=1
  -D_LIBCPP_ENABLE_NODISCARD
)

set(std_lib_libcpp_debug_c_flags)
set(std_lib_libcpp_debug_linker_flags)

set(
  std_lib_libstdcpp_debug_cxx_flags
  -D_GLIBCXX_DEBUG
  -D_GLIBCXX_DEBUG_PEDANTIC
)

set(std_lib_libstdcpp_debug_c_flags)
set(std_lib_libstdcpp_debug_linker_flags)

function(target_add_stdlib_debug_flags target)
  if(USE_STDLIB_DEBUG)
    if("${STD_LIB}" STREQUAL "libc++")
      target_compile_options(${target} PUBLIC $<$<COMPILE_LANGUAGE:CXX>:${std_lib_libcpp_debug_cxx_flags}>)
      target_compile_options(${target} PUBLIC $<$<COMPILE_LANGUAGE:C>:${std_lib_libcpp_debug_c_flags}>)
      target_link_options(${target} PUBLIC ${std_lib_libcpp_debug_linker_flags})
    else()
      target_compile_options(${target} PUBLIC $<$<COMPILE_LANGUAGE:CXX>:${std_lib_libstdcpp_debug_cxx_flags}>)
      target_compile_options(${target} PUBLIC $<$<COMPILE_LANGUAGE:C>:${std_lib_libstdcpp_debug_c_flags}>)
      target_link_options(${target} PUBLIC ${std_lib_libstdcpp_debug_linker_flags})
    endif()
  endif()
endfunction()

function(target_add_stdlib_flags target)
  if("${STD_LIB}" STREQUAL "libc++" AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    target_compile_options(${target} PUBLIC $<$<COMPILE_LANGUAGE:CXX>:-stdlib=libc++>)
    target_link_options(${target} PUBLIC -fuse-ld=lld -stdlib=libc++)
  elseif("${STD_LIB}" STREQUAL "libstdc++" AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    #target_compile_options(${target} PUBLIC $<$<COMPILE_LANGUAGE:CXX>:-stdlib=libstdc++>)
    #target_link_options(${target} PUBLIC -fuse-ld=lld -stdlib=libstdc++)
  elseif("${STD_LIB}" STREQUAL "libc++" AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    target_compile_options(${target} PUBLIC $<$<COMPILE_LANGUAGE:CXX>:-nostdinc++ -I/usr/include/c++/v1>)
    target_link_options(${target} PUBLIC -nodefaultlibs -lc++ -lc++abi -lm -lc -lc_nonshared -lgcc_s -lgcc)
  elseif("${STD_LIB}" STREQUAL "libstdc++" AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  else()
    message(AUTHOR_WARNING "something wrong")
  endif()
endfunction()
