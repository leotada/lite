module renderer;

import sdl3;
import stb_truetype;
import core.stdc.stdlib : malloc, free, calloc, exit, EXIT_FAILURE;
import core.stdc.stdio : fprintf, stderr;
import core.stdc.string : memset;
import std.math : floor;

extern (C) @nogc nothrow:

struct RenImage
{
    RenColor* pixels;
    int width, height;
}

struct RenColor
{
    ubyte b, g, r, a;
}

struct RenRect
{
    int x, y, width, height;
}

struct GlyphSet
{
    RenImage* image;
    stbtt_bakedchar[256] glyphs;
}

struct RenFont
{
    void* data;
    stbtt_fontinfo stbfont;
    GlyphSet*[256] sets;
    float size;
    int height;
}

// Global state
private __gshared SDL_Window* window;
private __gshared RenRect clip;

// Helper allocation check
private void* check_alloc(void* ptr)
{
    if (!ptr)
    {
        fprintf(stderr, "Fatal error: memory allocation failed\n");
        exit(EXIT_FAILURE);
    }
    return ptr;
}

void ren_init(SDL_Window* win)
{
    if (!win)
        exit(EXIT_FAILURE);
    window = win;
    SDL_Surface* surf = SDL_GetWindowSurface(window);
    ren_set_clip_rect(RenRect(0, 0, surf.w, surf.h));
}

void ren_update_rects(RenRect* rects, int count)
{
    SDL_UpdateWindowSurfaceRects(window, cast(SDL_Rect*) rects, count);
    static bool initial_frame = true;
    if (initial_frame)
    {
        SDL_ShowWindow(window);
        initial_frame = false;
    }
}

void ren_set_clip_rect(RenRect rect)
{
    clip_rect.left = rect.x;
    clip_rect.top = rect.y;
    clip_rect.right = rect.x + rect.width;
    clip_rect.bottom = rect.y + rect.height;
}

// Redefine clip properly
private struct ClipRect
{
    int left, top, right, bottom;
}

private __gshared ClipRect clip_rect;

// Fix ren_set_clip_rect logic
// void ren_set_clip_rect(RenRect rect) implementation above was modifying struct type?
// Let's rewrite:

void ren_get_size(int* x, int* y)
{
    SDL_Surface* surf = SDL_GetWindowSurface(window);
    *x = surf.w;
    *y = surf.h;
}

RenImage* ren_new_image(int width, int height)
{
    if (width <= 0 || height <= 0)
        return null; // assert replacement
    // RenImage* image = malloc(sizeof(RenImage) + width * height * sizeof(RenColor));
    size_t size = RenImage.sizeof + width * height * RenColor.sizeof;
    RenImage* image = cast(RenImage*) check_alloc(malloc(size));
    image.pixels = cast(RenColor*)(image + 1);
    image.width = width;
    image.height = height;
    return image;
}

void ren_free_image(RenImage* image)
{
    free(image);
}

// ... Additional helper functions ...

private const(char)* utf8_to_codepoint(const(char)* p, uint* dst)
{
    uint res, n;
    switch (*p & 0xf0)
    {
    case 0xf0:
        res = *p & 0x07;
        n = 3;
        break;
    case 0xe0:
        res = *p & 0x0f;
        n = 2;
        break;
    case 0xd0:
    case 0xc0:
        res = *p & 0x1f;
        n = 1;
        break;
    default:
        res = *p;
        n = 0;
        break;
    }
    while (n--)
    {
        res = (res << 6) | (*(++p) & 0x3f);
    }
    *dst = res;
    return p + 1;
}

