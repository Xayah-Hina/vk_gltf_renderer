# FindNvproCore2.cmake

find_path(NvproCore2_ROOT
    NAMES nvpro_core2/cmake/Setup.cmake
    PATHS
    ${CMAKE_BINARY_DIR}/_deps
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/..
    ${CMAKE_SOURCE_DIR}/../..
)

if(NOT NvproCore2_ROOT)
    message(FATAL_ERROR
        "nvpro_core2 was not found. Keep nvpro_core2 as a sibling checkout "
        "or pass -DNvproCore2_ROOT=<directory containing nvpro_core2>."
    )
endif()

set(NvproCore2_FOUND TRUE)
message(STATUS "Found nvpro_core2 at: ${NvproCore2_ROOT}")

# Include the setup file which will add the nvpro2::* targets.
include(${NvproCore2_ROOT}/nvpro_core2/cmake/Setup.cmake)
