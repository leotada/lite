module lua;

extern (C) nothrow:

struct lua_State;

// lua_CFunction can be GC or @nogc (non-@nogc pointer can hold @nogc func)
alias lua_CFunction = int function(lua_State* L);

// API functions are @nogc (pure C)
@nogc:

// Basic API
lua_State* luaL_newstate();
void luaL_openlibs(lua_State* L);
void lua_close(lua_State* L);
int luaL_loadstring(lua_State* L, const(char)* s);
int lua_pcallk(lua_State* L, int nargs, int nresults, int errfunc, long ctx, void* k);

// Macros/Wrappers
int luaL_dostring(lua_State* L, const(char)* s)
{
    if (luaL_loadstring(L, s) != 0)
        return 1;
    return lua_pcallk(L, 0, -1, 0, 0, null);
}

// Core
void lua_createtable(lua_State* L, int narr, int nrec);
void lua_newtable(lua_State* L)
{
    lua_createtable(L, 0, 0);
}

// Stack
void lua_settop(lua_State* L, int idx);
int lua_gettop(lua_State* L);
void lua_pop(lua_State* L, int n)
{
    lua_settop(L, -n - 1);
}

// Push functions
void lua_pushnil(lua_State* L);
void lua_pushboolean(lua_State* L, int b);
void lua_pushlightuserdata(lua_State* L, void* p);
void lua_pushnumber(lua_State* L, double n);
void lua_pushinteger(lua_State* L, long n);
void lua_pushstring(lua_State* L, const(char)* s);
void lua_pushlstring(lua_State* L, const(char)* s, size_t len);
void lua_pushvalue(lua_State* L, int idx);

// Get/Set access
void lua_rawget(lua_State* L, int idx);
void lua_rawgeti(lua_State* L, int idx, long n);
void lua_rawset(lua_State* L, int idx);
void lua_rawseti(lua_State* L, int idx, long n);
void lua_setglobal(lua_State* L, const(char)* name);
void lua_getglobal(lua_State* L, const(char)* name);

int lua_type(lua_State* L, int idx);
const(char)* lua_typename(lua_State* L, int tp);

// Getters
int lua_toboolean(lua_State* L, int idx);
const(char)* lua_tolstring(lua_State* L, int idx, size_t* len);
const(char)* lua_tostring(lua_State* L, int idx)
{
    return lua_tolstring(L, idx, null);
}

double lua_tonumberx(lua_State* L, int idx, int* isnum);
double lua_tonumber(lua_State* L, int idx)
{
    return lua_tonumberx(L, idx, null);
}

long lua_tointegerx(lua_State* L, int idx, int* isnum);
long lua_tointeger(lua_State* L, int idx)
{
    return lua_tointegerx(L, idx, null);
}

void lua_rawgeti(lua_State* L, int idx, long n);
void lua_setfield(lua_State* L, int idx, const(char)* k);

int lua_isnumber(lua_State* L, int idx);
int lua_isstring(lua_State* L, int idx);
int lua_isuserdata(lua_State* L, int idx);
bool lua_isnoneornil(lua_State* L, int idx)
{
    return lua_type(L, idx) <= 0;
}

// Aux
// luaL_Reg definition needs to be available. struct definitions are agnostic.
struct luaL_Reg
{
    const(char)* name;
    lua_CFunction func;
}

void luaL_checkany(lua_State* L, int arg);
const(char)* luaL_checklstring(lua_State* L, int arg, size_t* l);
const(char)* luaL_checkstring(lua_State* L, int arg)
{
    return luaL_checklstring(L, arg, null);
}

const(char)* luaL_optlstring(lua_State* L, int arg, const(char)* def, size_t* l);
double luaL_checknumber(lua_State* L, int arg);
double luaL_optnumber(lua_State* L, int arg, double def);
long luaL_checkinteger(lua_State* L, int arg);
long luaL_optinteger(lua_State* L, int arg, long def);

void* luaL_checkudata(lua_State* L, int arg, const(char)* tname);
int luaL_newmetatable(lua_State* L, const(char)* tname);
void luaL_setmetatable(lua_State* L, const(char)* tname);
void* luaL_testudata(lua_State* L, int arg, const(char)* tname);

int luaL_error(lua_State* L, const(char)* fmt, ...);

// lua_newuserdata is macro in 5.4: lua_newuserdatauv(L, s, 1)
void* lua_newuserdatauv(lua_State* L, size_t sz, int nuvalue);
void* lua_newuserdata(lua_State* L, size_t sz)
{
    return lua_newuserdatauv(L, sz, 1);
}

void luaL_requiref(lua_State* L, const(char)* modname, lua_CFunction openf, int glb);

// Newlib macros
void luaL_setfuncs(lua_State* L, const(luaL_Reg)* l, int nup);
void luaL_newlibtable(lua_State* L, const(luaL_Reg)* l)
{
    lua_createtable(L, 0, cast(int)((l ? l[0].sizeof : 0) / luaL_Reg.sizeof) - 1); // rough guess or ignore size hint
} // Actually usually definition involves counting.
// For D, better to just pass pointer.
void luaL_newlib(lua_State* L, const(luaL_Reg)* l)
{
    luaL_checkversion(L);
    lua_createtable(L, 0, 0); // simplify
    luaL_setfuncs(L, l, 0);
}

void luaL_checkversion_(lua_State* L, double ver, size_t sz);
// luaL_checkversion macro implementation
void luaL_checkversion(lua_State* L)
{
    // Lua 5.4 encodes type sizes in the 3rd argument
    enum LUA_VERSION_NUM = 504; // Assuming Lua 5.4
    alias lua_Integer = long; // Assuming D's long maps to Lua's lua_Integer
    alias lua_Number = double; // Assuming D's double maps to Lua's lua_Number
    luaL_checkversion_(L, LUA_VERSION_NUM, (lua_Integer.sizeof * 16 + lua_Number.sizeof));
}
// ... Add more as needed by api/*.c ports
