cmake_minimum_required(VERSION 4.3)

project(vk_gltf_renderer_rewrite LANGUAGES C CXX)

# ============================================================================
# Options
# ============================================================================
option(USE_DEFAULT_SCENE "Using a default scene at startup" ON)
option(USE_OPTIX_DENOISER "Use OptiX denoiser as alternative to DLSS" ON)
option(USE_DRACO "Use Draco for compression" ON)
option(USE_DLSS "Use DLSS-RR for denoising" ON)

# nvpro_core2 is opt-in for this renderer: enable only libraries used by the target.
set(NVPRO2_ENABLE_DEFAULT OFF CACHE BOOL "Disable nvpro_core2 default component set" FORCE)
set(NVPRO2_ENABLE_nvimageformats ON CACHE BOOL "Enable nvimageformats from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvutils ON CACHE BOOL "Enable nvutils from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvapp ON CACHE BOOL "Enable nvapp from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvgui ON CACHE BOOL "Enable nvgui from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvgpu_monitor ON CACHE BOOL "Enable nvgpu_monitor from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvvk ON CACHE BOOL "Enable nvvk from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvshaders_host ON CACHE BOOL "Enable nvshaders_host from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvaftermath ON CACHE BOOL "Enable nvaftermath from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvslang ON CACHE BOOL "Enable nvslang from nvpro_core2" FORCE)

set(NVPRO2_ENABLE_nvgl OFF CACHE BOOL "Disable unused nvgl from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvvkglsl OFF CACHE BOOL "Disable unused nvvkglsl from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvvkgltf OFF CACHE BOOL "Disable unused nvvkgltf from nvpro_core2" FORCE)
set(NVPRO2_ENABLE_nvnsight OFF CACHE BOOL "Disable unused nvnsight from nvpro_core2" FORCE)


# ============================================================================
# Dependencies
# ============================================================================
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Vulkan 1.4 REQUIRED)

find_path(
        NvproCore2_ROOT
        NAMES nvpro_core2/cmake/Setup.cmake
        PATHS
        ${CMAKE_BINARY_DIR}/_deps
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/..
        ${CMAKE_CURRENT_SOURCE_DIR}/../..
)

if (NOT NvproCore2_ROOT)
    message(FATAL_ERROR
            "nvpro_core2 was not found. Keep nvpro_core2 as a sibling checkout "
            "or pass -DNvproCore2_ROOT=<directory containing nvpro_core2>."
    )
endif ()

message(STATUS "Found nvpro_core2 at: ${NvproCore2_ROOT}")
set(NVPRO_CORE2_OUTPUT_DIR "${CMAKE_BINARY_DIR}")
set(NVPRO_CORE2_DOWNLOAD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/resources")
include(${NvproCore2_ROOT}/nvpro_core2/cmake/Setup.cmake)

# nvpro_core2's current nvvk/swapchain.cpp uses std::clamp without directly including <algorithm>.
# GCC 16 no longer sees that symbol through transitive includes; keep the workaround local to nvvk.
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "16" AND TARGET nvvk)
    target_compile_options(nvvk PRIVATE -include algorithm)
endif ()

find_package(WebP REQUIRED)
find_package(CUDAToolkit COMPONENTS CUDA::cudart)


# ============================================================================
# C++ Configuration
# ============================================================================
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)


# ============================================================================
# Target
# ============================================================================
add_executable(${PROJECT_NAME})

target_sources(
        ${PROJECT_NAME}
        PRIVATE
        src/gizmo_grid_vk.cpp
        src/gizmo_transform_vk.cpp
        src/gizmo_visuals_vk.cpp
        src/gltf_animation_pointer.cpp
        src/gltf_compact_model.cpp
        src/gltf_compact_scene.cpp
        src/gltf_create_tangent.cpp
        src/gltf_image_loader.cpp
        src/gltf_material_cache.cpp
        src/gltf_scene.cpp
        src/gltf_scene_animation.cpp
        src/gltf_scene_animation_vk.cpp
        src/gltf_scene_editor.cpp
        src/gltf_scene_gpu.cpp
        src/gltf_scene_merger.cpp
        src/gltf_scene_rtx.cpp
        src/gltf_scene_transform_vk.cpp
        src/gltf_scene_validator.cpp
        src/gltf_scene_vk.cpp
        src/gpu_memory_tracker.cpp
        src/main.cpp
        src/pipeline_cache_util.cpp
        src/renderer.cpp
        src/renderer_pathtracer.cpp
        src/renderer_rasterizer.cpp
        src/renderer_silhouette.cpp
        src/scene_descriptor.cpp
        src/scene_selection.cpp
        src/timeline_pipeline.cpp
        src/tiny_stb_implementation.cpp
        src/tinygltf_converter.cpp
        src/tinygltf_utils.cpp
        src/ui_animation.cpp
        src/ui_inspector.cpp
        src/ui_renderer.cpp
        src/ui_scene_browser.cpp
        src/ui_xmp.cpp
        src/undo_redo.cpp
        third_party/MikkTSpace/mikktspace.c
)

