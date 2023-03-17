if(NOT CMAKE_BUILD_TYPE)
  set(
    CMAKE_BUILD_TYPE
    Release
    CACHE STRING "Choose the type of build, options are: Release Debug" FORCE
  )
elseif(
  ("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
  OR ("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
)
  set(
    CMAKE_BUILD_TYPE
    ${CMAKE_BUILD_TYPE}
    CACHE STRING "Choose the type of build, options are: Release Debug" FORCE
  )
else()
  message(
    FATAL_ERROR
    "invalid CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE} use Release or Debug"
  )
endif()
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Release" "Debug")

set(
  CPP_STANDARD
  "20"
  CACHE STRING "Choose the C++ Standard, options are: 11 14 17 20 23"
)
set_property(CACHE CPP_STANDARD PROPERTY STRINGS "11" "14" "17" "20" "23")

set(
  C_STANDARD
  "20"
  CACHE STRING "Choose the C Standard, options are: 99 11 17 20"
)
set_property(CACHE C_STANDARD PROPERTY STRINGS "99" "11" "17" "20")

set(
  OPTIMIZE_LEVEL
  "3"
  CACHE STRING "Choose the optimize level, options are: g 0 1 2 3 s fast"
)
set_property(CACHE OPTIMIZE_LEVEL PROPERTY STRINGS "g" "0" "1" "2" "3" "s" "fast")

set(
  USE_LTO
  true
  CACHE BOOL "link time optimization"
)

set(
  USE_RTTI
  false
  CACHE BOOL "runtime type information"
)

set(
  USE_FASTMATH
  false
  CACHE BOOL "fast math!"
)

set(
    USE_STRIP
  false
  CACHE BOOL "strip the binary"
)

if(CMAKE_SIZEOF_VOID_P MATCHES 8)
  set(
    USE_NATIVE_FLAG
    true
    CACHE BOOL "use march=native"
  )
else()
  set(
    USE_NATIVE_FLAG
    false
    CACHE BOOL "use march=native"
  )
endif()

set(optimize_flag -O${OPTIMIZE_LEVEL})

if(USE_LTO)
  set(lto_flag -flto)
else()
  set(lto_flag)
endif()

if(USE_FASTMATH)
  set(fastmath_flag -ffast-math)
else()
  set(fastmath_flag)
endif()

if(USE_STRIP AND "${USE_SANITIZER}" STREQUAL "none" AND "${CMAKE_BUILD_TYPE}" STREQUAL "Release")
  set(strip_flag -s)
else()
  set(strip_flag)
endif()

if("${USE_SANITIZER}" STREQUAL "none")
  if(USE_RTTI)
    set(rtti_flag)
  else()
    set(rtti_flag -fno-rtti)
  endif()
else()
  set(rtti_flag)
endif()

if(${CMAKE_CROSSCOMPILING})
  set(native_flag)
else()
  if(USE_NATIVE_FLAG)
    set(native_flag -march=native)
  else()
    set(native_flag)
  endif()
endif()

set(CMAKE_CXX_FLAGS_DEBUG "")
set(CMAKE_CXX_FLAGS_RELEASE "")

function(target_add_optimizer_flags target scope)
  target_link_options(${target} ${scope} "${strip_flag}")

  set_target_properties(${target} PROPERTIES CXX_STANDARD ${CPP_STANDARD})
  set_target_properties(${target} PROPERTIES CXX_STANDARD_REQUIRED TRUE)
  set_target_properties(${target} PROPERTIES CXX_EXTENSIONS FALSE)

  set_target_properties(${target} PROPERTIES C_STANDARD ${C_STANDARD})
  set_target_properties(${target} PROPERTIES C_STANDARD_REQUIRED TRUE)
  set_target_properties(${target} PROPERTIES C_EXTENSIONS FALSE)

  if("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
        target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:CXX>:/O2 -DNDEBUG>)
        target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:C>:/O2 -DNDEBUG>)
    else()
        if("${STD_LIB}" STREQUAL "libstdc++" AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
            set(tmp_lto_flag)
        else()
            set(tmp_lto_flag ${lto_flag})
        endif()
        target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:CXX>:${fastmath_flag} ${optimize_flag} ${tmp_lto_flag} ${native_flag} ${rtti_flag} -DNDEBUG>)
        target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:C>:${fastmath_flag} ${optimize_flag} ${tmp_lto_flag} ${native_flag} -DNDEBUG>)
        target_link_options(${target} ${scope} ${tmp_lto_flag} ${native_flag})
    endif()
  else()
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
    else()
        target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:CXX>:${fastmath_flag} ${optimize_flag} ${lto_flag} ${rtti_flag} -ggdb>)
        target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:C>:${fastmath_flag} ${optimize_flag} ${lto_flag} -ggdb>)
        target_link_options(${target} ${scope} ${lto_flag} ${native_flag})
    endif()
  endif()

endfunction()
