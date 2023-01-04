module api;
@nogc nothrow:
extern (C):
import bindbc.lua;

int luaopen_system(lua_State* L);
int luaopen_renderer(lua_State* L);

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
