cmake_minimum_required(VERSION 3.18.1)

project("privavoice_native")

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add subdirectories for whisper.cpp and llama.cpp
# In production, you would clone these repositories:
# - whisper.cpp: https://github.com/ggerganov/whisper.cpp
# - llama.cpp: https://github.com/ggerganov/llama.cpp

# ============================================================
# WHISPER.CPP - Speech Recognition
# ============================================================

# For now, we create a placeholder library
# In production, include actual whisper.cpp source:
# add_subdirectory(whisper.cpp whisper_build)

add_library(whisper SHARED
    whisper_bridge.cpp
)

target_include_directories(whisper PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(whisper
    log
)

# ============================================================
# LLAMA.CPP - LLM Inference  
# ============================================================

add_library(llama SHARED
    llama_bridge.cpp
)

target_include_directories(llama PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(llama
    log
)
