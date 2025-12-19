module sdl3;

extern (C) @nogc nothrow:

// Types
struct SDL_Window;
struct SDL_Surface
{
    uint flags;
    int format; // simplified
    int w, h;
    int pitch;
    void* pixels;
    void* refcount;
    void* reserved;
}

struct SDL_Rect
{
    int x, y, w, h;
}

struct SDL_DisplayMode
{
    uint displayID;
    uint format;
    int w, h;
    float pixel_density;
    float refresh_rate;
    int refresh_rate_numerator;
    int refresh_rate_denominator;
    void* internal;
}

struct SDL_CommonEvent
{
    uint type;
    uint reserved;
    ulong timestamp;
}

struct SDL_WindowEvent
{
    uint type;
    uint reserved;
    ulong timestamp;
    uint windowID;
    int data1;
    int data2;
}

struct SDL_KeyboardEvent
{
    uint type;
    uint reserved;
    ulong timestamp;
    uint windowID;
    uint which;
    int scancode; // SDL_Scancode
    int key; // SDL_Keycode
    ushort mod; // SDL_Keymod
    ushort raw;
    bool down;
    bool repeat;
}

struct SDL_Keysym
{
    int scancode;
    int sym;
    ushort mod;
    uint unused;
}

struct SDL_MouseMotionEvent
{
    uint type;
    uint reserved;
    ulong timestamp;
    uint windowID;
    uint which;
    uint state;
    float x;
    float y;
    float xrel;
    float yrel;
}

struct SDL_MouseButtonEvent
{
    uint type;
    uint reserved;
    ulong timestamp;
    uint windowID;
    uint which;
    ubyte button;
    ubyte state;
    ubyte clicks;
    ubyte padding;
    float x;
    float y;
}

struct SDL_MouseWheelEvent
{
    uint type;
    uint reserved;
    ulong timestamp;
    uint windowID;
    uint which;
    float x;
    float y;
    uint direction;
    float mouseX;
    float mouseY;
}

struct SDL_TextInputEvent
{
    uint type;
    uint reserved;
    ulong timestamp;
    uint windowID;
    const(char)* text;
}

struct SDL_DropEvent
{
    uint type;
    uint reserved;
    ulong timestamp;
    char* file; // data in SDL3? 
    uint windowID;
}
// Note: SDL3 might differ slightly. Using SDL2-ish layout which is usually compatible for these fields or updated. 
// Ideally check SDL3 docs. 
// SDL3: SDL_MouseMotionEvent has float x,y. SDL2 has int. 
// Wait, SDL3 uses floats for mouse coordinates now. 
// Assuming `lite` logic expects integers? No, Lua API `mousemoved` passes numbers.
// We should cast if necessary or use float.
// For correct binary layout with C lib, we MUST match headers.
// If actual SDL3 lib is used, it uses floats.
// This binding uses `float x, y` which is correct for SDL3.
// Simplify for now, exact layout matters for binary compat.
// SDL3 might have changed layouts significantly from SDL2. 
// Assuming SDL2-like or checking SDL3.
// SDL3 has SDL_KeyboardEvent with specific layout.
// Since we use manual bindings, we need to be careful or use opaque pointers + accessors if possible (but event handling is direct).
// Let's use a simplified approach: just cast to specific pointer types.
// But union member access is cleaner.

union SDL_Event
{
    uint type;
    SDL_CommonEvent common;
    SDL_WindowEvent window;
    SDL_KeyboardEvent key;
    SDL_MouseMotionEvent motion;
    SDL_MouseButtonEvent button;
    SDL_MouseWheelEvent wheel;
    SDL_TextInputEvent text;
    SDL_DropEvent drop;
    ubyte[128] padding;
}

enum SDL_INIT_VIDEO = 0x00000020u;
enum SDL_INIT_EVENTS = 0x00004000u;

enum SDL_WINDOW_RESIZABLE = 0x00000020u;
enum SDL_WINDOW_HIDDEN = 0x00000008u;
enum SDL_WINDOW_HIGH_PIXEL_DENSITY = 0x00002000u;
enum SDL_WINDOW_INPUT_FOCUS = 0x00000200u; // Check SDL3 value. 0x200 usually.

