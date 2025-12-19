module app;

import core.stdc.stdio : fprintf, stderr;
import core.stdc.stdlib : exit, EXIT_FAILURE, free;
import core.stdc.string : strcpy, strlen;
import sdl3;
import renderer;
import rencache;
import lua;

// Import API loaders (to be implemented)
import api.api;
import api.system : system_window = window; // Aliasing? No.
import api.system;

extern (C) int main(int argc, char** argv)
{
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS))
    {
        fprintf(stderr, "Error: SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }
    SDL_EnableScreenSaver();
    SDL_SetEventEnabled(SDL_EVENT_DROP_FILE, true);

    // Cleanup on exit? D runtime handles main exit, but atexit(SDL_Quit) is standard.
    // We can use scope(exit) SDL_Quit();
    scope (exit)
        SDL_Quit();

    SDL_SetHint("SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR", "0");
    SDL_SetHint("SDL_MOUSE_FOCUS_CLICKTHROUGH", "1");

    const(SDL_DisplayMode)* dm = SDL_GetCurrentDisplayMode(SDL_GetPrimaryDisplay());
    int w = 800, h = 600;
    if (dm)
    {
        w = cast(int)(dm.w * 0.8);
        h = cast(int)(dm.h * 0.8);
    }

    // Initialize global window from api.system
    api.system.window = SDL_CreateWindow(
        "", w, h,
        SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY | SDL_WINDOW_HIDDEN
    );

    SDL_Window* window = api.system.window; // Local alias for convenience if needed

    if (!window)
    {
        fprintf(stderr, "Error: SDL_CreateWindow failed: %s\n", SDL_GetError());
        return 1;
    }

    // skip icon for now

    ren_init(window);
    SDL_StartTextInput(window);

    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    api_load_libs(L);

    lua_newtable(L);
    for (int i = 0; i < argc; i++)
    {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setglobal(L, "ARGS");

    lua_pushstring(L, "1.11");
    lua_setglobal(L, "VERSION");

    lua_pushstring(L, SDL_GetPlatform());
    lua_setglobal(L, "PLATFORM");

    float scale = SDL_GetDisplayContentScale(SDL_GetPrimaryDisplay());
    if (scale == 0.0f)
        scale = 1.0f;
    lua_pushnumber(L, scale);
    lua_setglobal(L, "SCALE");

    import std.file : thisExePath;
    import std.string : toStringz;

    // EXEFILE logic
    lua_pushstring(L, thisExePath().toStringz);
    lua_setglobal(L, "EXEFILE");

    const(char)* init_script = `
        local core
        xpcall(function()
          SCALE = tonumber(os.getenv("LITE_SCALE")) or SCALE
          PATHSEP = package.config:sub(1, 1)
          EXEDIR = EXEFILE:match("^(.+)[/\\].*$")
          package.path = EXEDIR .. '/data/?.lua;' .. package.path
          package.path = EXEDIR .. '/data/?/init.lua;' .. package.path
          core = require('core')
          core.init()
          core.run()
        end, function(err)
          print('Error: ' .. tostring(err))
          print(debug.traceback(nil, 2))
          if core and core.on_error then
            pcall(core.on_error, err)
          end
          os.exit(1)
        end)`;

    luaL_dostring(L, init_script);

    lua_close(L);
    SDL_DestroyWindow(window);

    return 0;
}