private GlyphSet* load_glyphset(RenFont* font, int idx)
{
    GlyphSet* set = cast(GlyphSet*) check_alloc(calloc(1, GlyphSet.sizeof));

    int width = 128;
    int height = 128;

retry:
    set.image = ren_new_image(width, height);

    float s = stbtt_ScaleForMappingEmToPixels(&font.stbfont, 1) /
        stbtt_ScaleForPixelHeight(&font.stbfont, 1);

    int res = stbtt_BakeFontBitmap(
        cast(ubyte*) font.data, 0, font.size * s, cast(ubyte*) set.image.pixels,
        width, height, idx * 256, 256, set.glyphs.ptr);

    if (res < 0)
    {
        width *= 2;
        height *= 2;
        ren_free_image(set.image);
        goto retry;
    }

    int ascent, descent, linegap;
    stbtt_GetFontVMetrics(&font.stbfont, &ascent, &descent, &linegap);
    float scale = stbtt_ScaleForMappingEmToPixels(&font.stbfont, font.size);
    int scaled_ascent = cast(int)(ascent * scale + 0.5f);

    for (int i = 0; i < 256; i++)
    {
        set.glyphs[i].yoff += scaled_ascent;
        set.glyphs[i].xadvance = floor(set.glyphs[i].xadvance);
    }

    // Convert 8bit to 32bit
    for (int i = width * height - 1; i >= 0; i--)
    {
        ubyte n = (cast(ubyte*) set.image.pixels)[i];
        set.image.pixels[i] = RenColor(255, 255, 255, n);
    }

    return set;
}

private GlyphSet* get_glyphset(RenFont* font, int codepoint)
{
    int idx = (codepoint >> 8) % 256;
    if (!font.sets[idx])
    {
        font.sets[idx] = load_glyphset(font, idx);
    }
    return font.sets[idx];
}

RenFont* ren_load_font(const(char)* filename, float size)
{
    RenFont* font = cast(RenFont*) check_alloc(calloc(1, RenFont.sizeof));
    font.size = size;

    import core.stdc.stdio : fopen, fseek, ftell, fread, fclose, FILE, SEEK_END, SEEK_SET;

    FILE* fp = fopen(filename, "rb");
    if (!fp)
    {
        free(font);
        return null;
    }

    fseek(fp, 0, SEEK_END);
    int buf_size = cast(int) ftell(fp);
    fseek(fp, 0, SEEK_SET);

    font.data = check_alloc(malloc(buf_size));
    fread(font.data, 1, buf_size, fp);
    fclose(fp);

    if (!stbtt_InitFont(&font.stbfont, cast(ubyte*) font.data, 0))
    {
        free(font.data);
        free(font);
        return null;
    }

    int ascent, descent, linegap;
    stbtt_GetFontVMetrics(&font.stbfont, &ascent, &descent, &linegap);
    float scale = stbtt_ScaleForMappingEmToPixels(&font.stbfont, size);
    font.height = cast(int)((ascent - descent + linegap) * scale + 0.5f);

    stbtt_bakedchar* g = get_glyphset(font, '\n').glyphs.ptr;
    g['\t'].x1 = g['\t'].x0;
    g['\n'].x1 = g['\n'].x0;

    return font;
}

void ren_free_font(RenFont* font)
{
    for (int i = 0; i < 256; i++)
    {
        GlyphSet* set = font.sets[i];
        if (set)
        {
            ren_free_image(set.image);
            free(set);
        }
    }
    free(font.data);
    free(font);
}

void ren_set_font_tab_width(RenFont* font, int n)
{
    GlyphSet* set = get_glyphset(font, '\t');
    set.glyphs['\t'].xadvance = n;
}

int ren_get_font_tab_width(RenFont* font)
{
    GlyphSet* set = get_glyphset(font, '\t');
    return cast(int) set.glyphs['\t'].xadvance;
}

int ren_get_font_width(RenFont* font, const(char)* text)
{
    int x = 0;
    const(char)* p = text;
    uint codepoint;
    while (*p)
    {
        p = utf8_to_codepoint(p, &codepoint);
        GlyphSet* set = get_glyphset(font, codepoint);
        stbtt_bakedchar* g = &set.glyphs[codepoint & 0xff];
        x += cast(int) g.xadvance;
    }
    return x;
}

int ren_get_font_height(RenFont* font)
{
    return font.height;
}

