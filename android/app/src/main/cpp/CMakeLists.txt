cmake_minimum_required(VERSION 3.18.1)

project("privavoice_native")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================
# GGML - Base library for GGUF models
# ============================================================
add_subdirectory(ggml ggml_build)

# ============================================================
# WHISPER.CPP - Speech Recognition
# ============================================================
# Add whisper.cpp as subdirectory
# (You need to copy whisper.cpp source to cpp/whisper.cpp)
# 
# In production, clone whisper.cpp and add:
# add_subdirectory(whisper.cpp whisper_build)

# For now, create a stub library that will be replaced
add_library(whisper SHARED
    whisper_bridge.cpp
)

target_include_directories(whisper PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/ggml/include
)

target_link_libraries(whisper
    ggml
    log
    android
)

# ============================================================
# LLAMA.CPP - LLM Inference
# ============================================================
# In production, clone llama.cpp and add:
# add_subdirectory(llama.cpp llama_build)

add_library(llama SHARED
    llama_bridge.cpp
)

target_include_directories(llama PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/ggml/include
)

target_link_libraries(llama
    ggml
    log
    android
)
