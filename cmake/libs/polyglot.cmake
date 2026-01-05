# Polyglot library (engine adapter / protocol glue).

file(GLOB SCIDUP_LIBS_POLYGLOT_SOURCES "${CMAKE_SOURCE_DIR}/src/polyglot/*.cpp")
add_library(scidup_libs_polyglot ${SCIDUP_LIBS_POLYGLOT_SOURCES})
add_library(ScidUp::Libs::Polyglot ALIAS scidup_libs_polyglot)

