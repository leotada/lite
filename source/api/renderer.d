module api.renderer;

import lua;
import renderer;
import rencache;
import core.stdc.stdlib : malloc, free; // For implementation details if needed

extern (C) @nogc nothrow:

private RenColor checkcolor(lua_State* L, int idx, int def)
{
    if (lua_isnoneornil(L, idx))
    {
        return RenColor(cast(ubyte) def, cast(ubyte) def, cast(ubyte) def, 255);
    }
    lua_rawgeti(L, idx, 1);
    lua_rawgeti(L, idx, 2);
    lua_rawgeti(L, idx, 3);
    lua_rawgeti(L, idx, 4);

    RenColor color;
    color.r = cast(ubyte) luaL_checknumber(L, -4);
    color.g = cast(ubyte) luaL_checknumber(L, -3);
    color.b = cast(ubyte) luaL_checknumber(L, -2);
    color.a = cast(ubyte) luaL_optnumber(L, -1, 255);

    lua_pop(L, 4);
    return color;
}

private int f_show_debug(lua_State* L)
{
    luaL_checkany(L, 1);
    rencache_show_debug(lua_toboolean(L, 1) != 0);
    return 0;
}

private int f_get_size(lua_State* L)
{
    int w, h;
    ren_get_size(&w, &h);
    lua_pushnumber(L, w);
    lua_pushnumber(L, h);
    return 2;
}

private int f_begin_frame(lua_State* L)
{
    rencache_begin_frame();
    return 0;
}

private int f_end_frame(lua_State* L)
{
    rencache_end_frame();
    return 0;
}

private int f_set_clip_rect(lua_State* L)
{
    RenRect rect;
    rect.x = cast(int) luaL_checknumber(L, 1);
    rect.y = cast(int) luaL_checknumber(L, 2);
    rect.width = cast(int) luaL_checknumber(L, 3);
    rect.height = cast(int) luaL_checknumber(L, 4);
    rencache_set_clip_rect(rect);
    return 0;
}

private int f_draw_rect(lua_State* L)
{
    RenRect rect;
    rect.x = cast(int) luaL_checknumber(L, 1);
    rect.y = cast(int) luaL_checknumber(L, 2);
    rect.width = cast(int) luaL_checknumber(L, 3);
    rect.height = cast(int) luaL_checknumber(L, 4);
    RenColor color = checkcolor(L, 5, 255);
    rencache_draw_rect(rect, color);
    return 0;
}

private int f_draw_text(lua_State* L)
{
    RenFont** font = cast(RenFont**) luaL_checkudata(L, 1, "RenFont"); // Make sure "RenFont" matches what font module uses
    const(char)* text = luaL_checkstring(L, 2);
    int x = cast(int) luaL_checknumber(L, 3);
    int y = cast(int) luaL_checknumber(L, 4);
    RenColor color = checkcolor(L, 5, 255);
    x = rencache_draw_text(*font, text, x, y, color);
    lua_pushnumber(L, x);
    return 1;
}

// TODO: Font functions (load, free, etc.) usually in api/renderer_font.c but referenced here?
// No, luaopen_renderer calls luaopen_renderer_font.

private __gshared const luaL_Reg[] renderer_lib = [
    {"show_debug", &f_show_debug},
    {"get_size", &f_get_size},
    {"begin_frame", &f_begin_frame},
    {"end_frame", &f_end_frame},
    {"set_clip_rect", &f_set_clip_rect},
    {"draw_rect", &f_draw_rect},
    {"draw_text", &f_draw_text},
    {null, null}
];

// Forward declaration
int luaopen_renderer_font(lua_State* L);

int luaopen_renderer(lua_State* L)
{
    luaL_newlib(L, renderer_lib.ptr);
    luaopen_renderer_font(L);
    lua_setfield(L, -2, "font");
    return 1;
}
