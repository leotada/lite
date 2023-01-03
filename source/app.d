//@nogc nothrow:
//extern(C): __gshared:
public import core.stdc.stdio;
//public import SDL2/SDL;
import api;
public import renderer;

version (Windows) {
  public import core.sys.windows.windows;
} else static if (__linux__) {
  public import core.sys.posix.unistd;
} else static if (__APPLE__) {
  //public import mach-o/dyld;
}


SDL_Window* window;


private double get_scale() {
  float dpi = void;
  SDL_GetDisplayDPI(0, null, &dpi, null);
static if (_WIN32) {
  return dpi / 96.0;
} else {
  return 1.0;
}
}


private void get_exe_filename(char* buf, int sz) {
static if (_WIN32) {
  int len = GetModuleFileName(null, buf, sz - 1);
  buf[len] = '\0';
} else static if (__linux__) {
  char[512] path = void;
  sprintf(path.ptr, "/proc/%d/exe", getpid());
  int len = readlink(path.ptr, buf, sz - 1);
  buf[len] = '\0';
} else static if (__APPLE__) {
  uint size = sz;
  _NSGetExecutablePath(buf, &size);
} else {
  strcpy(buf, "./lite");
}
}


private void init_window_icon() {
version (Windows) {} else {
  //public import ...icon.i;
  cast(void) icon_rgba_len; /* unused */
  SDL_Surface* surf = SDL_CreateRGBSurfaceFrom(
    icon_rgba, 64, 64,
    32, 64 * 4,
    0x000000ff,
    0x0000ff00,
    0x00ff0000,
    0xff000000);
  SDL_SetWindowIcon(window, surf);
  SDL_FreeSurface(surf);
}
}


int main(int argc, char** argv) {
version (Windows) {
  HINSTANCE lib = LoadLibrary("user32.dll");
  int function() SetProcessDPIAware = cast(void*) GetProcAddress(lib, "SetProcessDPIAware");
  SetProcessDPIAware();
}

  SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS);
  SDL_EnableScreenSaver();
  SDL_EventState(SDL_DROPFILE, SDL_ENABLE);
  atexit(SDL_Quit);

version (SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR) { /* Available since 2.0.8 */
  SDL_SetHint(SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR, "0");
}
static if (SDL_VERSION_ATLEAST(2, 0, 5)) {
  SDL_SetHint(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, "1");
}

  SDL_DisplayMode dm = void;
  SDL_GetCurrentDisplayMode(0, &dm);

  window = SDL_CreateWindow(
    "", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, dm.w * 0.8, dm.h * 0.8,
    SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_HIDDEN);
  init_window_icon();
  ren_init(window);


  lua_State* L = luaL_newstate();
  luaL_openlibs(L);
  api_load_libs(L);


  lua_newtable(L);
  for (int i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i + 1);
  }
  lua_setglobal(L, "ARGS");

  lua_pushstring(L, "1.11");
  lua_setglobal(L, "VERSION");

  lua_pushstring(L, SDL_GetPlatform());
  lua_setglobal(L, "PLATFORM");

  lua_pushnumber(L, get_scale());
  lua_setglobal(L, "SCALE");

  char[2048] exename = void;
  get_exe_filename(exename.ptr, exename.sizeof);
  lua_pushstring(L, exename.ptr);
  lua_setglobal(L, "EXEFILE");


  cast(void) luaL_dostring(L,
    "local core\n"
    ~ "xpcall(function()\n"
    ~ "  SCALE = tonumber(os.getenv(\"LITE_SCALE\")) or SCALE\n"
    ~ "  PATHSEP = package.config:sub(1, 1)\n"
    ~ "  EXEDIR = EXEFILE:match(\"^(.+)[/\\\\].*$\")\n"
    ~ "  package.path = EXEDIR .. '/data/?.lua;' .. package.path\n"
    ~ "  package.path = EXEDIR .. '/data/?/init.lua;' .. package.path\n"
    ~ "  core = require('core')\n"
    ~ "  core.init()\n"
    ~ "  core.run()\n"
    ~ "end, function(err)\n"
    ~ "  print('Error: ' .. tostring(err))\n"
    ~ "  print(debug.traceback(nil, 2))\n"
    ~ "  if core and core.on_error then\n"
    ~ "    pcall(core.on_error, err)\n"
    ~ "  end\n"
    ~ "  os.exit(1)\n"
    ~ "end)");


  lua_close(L);
  SDL_DestroyWindow(window);

  return EXIT_SUCCESS;
}
