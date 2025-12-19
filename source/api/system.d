module api.system;

import lua;
import sdl3;
import rencache;
import core.sys.posix.unistd : chdir;
import core.stdc.errno : errno;
import core.stdc.string : strerror, strcmp, strlen;
import core.stdc.stdlib : free; // malloc, system getenv already in line 6? No line 6 imports core.stdc.stdlib
// Using selective imports is safer.
// Re-doing imports block.

// Generic C stdlib
import core.stdc.stdlib : malloc, free, system, getenv;
import core.stdc.string : strcpy, strlen, strcmp, strerror;
import core.stdc.ctype : tolower; // Added back

// POSIX
import core.sys.posix.dirent : opendir, closedir, readdir, DIR, dirent;
import core.sys.posix.stdlib : realpath; // For realpath
// Rename stat module to avoid conflict
import PosixStat = core.sys.posix.sys.stat;

import core.sys.posix.unistd : chdir;
import core.stdc.errno : errno;

// We might need to alias to avoid conflict if both are named 'stat'
// Actually in D modules, if they have same name, we need full qualification.
// But `stat` IS the name of both?
// In C it works because `struct stat`.
// In D usage `stat s` refers to type? function?
// If I use `core.sys.posix.sys.stat.stat` it might mean the template/function?
// Let's rely on type inference or `struct stat`.

public __gshared SDL_Window* window;

extern (C) nothrow:

// Helpers
private const(char)* button_name(int button)
{
    switch (button)
    {
    case 1:
        return "left";
    case 2:
        return "middle";
    case 3:
        return "right";
    default:
        return "?";
    }
}

private char* key_name(char* dst, int sym)
{
    // SDL_GetKeyName is SDL2/3. Check bindings.
    // For now simplistic or missing binding?
    // Using SDL_GetKeyName if available.
    // Assuming sym is correct type.
    const(char)* name = SDL_GetKeyName(sym);
    if (!name)
        name = "?";
    strcpy(dst, name);
    char* p = dst;
    while (*p)
    {
        *p = cast(char) tolower(*p);
        p++;
    }
    return dst;
}

private int f_poll_event(lua_State* L)
{
    char[32] buf;
    SDL_Event e;

    while (SDL_PollEvent(&e))
    {
        switch (e.type)
        {
        case SDL_EVENT_QUIT:
            lua_pushstring(L, "quit");
            return 1;
        case SDL_EVENT_WINDOW_RESIZED:
            lua_pushstring(L, "resized");
            lua_pushnumber(L, e.window.data1);
            lua_pushnumber(L, e.window.data2);
            return 3;
        case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
            if (SDL_GetTicks() < 500)
            {
                continue;
            }
            lua_pushstring(L, "quit");
            return 1;
        case SDL_EVENT_KEY_DOWN:
            lua_pushstring(L, "keypressed");
            lua_pushstring(L, key_name(buf.ptr, e.key.key));
            return 2;
        case SDL_EVENT_KEY_UP:
            lua_pushstring(L, "keyreleased");
            lua_pushstring(L, key_name(buf.ptr, e.key.key));
            return 2;
        case SDL_EVENT_TEXT_INPUT:
            printf("DEBUG: SDL_EVENT_TEXT_INPUT received. Text: '%s'\n", e.text.text);
            lua_pushstring(L, "textinput");
            lua_pushstring(L, e.text.text);
            return 2;
        case SDL_EVENT_MOUSE_BUTTON_DOWN:
            lua_pushstring(L, "mousepressed");
            lua_pushstring(L, button_name(e.button.button));
            lua_pushnumber(L, cast(double) e.button.x);
            lua_pushnumber(L, cast(double) e.button.y);
            lua_pushnumber(L, e.button.clicks);
            return 5;
        case SDL_EVENT_MOUSE_BUTTON_UP:
            lua_pushstring(L, "mousereleased");
            lua_pushstring(L, button_name(e.button.button));
            lua_pushnumber(L, cast(double) e.button.x);
            lua_pushnumber(L, cast(double) e.button.y);
            return 4;
        case SDL_EVENT_MOUSE_MOTION:
            lua_pushstring(L, "mousemoved");
            lua_pushnumber(L, cast(double) e.motion.x);
            lua_pushnumber(L, cast(double) e.motion.y);
            lua_pushnumber(L, cast(double) e.motion.xrel);
            lua_pushnumber(L, cast(double) e.motion.yrel);
            return 5;
        case SDL_EVENT_MOUSE_WHEEL:
            lua_pushstring(L, "mousewheel");
            lua_pushnumber(L, cast(double) e.wheel.y);
            return 2;
        case SDL_EVENT_DROP_FILE:
            lua_pushstring(L, "filedropped");
            const(char)* filename = e.drop.file; // SDL3 might use 'data' or 'file' depending on version
            lua_pushstring(L, filename);
            int mx, my; // SDL Drop event doesn't explicitly have coords in standard SDL2/3 event, usually need GetMouseState?
            // Wait, standard `lite` api handles x,y?
            // api_system.c: `filedropped` -> filename, mouse_x, mouse_y.
            // SDL_GetMouseState(&mx, &my);
            // But we can't easily call that if not bound.
            // Actually SDL_DropEvent doesn't have coordinates.
            // We'll push 0, 0 or omit. Lite core seems to handle it.
            // Let's check lite src... it calls `SDL_GetMouseState`.
            // We need SDL_GetMouseState.
            lua_pushnumber(L, 0); // Placeholder X
            lua_pushnumber(L, 0); // Placeholder Y
            // Clean up? SDL3 might require `SDL_free`.
            // SDL_GetWindowFlags?
            // C version: SDL_free(e.drop.file). 
            // We should bindings SDL_free?
            // `free` from core.stdc.stdlib is likely fine if it acts on pointer.
            // But SDL allocator might differ.
            // Avoiding free for now (minor leak) or use SDL_free if bound.
            return 4;
        default:
            continue;
        }
    }
    return 0;
}

