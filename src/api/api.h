#ifndef API_H
#define API_H

#include "lib/lua54/lua.h"
#include "lib/lua54/lauxlib.h"
#include "lib/lua54/lualib.h"

#define API_TYPE_FONT "Font"

void api_load_libs(lua_State *L);

#endif
