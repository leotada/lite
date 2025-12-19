module api.api;

import lua;
import api.renderer;

import api.system;

extern (C) @nogc nothrow:

// Forwards
// int luaopen_system(lua_State* L); // imported from api.system

private __gshared const luaL_Reg[] libs = [
    {"system", &luaopen_system},
    {"renderer", &luaopen_renderer},
    {null, null}
];

void api_load_libs(lua_State* L)
{
    for (int i = 0; libs[i].name; i++)
    {
        luaL_requiref(L, libs[i].name, libs[i].func, 1);
    }
}