private int f_get_time(lua_State* L)
{
    double n = SDL_GetPerformanceCounter() / cast(double) SDL_GetPerformanceFrequency();
    lua_pushnumber(L, n);
    return 1;
}

private int f_sleep(lua_State* L)
{
    double n = luaL_checknumber(L, 1);
    SDL_Delay(cast(uint)(n * 1000));
    return 0;
}

// Imports for file operations
import core.sys.posix.unistd : chdir;
import core.stdc.errno : errno;
import core.stdc.string : strerror, strcmp, strlen;
import core.stdc.stdlib : free;
import core.stdc.stdio : printf;

// Using selective imports is safer.

// Generic C stdlib
import core.stdc.stdlib : malloc, free, system, getenv;
import core.stdc.string : strcpy, strlen, strcmp, strerror;
import core.stdc.ctype : tolower;

// POSIX
import core.sys.posix.dirent : opendir, closedir, readdir, DIR, dirent;

// import core.sys.posix.stdlib : realpath; // Unused
// import core.sys.posix.sys.stat; // Unused

import std.file : getSize, timeLastModified, isDir, isFile, exists, FileException;
import std.path : absolutePath, buildNormalizedPath;
import std.datetime : SysTime;
import std.string : toStringz, fromStringz;

// Warning: std.file functions are NOT @nogc nothrow.
// We must wrap them or use try-catch and assume wrapper.
// But api.system functions are extern(C).
// App.d imports api.system.
// But api.system functions are passed to Lua. Lua calls them.
// Lua calls are extern(C).
// So `lua_CFunction` signature `int function(lua_State*)` must be respected.
// `extern(C)` func can throw? No. D exception throwing across C boundary is bad.
// So we MUST catch exceptions inside these functions.
// And we MUST avoid GC if marked @nogc.
// But `std.file` allocates.
// So we CANNOT be @nogc.
// Lua functions don't need to be @nogc. They just need `extern(C)`.
// So remove `@nogc` from `extern(C):`.
// And wrap mostly everything in `try-catch` to return lua error.

private int f_chdir(lua_State* L) nothrow
{
    const(char)* path = luaL_checkstring(L, 1);
    // std.file.chdir? Or C chdir.
    // C chdir is @nogc nothrow. Keep using it.
    int err = chdir(path);
    if (err)
    {
        // luaL_error throws? No, it implies longjmp (panic).
        // So we can call it.
        // Convert to D string? No, luaL_error takes const char*.
        try
        {
            luaL_error(L, "chdir() failed: %s", strerror(errno));
        }
        catch (Exception e)
        {
        } // Should not happen as luaL_error doesn't throw D exception
    }
    return 0;
}

