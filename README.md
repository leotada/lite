# Lite Editor (D Port)

A port of the [lite](https://github.com/rxi/lite) text editor to the D programming language. This project aims to replicate the core functionality of `lite` while leveraging D's safety and expressiveness, interfacing with the original Lua-based logic.

## Prerequisites

To build and run this project, you need the following tools and libraries installed on your system:

*   **D Compiler**: [LDC](https://github.com/ldc-developers/ldc) (LLVM-based D Compiler) or [DMD](https://dlang.org/download.html).
*   **DUB**: The D package manager (usually included with the compiler).
*   **GCC** or **Clang**: Required for compiling the embedded C dependencies (Lua 5.4 and stb_truetype).
*   **SDL3**: The `lite` editor relies on SDL3 for windowing and input.

### Installing Dependencies

**Ubuntu/Debian:**

```bash
sudo apt update
sudo apt install ldc dub build-essential
# Install SDL3 (If available in repo, otherwise build from source)
# sudo apt install libsdl3-dev 
```

**Fedora:**

```bash
sudo dnf install ldc dub gcc 
# sudo dnf install SDL3-devel
```

*(Note: Since SDL3 is relatively new, you may need to [build and install it from source](https://github.com/libsdl-org/SDL) if your distribution's repositories do not have it yet.)*

## Building

The project handles the mixed C/D compilation via `dub` and a helper script.

1.  Clone the repository:
    ```bash
    git clone https://github.com/yourusername/lite-d.git
    cd lite-d
    ```

2.  Build the project:
    ```bash
    dub build
    ```

    The build process will:
    *   Run `scripts/build_clibs.sh` to compile Lua 5.4 and `stb_truetype` into a static library (`libclibs.a`) in the `build/` directory.
    *   Compile the D source files.
    *   Link everything together into the `lite-d` executable.

## Running

Run the editor directly from the project root:

```bash
./lite-d
```

**Important**: The application requires the `data` directory (containing `core`, `plugins`, and `fonts`) to be present in the working directory or executable directory.

## Project Structure

*   `source/`: D source code (App, Renderer, API bindings).
*   `src/`: Original C source code used for reference and dependencies (Lua, STB).
*   `data/`: Core Lua scripts and assets (Fonts, Plugins).
*   `scripts/`: Helper scripts for the build process.

## License

MIT
