cmake_minimum_required(VERSION 3.10.2)

# Name of the library
add_library( native-lib SHARED video_processing.cpp )

# Find the log library (optional, but good practice if we want to log from C++)
find_library( log-lib log )

# Link libraries
target_link_libraries( native-lib ${log-lib} )
