set(USE_CPPLINT
    false
    CACHE BOOL "cpplint")

if(USE_CPPLINT)
    find_program(
        CPPLINT_EXE
        NAMES "cpplint"
        DOC "Path to cpplint executable")

    mark_as_advanced(FORCE CPPLINT_EXE)

    if(NOT CPPLINT_EXE)
        message(FATAL_ERROR "cpplint not found.")
    else()
        set(common_cpplint ${CPPLINT_EXE} --quiet)

        set(common_cpplint_disabled_checks
            whitespace
            legal/copyright
            build/include_order
            readability/todo
            readability/nolint
            runtime/int
            ${GLOBAL_COMMON_CPPLINT_DISABLED_CHECKS})

        set(cxx_cpplint_disabled_checks readability/namespace build/c++11 runtime/references
                                        runtime/indentation_namespace ${GLOBAL_CXX_CPPLINT_DISABLED_CHECKS})

        set(c_cpplint_disabled_checks readability/casting ${GLOBAL_C_CPPLINT_DISABLED_CHECKS})

        list(TRANSFORM common_cpplint_disabled_checks PREPEND "-")
        list(JOIN common_cpplint_disabled_checks "," common_cpplint_disabled_checks)

        list(TRANSFORM cxx_cpplint_disabled_checks PREPEND "-")
        list(JOIN cxx_cpplint_disabled_checks "," cxx_cpplint_disabled_checks)

        list(TRANSFORM c_cpplint_disabled_checks PREPEND "-")
        list(JOIN c_cpplint_disabled_checks "," c_cpplint_disabled_checks)

        list(JOIN common_cpplint ";" cpplint)
        set(DO_CPPLINT_CXX ${cpplint} --filter=${common_cpplint_disabled_checks},${cxx_cpplint_disabled_checks})
        set(DO_CPPLINT_C ${cpplint} --extensions=c
                         --filter=${common_cpplint_disabled_checks},${c_cpplint_disabled_checks})
    endif()
endif()

function(target_add_cpplint_flags target)
    if(USE_CPPLINT)
        set_target_properties(${target} PROPERTIES CXX_CPPLINT "${DO_CPPLINT_CXX}")
        set_target_properties(${target} PROPERTIES C_CPPLINT "${DO_CPPLINT_C}")
    endif()
endfunction()
