set(
  USE_TIDY
  false
  CACHE BOOL "clang tidy"
)

if(USE_TIDY)
  find_program(
    CLANG_TIDY_EXE
    NAMES "clang-tidy"
    DOC "Path to clang-tidy executable"
  )

  mark_as_advanced(FORCE CLANG_TIDY_EXE)

  if(NOT CLANG_TIDY_EXE)
    message(FATAL_ERROR "clang-tidy not found.")
  else()
    set(
      common_clang_tidy
      ${CLANG_TIDY_EXE}
      -p=.
    )

    set(
      common_clang_tidy_disabled_checks
      cppcoreguidelines-avoid-magic-numbers
      cppcoreguidelines-macro-usage
      google-readability-todo
      llvm-header-guard
      readability-magic-numbers
      llvmlibc*
      altera*
      ${GLOBAL_COMMON_CLANG_TIDY_DISABLED_CHECKS}
    )

    set(
      cxx_clang_tidy_disabled_checks
      cert-dcl21-cpp
      cppcoreguidelines-non-private-member-variables-in-classes
      fuchsia-default-arguments-calls
      fuchsia-default-arguments-declarations
      fuchsia-overloaded-operator
      fuchsia-trailing-return
      google-readability-namespace-comments
      google-runtime-references
      llvm-namespace-comment
      misc-non-private-member-variables-in-classes
      modernize-concat-nested-namespaces
      modernize-use-default-member-init
      modernize-use-nodiscard
      modernize-use-trailing-return-type
      clang-diagnostic-c++17-extensions
      clang-diagnostic-c++20-extensions
      hicpp-named-parameter
      readability-named-parameter
      hicpp-exception-baseclass
      llvm-qualified-auto
      readability-qualified-auto
      bugprone-easily-swappable-parameters
      google-build-using-namespace
      hicpp-use-auto
      modernize-use-auto
      readability-convert-member-functions-to-static
      cppcoreguidelines-avoid-c-arrays
      hicpp-avoid-c-arrays
      modernize-avoid-c-arrays
      google-explicit-constructor
      hicpp-explicit-conversions
      cppcoreguidelines-pro-bounds-pointer-arithmetic
      ${GLOBAL_CXX_CLANG_TIDY_DISABLED_CHECKS}
    )

    set(c_clang_tidy_disabled_checks ${GLOBAL_C_CLANG_TIDY_DISABLED_CHECKS})

    list(TRANSFORM common_clang_tidy_disabled_checks PREPEND "-")
    list(JOIN common_clang_tidy_disabled_checks "," common_clang_tidy_disabled_checks)

    list(TRANSFORM cxx_clang_tidy_disabled_checks PREPEND "-")
    list(JOIN cxx_clang_tidy_disabled_checks "," cxx_clang_tidy_disabled_checks)

    list(TRANSFORM c_clang_tidy_disabled_checks PREPEND "-")
    list(JOIN c_clang_tidy_disabled_checks "," c_clang_tidy_disabled_checks)

    list(JOIN common_clang_tidy ";" clang_tidy)
    set(
      DO_CLANG_TIDY_CXX
      ${clang_tidy} -header-filter=.hpp -checks=*,${common_clang_tidy_disabled_checks},${cxx_clang_tidy_disabled_checks}
    )
    set(
      DO_CLANG_TIDY_C
      ${clang_tidy} -header-filter=.h -checks=*,${common_clang_tidy_disabled_checks},${c_clang_tidy_disabled_checks}
    )
  endif()
endif()

function(target_add_tidy_flags target scope)
  if(USE_TIDY)
    set_target_properties(${target} PROPERTIES CXX_CLANG_TIDY "${DO_CLANG_TIDY_CXX}")
    set_target_properties(${target} PROPERTIES C_CLANG_TIDY "${DO_CLANG_TIDY_C}")
  endif()
endfunction()
