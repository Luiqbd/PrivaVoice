cmake_minimum_required(VERSION 3.18.1)

project("privavoice_native")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================
# WHISPER.CPP - Speech Recognition
# The actual libwhisper.so is loaded at runtime via FFI
# This bridge provides JNI interface
# ============================================================

add_library(whisper SHARED
    whisper_bridge.cpp
)

target_include_directories(whisper PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(whisper
    log
    android
)

# ============================================================
# LLAMA.CPP - LLM Inference
# The actual libllama.so is loaded at runtime via FFI
# This bridge provides JNI interface
# ============================================================

add_library(llama SHARED
    llama_bridge.cpp
)

target_include_directories(llama PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(llama
    log
    android
)
