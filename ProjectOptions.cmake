include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(vulkan_journey_supports_sanitizers)
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

macro(vulkan_journey_setup_options)
  option(vulkan_journey_ENABLE_HARDENING "Enable hardening" ON)
  option(vulkan_journey_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    vulkan_journey_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    vulkan_journey_ENABLE_HARDENING
    OFF)

  vulkan_journey_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR vulkan_journey_PACKAGING_MAINTAINER_MODE)
    option(vulkan_journey_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(vulkan_journey_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(vulkan_journey_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(vulkan_journey_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(vulkan_journey_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(vulkan_journey_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(vulkan_journey_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(vulkan_journey_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(vulkan_journey_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(vulkan_journey_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(vulkan_journey_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(vulkan_journey_ENABLE_PCH "Enable precompiled headers" OFF)
    option(vulkan_journey_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(vulkan_journey_ENABLE_IPO "Enable IPO/LTO" ON)
    option(vulkan_journey_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(vulkan_journey_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(vulkan_journey_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(vulkan_journey_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(vulkan_journey_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(vulkan_journey_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(vulkan_journey_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(vulkan_journey_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(vulkan_journey_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(vulkan_journey_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(vulkan_journey_ENABLE_PCH "Enable precompiled headers" OFF)
    option(vulkan_journey_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      vulkan_journey_ENABLE_IPO
      vulkan_journey_WARNINGS_AS_ERRORS
      vulkan_journey_ENABLE_USER_LINKER
      vulkan_journey_ENABLE_SANITIZER_ADDRESS
      vulkan_journey_ENABLE_SANITIZER_LEAK
      vulkan_journey_ENABLE_SANITIZER_UNDEFINED
      vulkan_journey_ENABLE_SANITIZER_THREAD
      vulkan_journey_ENABLE_SANITIZER_MEMORY
      vulkan_journey_ENABLE_UNITY_BUILD
      vulkan_journey_ENABLE_CLANG_TIDY
      vulkan_journey_ENABLE_CPPCHECK
      vulkan_journey_ENABLE_COVERAGE
      vulkan_journey_ENABLE_PCH
      vulkan_journey_ENABLE_CACHE)
  endif()

  vulkan_journey_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (vulkan_journey_ENABLE_SANITIZER_ADDRESS OR vulkan_journey_ENABLE_SANITIZER_THREAD OR vulkan_journey_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(vulkan_journey_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(vulkan_journey_global_options)
  if(vulkan_journey_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    vulkan_journey_enable_ipo()
  endif()

  vulkan_journey_supports_sanitizers()

  if(vulkan_journey_ENABLE_HARDENING AND vulkan_journey_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR vulkan_journey_ENABLE_SANITIZER_UNDEFINED
       OR vulkan_journey_ENABLE_SANITIZER_ADDRESS
       OR vulkan_journey_ENABLE_SANITIZER_THREAD
       OR vulkan_journey_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${vulkan_journey_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${vulkan_journey_ENABLE_SANITIZER_UNDEFINED}")
    vulkan_journey_enable_hardening(vulkan_journey_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(vulkan_journey_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(vulkan_journey_warnings INTERFACE)
  add_library(vulkan_journey_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  vulkan_journey_set_project_warnings(
    vulkan_journey_warnings
    ${vulkan_journey_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(vulkan_journey_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    vulkan_journey_configure_linker(vulkan_journey_options)
  endif()

  include(cmake/Sanitizers.cmake)
  vulkan_journey_enable_sanitizers(
    vulkan_journey_options
    ${vulkan_journey_ENABLE_SANITIZER_ADDRESS}
    ${vulkan_journey_ENABLE_SANITIZER_LEAK}
    ${vulkan_journey_ENABLE_SANITIZER_UNDEFINED}
    ${vulkan_journey_ENABLE_SANITIZER_THREAD}
    ${vulkan_journey_ENABLE_SANITIZER_MEMORY})

  set_target_properties(vulkan_journey_options PROPERTIES UNITY_BUILD ${vulkan_journey_ENABLE_UNITY_BUILD})

  if(vulkan_journey_ENABLE_PCH)
    target_precompile_headers(
      vulkan_journey_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(vulkan_journey_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    vulkan_journey_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(vulkan_journey_ENABLE_CLANG_TIDY)
    vulkan_journey_enable_clang_tidy(vulkan_journey_options ${vulkan_journey_WARNINGS_AS_ERRORS})
  endif()

  if(vulkan_journey_ENABLE_CPPCHECK)
    vulkan_journey_enable_cppcheck(${vulkan_journey_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(vulkan_journey_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    vulkan_journey_enable_coverage(vulkan_journey_options)
  endif()

  if(vulkan_journey_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(vulkan_journey_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(vulkan_journey_ENABLE_HARDENING AND NOT vulkan_journey_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR vulkan_journey_ENABLE_SANITIZER_UNDEFINED
       OR vulkan_journey_ENABLE_SANITIZER_ADDRESS
       OR vulkan_journey_ENABLE_SANITIZER_THREAD
       OR vulkan_journey_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    vulkan_journey_enable_hardening(vulkan_journey_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
