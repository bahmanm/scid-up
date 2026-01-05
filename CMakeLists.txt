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

cmake_minimum_required(VERSION 3.30)
project(scidup)
set(CPACK_PACKAGE_VERSION 5.1.0)
set(
  CPACK_PACKAGE_DESCRIPTION_SUMMARY
  "chess database application with play and training functionality"
)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "tk9 (>= 9)")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
include(CPack)

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD 20 CACHE STRING "")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(MSVC)
  add_definitions(/D_CRT_SECURE_NO_WARNINGS /D_SCL_SECURE_NO_WARNINGS)
  # To run/debug using Visual Studio set "scidup_main" as startup project and add:
  # Command Arguments: ../tcl/start.tcl
  # Environment:       PATH=C:\tcl\bin
endif()

find_package(Threads REQUIRED)
find_package(TCL REQUIRED)

add_library(scidup_libs_tcl INTERFACE)
add_library(ScidUp::Libs::Tcl ALIAS scidup_libs_tcl)
if(TARGET TCL::TCL)
  target_link_libraries(scidup_libs_tcl INTERFACE TCL::TCL)
else()
  target_include_directories(scidup_libs_tcl INTERFACE ${TCL_INCLUDE_PATH})
  target_link_libraries(scidup_libs_tcl INTERFACE ${TCL_LIBRARY})
endif()

include(cmake/libs/polyglot.cmake)

# scidup
file(GLOB SCIDUP_MAIN_SOURCES src/*.h src/*.cpp)
if(MSVC)
  add_executable(scidup_main WIN32 ${SCIDUP_MAIN_SOURCES} resources/win/scid.rc resources/win/scid.manifest)
  target_link_options(scidup_main PRIVATE /ENTRY:mainCRTStartup)
else()
  add_executable(scidup_main ${SCIDUP_MAIN_SOURCES})
endif()
add_executable(ScidUp::Bins::Main ALIAS scidup_main)
set_target_properties(scidup_main PROPERTIES OUTPUT_NAME "scid-up")
set_property(TARGET scidup_main PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE True)
target_link_libraries(scidup_main PRIVATE ScidUp::Libs::Polyglot Threads::Threads ScidUp::Libs::Tcl)

option(SPELLCHKVALIDATE "Verify the integrity of spelling files" OFF)
if(SPELLCHKVALIDATE)
  target_compile_definitions(scidup_main PRIVATE SPELLCHKVALIDATE)
endif()

install(TARGETS scidup_main DESTINATION scid-up)
file(GLOB ECO_FILES *.eco)
install(FILES ${ECO_FILES} DESTINATION scid-up)
install(DIRECTORY bitmaps DESTINATION scid-up)
install(DIRECTORY bitmaps2 DESTINATION scid-up)
install(DIRECTORY books DESTINATION scid-up)
install(DIRECTORY html DESTINATION scid-up)
install(DIRECTORY img DESTINATION scid-up)
install(DIRECTORY scripts DESTINATION scid-up)
install(DIRECTORY sounds DESTINATION scid-up)
install(DIRECTORY tcl DESTINATION scid-up)

include(cmake/tests.cmake)
include(cmake/lint.cmake)
