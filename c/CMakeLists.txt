cmake_minimum_required(VERSION 3.14)
project(bench LANGUAGES C)

include(FetchContent)


find_package(tigerbeetle 0.3.0 QUIET)
if(NOT tigerbeetle_FOUND)
    FetchContent_Declare(tigerbeetle GIT_REPOSITORY https://github.com/kassane/tigerbeetle-cpp.git
        GIT_TAG main)
    FetchContent_GetProperties(tigerbeetle)
    set(APP_TARGETS ${PROJECT_NAME})
    FetchContent_MakeAvailable(tigerbeetle)
endif()
find_package(Threads REQUIRED)

add_executable(${PROJECT_NAME} bench.c)
# Link the executable target with the tigerbeetle client library and Threads library
target_link_libraries(${PROJECT_NAME}
    PRIVATE tb_client Threads::Threads
)
# Include the tigerbeetle headers
target_include_directories(${PROJECT_NAME} PUBLIC ${tigerbeetle_SOURCE_DIR}/include)
# Link against the tigerbeetle library directory
target_link_directories(${PROJECT_NAME} PUBLIC ${tigerbeetle_BINARY_DIR})
# Add a custom target to run the executable
add_custom_target(run
    COMMAND ${PROJECT_NAME}
    DEPENDS ${PROJECT_NAME}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)
# Set the "bench" target as the default target when building the project
set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT ${PROJECT_NAME})
