set(USE_SANITIZER
    none
    CACHE STRING "Choose the Sanitizer to use, options are: none thread address fuzzer")
set_property(CACHE USE_SANITIZER PROPERTY STRINGS none thread address fuzzer)

set(sanitizer_common_flags -ggdb -fno-omit-frame-pointer -fsanitize-recover=all)

set(sanitizer_common_flags_clang ${sanitizer_common_flags})

set(sanitizer_common_flags_gcc ${sanitizer_common_flags})

set(sanitizer_thread_flags_clang ${sanitizer_common_flags_clang}
                                 -fsanitize=thread,undefined,integer,implicit-conversion,nullability)

set(sanitizer_thread_flags_gcc ${sanitizer_common_flags_gcc} -fsanitize=thread,undefined)

set(sanitizer_address_flags_clang ${sanitizer_common_flags_clang}
                                  -fsanitize=address,undefined,integer,implicit-conversion,nullability)

set(sanitizer_fuzzer_flags_clang ${sanitizer_common_flags_clang}
                                 -fsanitize=address,undefined,integer,implicit-conversion,nullability,fuzzer)

set(sanitizer_address_flags_gcc ${sanitizer_common_flags_gcc} -fsanitize=address,undefined)

if("${USE_SANITIZER}" STREQUAL "thread")
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
        set(sanitizer_cxx_flags ${sanitizer_thread_flags_clang})
        set(sanitizer_c_flags ${sanitizer_thread_flags_clang})
        set(sanitizer_linker_flags ${sanitizer_thread_flags_clang})
    else()
        set(sanitizer_cxx_flags ${sanitizer_thread_flags_gcc})
        set(sanitizer_c_flags ${sanitizer_thread_flags_gcc})
        set(sanitizer_linker_flags ${sanitizer_thread_flags_gcc})
    endif()
elseif("${USE_SANITIZER}" STREQUAL "address")
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
        set(sanitizer_cxx_flags ${sanitizer_address_flags_clang})
        set(sanitizer_c_flags ${sanitizer_address_flags_clang})
        set(sanitizer_linker_flags ${sanitizer_address_flags_clang})
    else()
        set(sanitizer_cxx_flags ${sanitizer_address_flags_gcc})
        set(sanitizer_c_flags ${sanitizer_address_flags_gcc})
        set(sanitizer_linker_flags ${sanitizer_address_flags_gcc})
    endif()
elseif("${USE_SANITIZER}" STREQUAL "fuzzer")
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
        set(sanitizer_cxx_flags ${sanitizer_fuzzer_flags_clang})
        set(sanitizer_c_flags ${sanitizer_fuzzer_flags_clang})
        set(sanitizer_linker_flags ${sanitizer_fuzzer_flags_clang})
    else()
        message(FATAL_ERROR "invalid USE_SANITIZER ${USE_SANITIZER} for gcc")
    endif()
elseif("${USE_SANITIZER}" STREQUAL "none")
    set(sanitizer_cxx_flags)
    set(sanitizer_c_flags)
    set(sanitizer_linker_flags)
else()
    message(FATAL_ERROR "invalid USE_SANITIZER ${USE_SANITIZER} use none, address, thread or fuzzer")
endif()

function(target_add_sanitizer_flags target scope)
    target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:CXX>:${sanitizer_cxx_flags}>)
    target_compile_options(${target} ${scope} $<$<COMPILE_LANGUAGE:C>:${sanitizer_c_flags}>)
    target_link_options(${target} PUBLIC ${sanitizer_linker_flags})
endfunction()
