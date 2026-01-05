include(cmake/libs/threads.cmake)

include(FetchContent)
set(gtest_force_shared_crt ON CACHE BOOL "Always use msvcrt.dll" FORCE)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz
  URL_HASH SHA256=65fab701d9829d38cb77c14acdc431d2108bfdbf8979e40eb8ae567edf10b27c
)
FetchContent_MakeAvailable(googletest)

set(SCIDUP_TESTS_LIBS_CPPSUPPORT_SOURCES
  "${CMAKE_SOURCE_DIR}/src/codec_scid4.cpp"
  "${CMAKE_SOURCE_DIR}/src/scidbase.cpp"
  "${CMAKE_SOURCE_DIR}/src/sortcache.cpp"
  "${CMAKE_SOURCE_DIR}/src/stored.cpp"
  "${CMAKE_SOURCE_DIR}/src/game.cpp"
  "${CMAKE_SOURCE_DIR}/src/position.cpp"
  "${CMAKE_SOURCE_DIR}/src/textbuf.cpp"
  "${CMAKE_SOURCE_DIR}/src/misc.cpp"
)
add_library(scidup_tests_libs_cppsupport ${SCIDUP_TESTS_LIBS_CPPSUPPORT_SOURCES})
target_include_directories(scidup_tests_libs_cppsupport PUBLIC "${CMAKE_SOURCE_DIR}/src")
add_library(ScidUp::Tests::Libs::CppBase ALIAS scidup_tests_libs_cppsupport)
target_link_libraries(scidup_tests_libs_cppsupport PUBLIC Threads::Threads)

file(GLOB SCIDUP_TESTS_BINS_CPPTEST_SOURCES "${CMAKE_SOURCE_DIR}/gtest/*.cpp")
add_executable(scidup_tests_bins_cpptest ${SCIDUP_TESTS_BINS_CPPTEST_SOURCES})
add_executable(ScidUp::Tests::Bins::CppTest ALIAS scidup_tests_bins_cpptest)
target_compile_definitions(scidup_tests_bins_cpptest PRIVATE SCIDUP_TEST_RESOURCES_DIR=\"${CMAKE_SOURCE_DIR}/gtest/\")
target_link_libraries(scidup_tests_bins_cpptest PRIVATE ScidUp::Tests::Libs::CppBase gtest_main)

add_test(
  NAME cpp_test
  COMMAND $<TARGET_FILE:ScidUp::Tests::Bins::CppTest>
)
set_tests_properties(
  cpp_test
  PROPERTIES
  LABELS "cpp"
)