target_link_libraries(
        ${PROJECT_NAME}
        PRIVATE
        nvpro2::nvapp
        nvpro2::nvgui
        nvpro2::nvslang
        nvpro2::nvutils
        nvpro2::nvvk
        nvpro2::nvshaders_host
        nvpro2::nvaftermath
        nvpro2::nvgpu_monitor
        fmt
        glm
        nvimageformats
        stb
        tinygltf
        tinyobjloader
        meshoptimizer
        webp
)

target_include_directories(
        ${PROJECT_NAME}
        PRIVATE
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/third_party/MikkTSpace
)

add_project_definitions(${PROJECT_NAME})

if (USE_DEFAULT_SCENE)
    target_compile_definitions(${PROJECT_NAME} PRIVATE USE_DEFAULT_SCENE)
endif ()


# ============================================================================
# Shaders
# ============================================================================
set(VK_GLTF_SHADER_OUTPUT_DIR ${CMAKE_BINARY_DIR}/${PROJECT_NAME}/_autogen)
set(
        VK_GLTF_SHADER_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/gizmo_grid.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/gizmo_visuals.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/gltf_pathtrace.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/gltf_raster.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/morph.comp.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/optix_image_to_buffer.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/silhouette.comp.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/skinning.comp.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/update_render_instances.comp.slang
        ${CMAKE_CURRENT_SOURCE_DIR}/shaders/world_matrix_propagate.comp.slang
)
set(
        VK_GLTF_SHARED_SHADER_SOURCES
        ${NVSHADERS_DIR}/nvshaders/tonemapper.slang
        ${NVSHADERS_DIR}/nvshaders/sky_physical.slang
        ${NVSHADERS_DIR}/nvshaders/hdr_prefilter_diffuse.slang
        ${NVSHADERS_DIR}/nvshaders/hdr_prefilter_glossy.slang
        ${NVSHADERS_DIR}/nvshaders/hdr_dome.slang
        ${NVSHADERS_DIR}/nvshaders/hdr_integrate_brdf.slang
        ${NVSHADERS_DIR}/nvshaders/hdr_charlie_brdf_lut.slang
)
set(VK_GLTF_ALL_SHADER_SOURCES ${VK_GLTF_SHADER_SOURCES} ${VK_GLTF_SHARED_SHADER_SOURCES})

list(LENGTH VK_GLTF_ALL_SHADER_SOURCES VK_GLTF_SHADER_COUNT)
message(STATUS "Compiling ${VK_GLTF_SHADER_COUNT} Slang shader(s) to embedded SPIR-V headers")

compile_slang(
        "${VK_GLTF_ALL_SHADER_SOURCES}"
        "${VK_GLTF_SHADER_OUTPUT_DIR}"
        HEADERS_VAR VK_GLTF_GENERATED_SHADER_HEADERS
        EXTRA_FLAGS "-I${NVSHADERS_DIR}"
        DEBUG_LEVEL 2
        OPTIMIZATION_LEVEL 0
        CAPABILITIES
        spvGroupNonUniformArithmetic
        spvGroupNonUniform
)

target_sources(${PROJECT_NAME} PRIVATE ${VK_GLTF_GENERATED_SHADER_HEADERS})


# ============================================================================
# OptiX Denoiser
# ============================================================================
set(OptiX_VERSION 9.0.0)
download_package(
        NAME OptiX
        URLS https://github.com/NVIDIA/optix-dev/archive/refs/tags/v${OptiX_VERSION}.zip
        VERSION ${OptiX_VERSION}
        LOCATION OptiX_SOURCE_DIR
)
target_include_directories(${PROJECT_NAME} PRIVATE ${OptiX_SOURCE_DIR}/optix-dev-${OptiX_VERSION}/include)