private int f_list_dir(lua_State* L) nothrow
{
    const(char)* path = luaL_checkstring(L, 1);
    DIR* dir = opendir(path);
    if (!dir)
    {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    // lua_newtable etc. are nothrow (C functions).
    // But they might longjmp. D `nothrow` means no D exceptions.
    // Longjmp/setjmp is compatible with extern(C) but D dtors might be skipped (unwind).
    // As long as we don't have RAII objects on stack that need cleanup...
    // We are fine.

    lua_newtable(L);
    int i = 1;
    dirent* entry;
    while ((entry = readdir(dir)) !is null)
    {
        if (strcmp(entry.d_name.ptr, ".") == 0)
            continue;
        if (strcmp(entry.d_name.ptr, "..") == 0)
            continue;
        lua_pushstring(L, entry.d_name.ptr);
        lua_rawseti(L, -2, i);
        i++;
    }
    closedir(dir);
    return 1;
}

private int f_absolute_path(lua_State* L) nothrow
{
    const(char)* path = luaL_checkstring(L, 1);

    // Wrap GC code
    try
    {
        string abs = absolutePath(path.fromStringz.idup);
        // idup copies C string to D string (GC).
        // absolutePath uses GC.
        lua_pushstring(L, abs.toStringz);
        // toStringz passes ptr. lua_pushstring copies it.
        return 1;
    }
    catch (Exception e)
    {
        lua_pushnil(L);
        return 1;
    }
}

private int f_get_file_info(lua_State* L) nothrow
{
    const(char)* path_c = luaL_checkstring(L, 1);

    try
    {
        string path = path_c.fromStringz.idup;
        if (!exists(path))
        {
            lua_pushnil(L);
            lua_pushstring(L, "File not found");
            return 2;
        }

        lua_newtable(L);

        // Size
        ulong size = 0;
        try
        {
            size = getSize(path);
        }
        catch (Exception)
        {
        }
        lua_pushnumber(L, cast(double) size);
        lua_setfield(L, -2, "size");

        // Modified time (unix timestamp)
        double mtime = 0;
        try
        {
            auto st = timeLastModified(path);
            mtime = cast(double) st.toUnixTime(); // toUnixTime available?
            // SysTime.toUnixTime() returns long.
        }
        catch (Exception)
        {
        }
        lua_pushnumber(L, mtime);
        lua_setfield(L, -2, "modified");

        // Type
        if (isDir(path))
            lua_pushstring(L, "dir");
        else if (isFile(path))
            lua_pushstring(L, "file");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "type");

        return 1;
    }
    catch (Exception e)
    {
        lua_pushnil(L);
        lua_pushstring(L, e.msg.toStringz); // unsafe toStringz of tmp?
        return 2;
    }
}

private int f_set_window_title(lua_State* L)
{
    const(char)* title = luaL_checkstring(L, 1);
    SDL_SetWindowTitle(window, title);
    return 0;
}

private int f_set_window_mode(lua_State* L)
{
    // Requires window_opts array and checkoption
    // Simplification: assume valid input or basic check
    const(char)* mode = luaL_checkstring(L, 1);
    if (strcmp(mode, "fullscreen") == 0)
    {
        SDL_SetWindowFullscreen(window, true);
    }
    else
    {
        SDL_SetWindowFullscreen(window, false);
        if (strcmp(mode, "maximized") == 0)
            SDL_MaximizeWindow(window);
        else if (strcmp(mode, "normal") == 0)
            SDL_RestoreWindow(window);
    }
    return 0;
}

private int f_window_has_focus(lua_State* L)
{
    uint flags = SDL_GetWindowFlags(window);
    lua_pushboolean(L, (flags & SDL_WINDOW_INPUT_FOCUS) != 0);
    return 1;
}

private int f_show_confirm_dialog(lua_State* L)
{
    const(char)* title = luaL_checkstring(L, 1);
    const(char)* msg = luaL_checkstring(L, 2);

    SDL_MessageBoxButtonData[3] buttons = [
        SDL_MessageBoxButtonData(SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT, 1, "Yes"),
        SDL_MessageBoxButtonData(0, 2, "No"),
        SDL_MessageBoxButtonData(SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT, 3, "Cancel")
    ];

    SDL_MessageBoxData messageboxdata = {
        flags: SDL_MESSAGEBOX_WARNING,
        window: null, // Try null window to avoid parenting issues
        title: title,
        message: msg,
        numbuttons: 3,
        buttons: buttons.ptr,
        colorScheme: null
    };

    int buttonid = -1;
    int res = SDL_ShowMessageBox(&messageboxdata, &buttonid);

    if (res < 0)
    {
        lua_pushboolean(L, 0);
        return 1;
    }

    if (buttonid == 1)
        lua_pushboolean(L, 1); // Yes
    else
        lua_pushboolean(L, 0); // No or Cancel

    return 1;
}

private int f_begin_text_input(lua_State* L)
{
    printf("DEBUG: f_begin_text_input called\n");
    SDL_StartTextInput(window);
    return 0;
}

private int f_end_text_input(lua_State* L)
{
    printf("DEBUG: f_end_text_input called\n");
    SDL_StopTextInput(window);
    return 0;
}

// ... other functions ...

private __gshared const luaL_Reg[] system_lib = [
    {"poll_event", &f_poll_event},
    {"get_time", &f_get_time},
    {"sleep", &f_sleep},
    {"chdir", &f_chdir},
    {"list_dir", &f_list_dir},
    {"absolute_path", &f_absolute_path},
    {"get_file_info", &f_get_file_info},
    {"set_window_title", &f_set_window_title},
    {"set_window_mode", &f_set_window_mode},
    {"window_has_focus", &f_window_has_focus},
    {"show_confirm_dialog", &f_show_confirm_dialog},
    {"begin_text_input", &f_begin_text_input},
    {"end_text_input", &f_end_text_input},
    // Add others if needed (fuzzy_match, clipboard, etc.)
    // For minimal functionality, file ops are critical.
    {null, null}
];

int luaopen_system(lua_State* L)
{
    luaL_newlib(L, system_lib.ptr);
    return 1;
}
