file(GLOB SCIDUP_MAIN_SOURCES
  "${CMAKE_SOURCE_DIR}/src/*.h"
  "${CMAKE_SOURCE_DIR}/src/*.cpp"
)

if(MSVC)
  add_executable(
    scidup_main
    WIN32
    ${SCIDUP_MAIN_SOURCES}
    "${CMAKE_SOURCE_DIR}/resources/win/scid.rc"
    "${CMAKE_SOURCE_DIR}/resources/win/scid.manifest"
  )
  target_link_options(scidup_main PRIVATE /ENTRY:mainCRTStartup)
  target_compile_definitions(scidup_main PRIVATE _CRT_SECURE_NO_WARNINGS _SCL_SECURE_NO_WARNINGS)
  # To run/debug using Visual Studio set "scidup_main" as startup project and add:
  # Command Arguments: ../tcl/start.tcl
  # Environment:       PATH=C:\tcl\bin
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

install(TARGETS scidup_main RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")

file(GLOB ECO_FILES "${CMAKE_SOURCE_DIR}/*.eco")
set(SCIDUP_DATA_INSTALL_DIR "${CMAKE_INSTALL_DATADIR}/scid-up")
install(FILES ${ECO_FILES} DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
install(DIRECTORY "${CMAKE_SOURCE_DIR}/bitmaps" DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
install(DIRECTORY "${CMAKE_SOURCE_DIR}/bitmaps2" DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
install(DIRECTORY "${CMAKE_SOURCE_DIR}/books" DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
install(DIRECTORY "${CMAKE_SOURCE_DIR}/html" DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
install(DIRECTORY "${CMAKE_SOURCE_DIR}/img" DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
install(DIRECTORY "${CMAKE_SOURCE_DIR}/scripts" DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
install(DIRECTORY "${CMAKE_SOURCE_DIR}/sounds" DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
install(DIRECTORY "${CMAKE_SOURCE_DIR}/tcl" DESTINATION "${SCIDUP_DATA_INSTALL_DIR}")