if (USE_OPTIX_DENOISER)
    if (CUDAToolkit_FOUND)
        target_sources(
                ${PROJECT_NAME}
                PRIVATE
                src/optix_denoiser.cpp
                src/vk_cuda.cpp
        )
        target_include_directories(${PROJECT_NAME} PRIVATE ${CUDAToolkit_INCLUDE_DIRS})
        target_link_libraries(${PROJECT_NAME} PRIVATE CUDA::cudart CUDA::cuda_driver)
        target_compile_definitions(${PROJECT_NAME} PRIVATE USE_OPTIX_DENOISER CUDAToolkit_FOUND)

        if (WIN32)
            target_link_libraries(${PROJECT_NAME} PRIVATE delayimp.lib)
            target_link_options(${PROJECT_NAME} PRIVATE "/DELAYLOAD:cudart64_${CUDAToolkit_VERSION_MAJOR}.dll")
        endif ()
    else ()
        message(WARNING "CUDAToolkit not found - OptiX denoiser will not work properly")
    endif ()
endif ()


# ============================================================================
# Draco
# ============================================================================
if (USE_DRACO)
    download_package(
            NAME draco
            URLS https://github.com/google/draco/archive/refs/heads/main.zip
            VERSION main
            LOCATION draco_SOURCE_DIR
    )
    set(DRACO_SOURCE_DIR ${draco_SOURCE_DIR}/draco-main)
    set(DRACO_BINARY_DIR ${CMAKE_BINARY_DIR}/draco)

    set(DRACO_BUILD_EXECUTABLES OFF CACHE BOOL "Disable building draco command-line tools" FORCE)
    set(DRACO_TESTS OFF CACHE BOOL "Disable draco tests" FORCE)
    set(DRACO_UNITY_PLUGIN OFF CACHE BOOL "Disable Unity plugin" FORCE)
    set(DRACO_MAYA_PLUGIN OFF CACHE BOOL "Disable Maya plugin" FORCE)

    add_subdirectory(${DRACO_SOURCE_DIR} ${DRACO_BINARY_DIR} EXCLUDE_FROM_ALL)
    target_link_libraries(tinygltf INTERFACE draco::draco)
    target_include_directories(tinygltf INTERFACE ${DRACO_SOURCE_DIR}/src ${DRACO_BINARY_DIR}/..)
    target_compile_definitions(tinygltf INTERFACE TINYGLTF_ENABLE_DRACO)
    target_compile_definitions(${PROJECT_NAME} PRIVATE USE_DRACO)
endif ()


# ============================================================================
# RapidJSON
# ============================================================================
download_package(
        NAME RapidJSON
        URLS https://github.com/Tencent/rapidjson/archive/refs/heads/master.zip
        VERSION master
        LOCATION RapidJSON_SOURCE_DIR
)
target_include_directories(${PROJECT_NAME} PRIVATE ${RapidJSON_SOURCE_DIR}/rapidjson-master/include/rapidjson)


# ============================================================================
# DLSS
# ============================================================================
if (USE_DLSS)
    set(DLSS_VERSION "310.5.3")
    find_package(NGX REQUIRED)
    target_sources(
            ${PROJECT_NAME}
            PRIVATE
            src/dlss_wrapper.cpp
            src/dlss_denoiser.cpp
    )
    target_link_libraries(${PROJECT_NAME} PRIVATE ngx)
    target_compile_definitions(${PROJECT_NAME} PRIVATE USE_DLSS)
endif ()


function(copy_existing_runtime_files TARGET_NAME)
    foreach (RUNTIME_FILE IN LISTS ARGN)
        if (RUNTIME_FILE AND EXISTS "${RUNTIME_FILE}")
            add_custom_command(
                    TARGET ${TARGET_NAME} POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${RUNTIME_FILE}" "$<TARGET_FILE_DIR:${TARGET_NAME}>"
                    VERBATIM
            )
        endif ()
    endforeach ()
endfunction()

set(VK_GLTF_RUNTIME_FILES ${Slang_GLSLANG})
if (USE_DLSS)
    list(APPEND VK_GLTF_RUNTIME_FILES ${DLSS_DLLS})
endif ()
copy_existing_runtime_files(${PROJECT_NAME} ${VK_GLTF_RUNTIME_FILES})

if (WIN32)
    set(HAVE_RUNTIME_DLLS $<BOOL:$<TARGET_RUNTIME_DLLS:${PROJECT_NAME}>>)
    set(COPY_RUNTIME_DLLS ${CMAKE_COMMAND} -E copy_if_different "$<TARGET_RUNTIME_DLLS:${PROJECT_NAME}>" "$<TARGET_FILE_DIR:${PROJECT_NAME}>")
    add_custom_command(
            TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND "$<${HAVE_RUNTIME_DLLS}:${COPY_RUNTIME_DLLS}>"
            COMMAND_EXPAND_LISTS
    )

endif ()
