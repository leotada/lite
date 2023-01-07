module api.renderer_font;
nothrow:
extern (C):
//__gshared:
import bindbc.lua;
import api;
import renderer;
import rencache;

public immutable const(char)* API_TYPE_FONT = "Font";

private RenFont** self;

private int f_load(lua_State* L)
{
    const(char)* filename = luaL_checkstring(L, 1);
    float size = luaL_checknumber(L, 2);
    RenFont** self = cast(RenFont**) lua_newuserdata(L, typeof(*self).sizeof);
    luaL_setmetatable(L, API_TYPE_FONT);
    *self = ren_load_font(filename, size);
    if (!*self)
    {
        luaL_error(L, "failed to load font");
    }
    return 1;
}

private int f_set_tab_width(lua_State* L)
{
    RenFont** self = cast(RenFont**) luaL_checkudata(L, 1, API_TYPE_FONT);
    int n = cast(int) luaL_checknumber(L, 2);
    ren_set_font_tab_width(*self, n);
    return 0;
}

private int f_gc(lua_State* L)
{
    RenFont** self = cast(RenFont**) luaL_checkudata(L, 1, API_TYPE_FONT);
    if (*self)
    {
        rencache_free_font(*self);
    }
    return 0;
}

private int f_get_width(lua_State* L)
{
    RenFont** self = cast(RenFont**) luaL_checkudata(L, 1, API_TYPE_FONT);
    const(char)* text = luaL_checkstring(L, 2);
    lua_pushnumber(L, ren_get_font_width(*self, text));
    return 1;
}

private int f_get_height(lua_State* L)
{
    RenFont** self = cast(RenFont**) luaL_checkudata(L, 1, API_TYPE_FONT);
    lua_pushnumber(L, ren_get_font_height(*self));
    return 1;
}

private const(luaL_Reg)[6] lib = [
    {"__gc", &f_gc}, {"load", &f_load}, {"set_tab_width", &f_set_tab_width},
    {"get_width", &f_get_width}, {"get_height", &f_get_height}, {null, null}
];

int luaopen_renderer_font(lua_State* L)
{
    luaL_newmetatable(L, API_TYPE_FONT);
    luaL_setfuncs(L, lib.ptr, 0);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    return 1;
}
