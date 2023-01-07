module api;
nothrow:
__gshared:
import bindbc.lua;
import api.system : luaopen_system;
import api.renderer : luaopen_renderer;

private static const luaL_Reg[3] libs = [
    {"system", &luaopen_system}, {"renderer", &luaopen_renderer}, {null, null}
];

void api_load_libs(lua_State* L)
{
    for (int i = 0; libs[i].name; i++)
    {
        luaL_requiref(L, libs[i].name, libs[i].func, 1);
    }
}
