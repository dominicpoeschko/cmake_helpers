set(USE_CPPCHECK
    false
    CACHE BOOL "cppcheck")

if(USE_CPPCHECK)
    find_program(
        CPPCHECK_EXE
        NAMES "cppcheck"
        DOC "Path to cppcheck executable")

    mark_as_advanced(FORCE CPPCHECK_EXE)

    if(NOT CPPCHECK_EXE)
        message(FATAL_ERROR "cppcheck not found.")
    else()
        set(common_cppcheck ${CPPCHECK_EXE} --check-config -q --enable=all --suppress=*:*third_party \*)

        set(common_cppcheck_disabled_checks unknownMacro missingIncludeSystem unusedFunction unmatchedSuppression
                                            ${GLOBAL_COMMON_CPPCHECK_DISABLED_CHECKS})

        set(cxx_cppcheck_disabled_checks ${GLOBAL_CXX_CPPCHECK_DISABLED_CHECKS})
        set(c_cppcheck_disabled_checks ${GLOBAL_C_CPPCHECK_DISABLED_CHECKS})

        list(TRANSFORM common_cppcheck_disabled_checks PREPEND "--suppress=")
        list(JOIN common_cppcheck_disabled_checks ";" common_cppcheck_disabled_checks)

        list(TRANSFORM cxx_cppcheck_disabled_checks PREPEND "--suppress=")
        list(JOIN cxx_cppcheck_disabled_checks ";" cxx_cppcheck_disabled_checks)

        list(TRANSFORM c_cppcheck_disabled_checks PREPEND "--suppress=")
        list(JOIN c_cppcheck_disabled_checks ";" c_cppcheck_disabled_checks)

        list(JOIN common_cppcheck ";" cppcheck)

        set(DO_CPPCHECK_CXX ${cppcheck} ${common_cppcheck_disabled_checks} ${cxx_cppcheck_disabled_checks})

        set(DO_CPPCHECK_C ${cppcheck} ${common_cppcheck_disabled_checks} ${c_cppcheck_disabled_checks})
    endif()
endif()

function(target_add_cppcheck_flags target)
    if(USE_CPPCHECK)
        set_target_properties(${target} PROPERTIES CXX_CPPCHECK "${DO_CPPCHECK_CXX}")
        set_target_properties(${target} PROPERTIES C_CPPCHECK "${DO_CPPCHECK_C}")
    endif()
endfunction()
