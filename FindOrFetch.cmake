function(find_or_fetch_package name version)

  cmake_parse_arguments(PARSE_ARGV 2 PARSED_ARGS "" "GIT_REPOSITORY;GIT_TAG" "")

  if(PARSED_ARGS_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "unknown argument ${PARSED_ARGS_UNPARSED_ARGUMENTS}")
  endif()

  if(NOT PARSED_ARGS_GIT_REPOSITORY)
    message(FATAL_ERROR "find_or_fetch_package needs GIT_REPOSITORY")
  endif()

  if(NOT PARSED_ARGS_GIT_TAG)
    message(FATAL_ERROR "find_or_fetch_package needs GIT_TAG")
  endif()

  find_package(${name} ${version} QUIET)
  if(NOT ${name}_FOUND)
    include(FetchContent)
    FetchContent_Declare(
      ${name}
      GIT_REPOSITORY ${PARSED_ARGS_GIT_REPOSITORY}
      GIT_TAG ${PARSED_ARGS_GIT_TAG}
    )
    FetchContent_MakeAvailable(${name})
  endif()

endfunction()
