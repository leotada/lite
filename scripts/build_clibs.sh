#!/bin/bash
set -e

# Create build directory
mkdir -p build/clibs

# Compile Lua 5.4
echo "Compiling Lua 5.4..."
gcc -O2 -c -std=gnu99 -DLUA_USE_POSIX -D_GNU_SOURCE -Isrc/lib/lua54 src/lib/lua54/*.c
# Remove standalone main objects if they were compiled (we used *.c so they are there)
rm -f lua.o luac.o
mv *.o build/clibs/

# Compile STB Truetype
echo "Compiling STB Truetype..."
gcc -O2 -c -std=gnu99 -Isrc/lib/stb src/lib/stb/stb_truetype.c -o build/clibs/stb_truetype.o

# Create static library
echo "Creating libclibs.a..."
ar rcs build/libclibs.a build/clibs/*.o

echo "Done."
