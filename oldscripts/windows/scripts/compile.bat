IF not exist %1 (
	mkdir %1
)
cmake -S %2 -G "MinGW Makefiles" -D CMAKE_BUILD_TYPE=Release -D CMAKE_RUNTIME_OUTPUT_DIRECTORY=%1
mingw32-make
