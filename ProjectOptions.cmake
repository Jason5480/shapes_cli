include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(shapes_cli_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(shapes_cli_setup_options)
  option(shapes_cli_ENABLE_HARDENING "Enable hardening" ON)
  option(shapes_cli_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    shapes_cli_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    shapes_cli_ENABLE_HARDENING
    OFF)

  shapes_cli_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR shapes_cli_PACKAGING_MAINTAINER_MODE)
    option(shapes_cli_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(shapes_cli_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(shapes_cli_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(shapes_cli_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(shapes_cli_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(shapes_cli_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(shapes_cli_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(shapes_cli_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(shapes_cli_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(shapes_cli_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(shapes_cli_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(shapes_cli_ENABLE_PCH "Enable precompiled headers" OFF)
    option(shapes_cli_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(shapes_cli_ENABLE_IPO "Enable IPO/LTO" ON)
    option(shapes_cli_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(shapes_cli_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(shapes_cli_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(shapes_cli_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(shapes_cli_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(shapes_cli_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(shapes_cli_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(shapes_cli_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(shapes_cli_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(shapes_cli_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(shapes_cli_ENABLE_PCH "Enable precompiled headers" OFF)
    option(shapes_cli_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      shapes_cli_ENABLE_IPO
      shapes_cli_WARNINGS_AS_ERRORS
      shapes_cli_ENABLE_USER_LINKER
      shapes_cli_ENABLE_SANITIZER_ADDRESS
      shapes_cli_ENABLE_SANITIZER_LEAK
      shapes_cli_ENABLE_SANITIZER_UNDEFINED
      shapes_cli_ENABLE_SANITIZER_THREAD
      shapes_cli_ENABLE_SANITIZER_MEMORY
      shapes_cli_ENABLE_UNITY_BUILD
      shapes_cli_ENABLE_CLANG_TIDY
      shapes_cli_ENABLE_CPPCHECK
      shapes_cli_ENABLE_COVERAGE
      shapes_cli_ENABLE_PCH
      shapes_cli_ENABLE_CACHE)
  endif()

  shapes_cli_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (shapes_cli_ENABLE_SANITIZER_ADDRESS OR shapes_cli_ENABLE_SANITIZER_THREAD OR shapes_cli_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(shapes_cli_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(shapes_cli_global_options)
  if(shapes_cli_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    shapes_cli_enable_ipo()
  endif()

  shapes_cli_supports_sanitizers()

  if(shapes_cli_ENABLE_HARDENING AND shapes_cli_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR shapes_cli_ENABLE_SANITIZER_UNDEFINED
       OR shapes_cli_ENABLE_SANITIZER_ADDRESS
       OR shapes_cli_ENABLE_SANITIZER_THREAD
       OR shapes_cli_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${shapes_cli_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${shapes_cli_ENABLE_SANITIZER_UNDEFINED}")
    shapes_cli_enable_hardening(shapes_cli_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(shapes_cli_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(shapes_cli_warnings INTERFACE)
  add_library(shapes_cli_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  shapes_cli_set_project_warnings(
    shapes_cli_warnings
    ${shapes_cli_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(shapes_cli_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(shapes_cli_options)
  endif()

  include(cmake/Sanitizers.cmake)
  shapes_cli_enable_sanitizers(
    shapes_cli_options
    ${shapes_cli_ENABLE_SANITIZER_ADDRESS}
    ${shapes_cli_ENABLE_SANITIZER_LEAK}
    ${shapes_cli_ENABLE_SANITIZER_UNDEFINED}
    ${shapes_cli_ENABLE_SANITIZER_THREAD}
    ${shapes_cli_ENABLE_SANITIZER_MEMORY})

  set_target_properties(shapes_cli_options PROPERTIES UNITY_BUILD ${shapes_cli_ENABLE_UNITY_BUILD})

  if(shapes_cli_ENABLE_PCH)
    target_precompile_headers(
      shapes_cli_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(shapes_cli_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    shapes_cli_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(shapes_cli_ENABLE_CLANG_TIDY)
    shapes_cli_enable_clang_tidy(shapes_cli_options ${shapes_cli_WARNINGS_AS_ERRORS})
  endif()

  if(shapes_cli_ENABLE_CPPCHECK)
    shapes_cli_enable_cppcheck(${shapes_cli_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(shapes_cli_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    shapes_cli_enable_coverage(shapes_cli_options)
  endif()

  if(shapes_cli_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(shapes_cli_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(shapes_cli_ENABLE_HARDENING AND NOT shapes_cli_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR shapes_cli_ENABLE_SANITIZER_UNDEFINED
       OR shapes_cli_ENABLE_SANITIZER_ADDRESS
       OR shapes_cli_ENABLE_SANITIZER_THREAD
       OR shapes_cli_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    shapes_cli_enable_hardening(shapes_cli_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
