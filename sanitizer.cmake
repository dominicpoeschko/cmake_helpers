set(USE_SANITIZER
    none
    CACHE STRING "Choose the Sanitizer to use, options are: none thread address fuzzer")
set_property(CACHE USE_SANITIZER PROPERTY STRINGS none thread address fuzzer)

set(USE_EXTRA_SANITIZERS
    ON
    CACHE BOOL "Enable extra clang sanitizer flags: integer, implicit-conversion, nullability")

set(sanitizer_common_flags -ggdb -fno-omit-frame-pointer -fsanitize-recover=all)

set(sanitizer_common_flags_clang ${sanitizer_common_flags})

set(sanitizer_common_flags_gcc ${sanitizer_common_flags})

if(USE_EXTRA_SANITIZERS)
    set(sanitizer_extra_flags ,integer,implicit-conversion,nullability)
else()
    set(sanitizer_extra_flags)
endif()

set(sanitizer_thread_flags_clang ${sanitizer_common_flags_clang} -fsanitize=thread${sanitizer_extra_flags})

# gcc's middle-end warnings misread sanitizer-instrumented code at -O2 and up: maybe-uninitialized inside libstdc++'s
# <regex> and on a conditional's aggregate temporaries, uninitialized inside libstdc++'s checked vector (_Safe_vector)
# under nlohmann::json, stringop-overflow "writing 1 byte into a region of size 0" in a vector's push_back - code that
# builds warning-free without the sanitizer. And the instrumentation makes a big test function too big for a pass:
# disabled-optimization "ext-dce disabled: 5602 basic blocks". Off in sanitizer builds; the build without one has them
# (its LTO link included). A -Wno- of a specific warning beats -Wall whatever the order.
set(sanitizer_gcc_warning_flags -Wno-maybe-uninitialized -Wno-uninitialized -Wno-stringop-overflow
                                -Wno-disabled-optimization)

set(sanitizer_thread_flags_gcc ${sanitizer_common_flags_gcc} -fsanitize=thread ${sanitizer_gcc_warning_flags})

set(sanitizer_address_flags_clang ${sanitizer_common_flags_clang} -fsanitize=address,undefined${sanitizer_extra_flags})

set(sanitizer_fuzzer_flags_clang ${sanitizer_common_flags_clang}
                                 -fsanitize=address,undefined${sanitizer_extra_flags},fuzzer)

set(sanitizer_address_flags_gcc ${sanitizer_common_flags_gcc} -fsanitize=address,undefined
                                ${sanitizer_gcc_warning_flags})

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
