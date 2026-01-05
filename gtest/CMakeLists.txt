# Copyright (C) 2016-2017  Fulvio Benini
# This file is part of Scid (Shane's Chess Information Database).
#
# Scid is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.
#
# Scid is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Scid. If not, see <http://www.gnu.org/licenses/>.

set(CMAKE_CXX_STANDARD 20 CACHE STRING "")

# googletest
include(FetchContent)
set(gtest_force_shared_crt ON CACHE BOOL "Always use msvcrt.dll" FORCE)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz
  URL_HASH SHA256=65fab701d9829d38cb77c14acdc431d2108bfdbf8979e40eb8ae567edf10b27c
)
FetchContent_MakeAvailable(googletest)

# scidup_sources
set(SCIDUP_TESTS_LIBS_CPPSUPPORT_SOURCES
  ../src/codec_scid4.cpp
  ../src/scidbase.cpp
  ../src/sortcache.cpp
  ../src/stored.cpp
  ../src/game.cpp ../src/position.cpp ../src/textbuf.cpp ../src/misc.cpp
)
add_library(scidup_tests_libs_cppsupport ${SCIDUP_TESTS_LIBS_CPPSUPPORT_SOURCES})
target_include_directories(scidup_tests_libs_cppsupport PUBLIC ../src)
add_library(ScidUp::Tests::Libs::CppBase ALIAS scidup_tests_libs_cppsupport)
find_package(Threads REQUIRED)
target_link_libraries(scidup_tests_libs_cppsupport PUBLIC Threads::Threads)

# scidup_tests
file(GLOB SCIDUP_TESTS_BINS_CPPTEST_SOURCES *.cpp)
add_executable(scidup_tests_bins_cpptest ${SCIDUP_TESTS_BINS_CPPTEST_SOURCES})
add_executable(ScidUp::Tests::Bins::CppTest ALIAS scidup_tests_bins_cpptest)
target_compile_definitions(scidup_tests_bins_cpptest PRIVATE SCIDUP_TEST_RESOURCES_DIR=\"${CMAKE_CURRENT_LIST_DIR}/\")
target_link_libraries(scidup_tests_bins_cpptest PRIVATE ScidUp::Tests::Libs::CppBase gtest_main)
