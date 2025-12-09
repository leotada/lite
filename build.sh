#!/bin/bash

cflags="-Wall -O3 -g -std=gnu11 -fno-strict-aliasing -Isrc"

if [[ $* == *windows* ]]; then
  platform="windows"
  outfile="lite.exe"
  compiler="x86_64-w64-mingw32-gcc"
  cflags="$cflags -DLUA_USE_POPEN -Iwinlib/SDL3/include"
  # Assuming user will provide SDL3 in winlib/SDL3
  lflags="-lmingw32 -lSDL3 -lm -Lwinlib/SDL3/lib -mwindows -o $outfile res.res"
  x86_64-w64-mingw32-windres res.rc -O coff -o res.res
else
  platform="unix"
  outfile="lite"
  compiler="gcc"
  cflags="$cflags -DLUA_USE_POSIX"
  if pkg-config --exists sdl3; then
    cflags="$cflags $(pkg-config --cflags sdl3)"
    lflags="$(pkg-config --libs sdl3) -lm -o $outfile"
  else
    # Fallback to SDL2 if SDL3 is not found (or raise error if strictly required, but for now fallback logic is tricky if code is updated)
    # The code will be updated to SDL3, so this fallback might fail at compile time if SDL3 is missing.
    # We'll just assume SDL3 is desired.
    cflags="$cflags $(pkg-config --cflags sdl3)"
    lflags="$(pkg-config --libs sdl3) -lm -o $outfile"
  fi
fi

if command -v ccache >/dev/null; then
  compiler="ccache $compiler"
fi


echo "compiling ($platform)..."
for f in `find src -name "*.c"`; do
  $compiler -c $cflags $f -o "${f//\//_}.o"
  if [[ $? -ne 0 ]]; then
    got_error=true
  fi
done

if [[ ! $got_error ]]; then
  echo "linking..."
  $compiler *.o $lflags
fi

echo "cleaning up..."
rm *.o
rm res.res 2>/dev/null
echo "done"