// Blending
private RenColor blend_pixel(RenColor dst, RenColor src)
{
    int ia = 0xff - src.a;
    dst.r = cast(ubyte)((src.r * src.a + dst.r * ia) >> 8);
    dst.g = cast(ubyte)((src.g * src.a + dst.g * ia) >> 8);
    dst.b = cast(ubyte)((src.b * src.a + dst.b * ia) >> 8);
    return dst;
}

private RenColor blend_pixel2(RenColor dst, RenColor src, RenColor color)
{
    src.a = cast(ubyte)((src.a * color.a) >> 8);
    int ia = 0xff - src.a;
    dst.r = cast(ubyte)(((src.r * color.r * src.a) >> 16) + ((dst.r * ia) >> 8));
    dst.g = cast(ubyte)(((src.g * color.g * src.a) >> 16) + ((dst.g * ia) >> 8));
    dst.b = cast(ubyte)(((src.b * color.b * src.a) >> 16) + ((dst.b * ia) >> 8));
    return dst;
}

void ren_draw_rect(RenRect rect, RenColor color)
{
    if (color.a == 0)
        return;

    int x1 = rect.x < clip_rect.left ? clip_rect.left : rect.x;
    int y1 = rect.y < clip_rect.top ? clip_rect.top : rect.y;
    int x2 = rect.x + rect.width;
    int y2 = rect.y + rect.height;
    x2 = x2 > clip_rect.right ? clip_rect.right : x2;
    y2 = y2 > clip_rect.bottom ? clip_rect.bottom : y2;

    SDL_Surface* surf = SDL_GetWindowSurface(window);
    RenColor* d = cast(RenColor*) surf.pixels;
    d += x1 + y1 * surf.w;
    int dr = surf.w - (x2 - x1);

    if (color.a == 0xff)
    {
        for (int j = y1; j < y2; j++)
        {
            for (int i = x1; i < x2; i++)
            {
                *d = color;
                d++;
            }
            d += dr;
        }
    }
    else
    {
        for (int j = y1; j < y2; j++)
        {
            for (int i = x1; i < x2; i++)
            {
                *d = blend_pixel(*d, color);
                d++;
            }
            d += dr;
        }
    }
}

void ren_draw_image(RenImage* image, RenRect* sub, int x, int y, RenColor color)
{
    if (color.a == 0)
        return;

    // clip
    int n;
    if ((n = clip_rect.left - x) > 0)
    {
        sub.width -= n;
        sub.x += n;
        x += n;
    }
    if ((n = clip_rect.top - y) > 0)
    {
        sub.height -= n;
        sub.y += n;
        y += n;
    }
    if ((n = x + sub.width - clip_rect.right) > 0)
    {
        sub.width -= n;
    }
    if ((n = y + sub.height - clip_rect.bottom) > 0)
    {
        sub.height -= n;
    }

    if (sub.width <= 0 || sub.height <= 0)
        return;

    SDL_Surface* surf = SDL_GetWindowSurface(window);
    RenColor* s = image.pixels;
    RenColor* d = cast(RenColor*) surf.pixels;
    s += sub.x + sub.y * image.width;
    d += x + y * surf.w;
    int sr = image.width - sub.width;
    int dr = surf.w - sub.width;

    for (int j = 0; j < sub.height; j++)
    {
        for (int i = 0; i < sub.width; i++)
        {
            *d = blend_pixel2(*d, *s, color);
            d++;
            s++;
        }
        d += dr;
        s += sr;
    }
}

int ren_draw_text(RenFont* font, const(char)* text, int x, int y, RenColor color)
{
    RenRect rect;
    const(char)* p = text;
    uint codepoint;
    while (*p)
    {
        p = utf8_to_codepoint(p, &codepoint);
        GlyphSet* set = get_glyphset(font, codepoint);
        stbtt_bakedchar* g = &set.glyphs[codepoint & 0xff];
        rect.x = g.x0;
        rect.y = g.y0;
        rect.width = g.x1 - g.x0;
        rect.height = g.y1 - g.y0;
        ren_draw_image(set.image, &rect, cast(int)(x + g.xoff), cast(int)(y + g.yoff), color);
        x += cast(int) g.xadvance;
    }
    return x;
}