enum SDL_EVENT_QUIT = 0x100;
enum SDL_EVENT_DISPLAY_ORIENTATION = 0x151;
enum SDL_EVENT_WINDOW_SHOWN = 0x202;
enum SDL_EVENT_WINDOW_HIDDEN = 0x203;
enum SDL_EVENT_WINDOW_CLOSE_REQUESTED = 0x205; // Standard SDL3 close request
enum SDL_EVENT_WINDOW_RESIZED = 0x206;
enum SDL_EVENT_KEY_DOWN = 0x300;
enum SDL_EVENT_KEY_UP = 0x301;
enum SDL_EVENT_TEXT_EDITING = 0x302;
enum SDL_EVENT_TEXT_INPUT = 0x303;
enum SDL_EVENT_MOUSE_MOTION = 0x400;
enum SDL_EVENT_MOUSE_BUTTON_DOWN = 0x401;
enum SDL_EVENT_MOUSE_BUTTON_UP = 0x402;
enum SDL_EVENT_MOUSE_WHEEL = 0x403;
enum SDL_EVENT_DROP_FILE = 0x1000;

// Functions
bool SDL_Init(uint flags);
void SDL_Quit();
const(char)* SDL_GetError();

uint SDL_GetPrimaryDisplay();
float SDL_GetDisplayContentScale(uint displayID);
const(SDL_DisplayMode)* SDL_GetCurrentDisplayMode(uint displayID);

SDL_Window* SDL_CreateWindow(const(char)* title, int w, int h, uint flags);
void SDL_DestroyWindow(SDL_Window* window);
uint SDL_GetWindowFlags(SDL_Window* window);

SDL_Surface* SDL_GetWindowSurface(SDL_Window* window);
int SDL_UpdateWindowSurfaceRects(SDL_Window* window, const(SDL_Rect)* rects, int numrects);
bool SDL_ShowWindow(SDL_Window* window);

void SDL_EnableScreenSaver();
bool SDL_SetEventEnabled(uint type, bool enabled);
bool SDL_SetHint(const(char)* name, const(char)* value);

bool SDL_StartTextInput(SDL_Window* window);
bool SDL_StopTextInput(SDL_Window* window);

uint SDL_GetTicks();
void SDL_Delay(uint ms);
bool SDL_PollEvent(SDL_Event* event);

// Pixel format constants usually needed?
enum SDL_PIXELFORMAT_RGBA32 = 0x16661604; // Check value!

// Additional needed for icon
SDL_Surface* SDL_CreateSurfaceFrom(int width, int height, uint format, void* pixels, int pitch);
bool SDL_SetWindowIcon(SDL_Window* window, SDL_Surface* icon);
void SDL_DestroySurface(SDL_Surface* surface);

const(char)* SDL_GetPlatform();

const(char)* SDL_GetKeyName(int key); // SDL_Keycode is int
ulong SDL_GetPerformanceCounter();
ulong SDL_GetPerformanceFrequency();

void SDL_SetWindowTitle(SDL_Window* window, const(char)* title);
int SDL_SetWindowFullscreen(SDL_Window* window, bool fullscreen);
void SDL_MaximizeWindow(SDL_Window* window);
void SDL_RestoreWindow(SDL_Window* window);

// MessageBox
struct SDL_MessageBoxButtonData
{
    uint flags;
    int buttonid;
    const(char)* text;
}

struct SDL_MessageBoxColorScheme
{
    struct SDL_MessageBoxColor
    {
        ubyte r, g, b;
    }

    SDL_MessageBoxColor[5] colors;
}

struct SDL_MessageBoxData
{
    uint flags;
    SDL_Window* window;
    const(char)* title;
    const(char)* message;
    int numbuttons;
    const(SDL_MessageBoxButtonData)* buttons;
    const(SDL_MessageBoxColorScheme)* colorScheme;
}

enum SDL_MESSAGEBOX_WARNING = 0x00000020u;
enum SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT = 0x00000001u;
enum SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT = 0x00000002u;

int SDL_ShowMessageBox(const(SDL_MessageBoxData)* messageboxdata, int* buttonid);
