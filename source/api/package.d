module api;
@safe:
import bindbc.lua;

int luaopen_system(lua_State* L);
int luaopen_renderer(lua_State* L);


static struct _Reg
{
    string name;
    void* func;
    this(string name, void* func)
    {
        this.name = name;
        this.func = func;
    }
}

static const _Reg[3] libs = [
    _Reg("system", &luaopen_system),
    _Reg("renderer", &luaopen_renderer),
    _Reg(null, null)
];

void api_load_libs(lua_State* L) {
    for (int i = 0; libs[i].name; i++) {
        luaL_requiref(L, libs[i].name, libs[i].func, 1);
    }
}
