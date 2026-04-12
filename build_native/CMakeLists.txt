# PrivaVoice Native Build Configuration
# Builds whisper.cpp and llama.cpp as shared libraries for Android

cmake_minimum_required(VERSION 3.22.1)

project(privavoice_native)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Options
option(BUILD_WHISPER "Build Whisper" ON)
option(BUILD_LLAMA "Build Llama" ON)

# Find required libraries
find_library(log-lib log)
find_library(android-lib android)
find_library(OpenGL-lib GLESv2)

# ============================================================
# WHISPER.CPP
# ============================================================
if(BUILD_WHISPER)
    add_library(whisper SHARED
        whisper.cpp/whisper.cc
        whisper.cpp/ggml/ggml.c
        whisper.cpp/ggml/ggml-alloc.c
        whisper.cpp/ggml/ggml-quants.c
    )

    target_include_directories(whisper PUBLIC
        whisper.cpp
        whisper.cpp/ggml/include
        whisper.cpp/include
    )

    target_link_libraries(whisper
        ${log-lib}
        ${android-lib}
        -lm -ldl -latomic
    )

    target_compile_options(whisper PRIVATE
        -O3
        -ffast-math
        -fPIC
        -Wall
        -Wextra
        $<$<AND:$<PLATFORM_ID:Android>,$<CONFIG:Release>>:-Os>
    )

    # ARM specific optimizations
    if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
        target_compile_options(whisper PRIVATE
            -march=armv8.2a+dotprod
            -mtune=cortex-a55
        )
    elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
        target_compile_options(whisper PRIVATE
            -march=armv7a+neon-vfpv4
            -mfpu=neon-fp16
        )
    endif()

    # SIMD optimizations (disable for smaller build)
    # Uncomment for faster inference:
    # target_compile_definitions(whisper PRIVATE GGML_USE_LLAMAFILE)

    # Disable optimizations that increase binary size significantly
    target_compile_definitions(whisper PRIVATE
        GGML_USE_ACCURATE_LAYERNORM=0
        GGML_USE_ROCM=0
    )
endif()

# ============================================================
# LLAMA.CPP
# ============================================================
if(BUILD_LLAMA)
    add_library(llama SHARED
        llama.cpp/llama.cpp
        llama.cpp/ggml/ggml.c
        llama.cpp/ggml/ggml-alloc.c
        llama.cpp/ggml/ggml-quants.c
        llama.cpp/ggml/ggml-backend.c
    )

    target_include_directories(llama PUBLIC
        llama.cpp
        llama.cpp/ggml/include
    )

    target_link_libraries(llama
        ${log-lib}
        ${android-lib}
        -lm -ldl -latomic
    )

    target_compile_options(llama PRIVATE
        -O3
        -ffast-math
        -fPIC
        -Wall
        -Wextra
        $<$<AND:$<PLATFORM_ID:Android>,$<CONFIG:Release>>:-Os>
    )

    if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
        target_compile_options(llama PRIVATE
            -march=armv8.2a+dotprod
            -mtune=cortex-a55
        )
    elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
        target_compile_options(llama PRIVATE
            -march=armv7a+neon-vfpv4
        )
    endif()

    # Llama optimizations
    target_compile_definitions(llama PRIVATE
        GGML_USE_ACCURATE_LAYERNORM=0
        GGML_USE_ROCM=0
        GGML_USE_CUBLAS=0
    )

    # Build with -sanitize=address for debug only
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        target_compile_options(llama PRIVATE -fsanitize=address)
        target_link_options(llama PRIVATE -fsanitize=address)
    endif()
endif()

# ============================================================
# EXPORTED FUNCTIONS
# ============================================================

# whisper.cpp exports
if(BUILD_WHISPER)
    target_compile_definitions(whisper PRIVATE
        WHISPER_BUILDING_LIBRARY
    )

    # Standard function exports (not JNI)
    add_library(whisper_cpp INTERFACE)
    target_link_libraries(whisper_cpp INTERFACE whisper)

    # Functions that will be exported:
    # - whisper_init_from_file()
    # - whisper_free()
    # - whisper_full() 
    # - whisper_full_n_segments()
    # - whisper_full_get_segment_text()
    # - whisper_full_get_segment_timestamps()
endif()

# llama.cpp exports
if(BUILD_LLAMA)
    target_compile_definitions(llama PRIVATE
        LLAMA_BUILDING_LIBRARY
    )

    add_library(llama_cpp INTERFACE)
    target_link_libraries(llama_cpp INTERFACE llama)

    # Functions exported:
    # - llama_init_from_file()
    # - llama_free()
    # - llama_batch_add()
    # - llama_decode()
    # - llama_get_token_text()
    # - llama_generate()
endif()