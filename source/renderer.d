module renderer;
nothrow:
extern (C):
__gshared:
import bindbc.sdl;
public import core.stdc.stdio;
import core.stdc.stdlib : malloc, calloc, free, exit;

//public import stdbool;
public import core.stdc.assert_;
public import core.stdc.math;
public import lib.stb.stb_truetype;

enum MAX_GLYPHSET = 256;

struct _RenColor
{
    ubyte b, g, r, a;
}

alias RenColor = _RenColor;

struct _RenRect
{
    int x, y, width, height;
}

alias RenRect = _RenRect;

struct RenImage
{
    RenColor* pixels;
    int width, height;
}

struct _GlyphSet
{
    RenImage* image;
    stbtt_bakedchar[256] glyphs;
}

alias GlyphSet = _GlyphSet;

struct RenFont
{
    void* data;
    stbtt_fontinfo stbfont;
    GlyphSet*[MAX_GLYPHSET] sets;
    float size = 0;
    int height;
}

private SDL_Window* window;
struct _Clip
{
    int left, top, right, bottom;
}

private _Clip clip;

private void* check_alloc(void* ptr)
{
    if (!ptr)
    {
        cast(int) fprintf(stderr, "Fatal error: memory allocation failed\n");
        exit(1);
    }
    return ptr;
}

private const(char)* utf8_to_codepoint(const(char)* p, uint* dst)
{
    uint res = void, n = void;
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

void ren_init(SDL_Window* win)
{
    assert(win);
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
    clip.left = rect.x;
    clip.top = rect.y;
    clip.right = rect.x + rect.width;
    clip.bottom = rect.y + rect.height;
}

void ren_get_size(int* x, int* y)
{
    SDL_Surface* surf = SDL_GetWindowSurface(window);
    *x = surf.w;
    *y = surf.h;
}

RenImage* ren_new_image(int width, int height)
{
    assert(width > 0 && height > 0);
    RenImage* image = new RenImage;
    check_alloc(image);
    // image.pixels = cast(void*)(image.ptr + 1);
    image.width = width;
    image.height = height;
    return image;
}

void ren_free_image(RenImage* image)
{
    free(image);
}

private GlyphSet* load_glyphset(RenFont* font, int idx)
{
    // GlyphSet* set = check_alloc(calloc(1, GlyphSet.sizeof));
    GlyphSet* set = new GlyphSet;

    /* init image */
    int width = 128;
    int height = 128;
retry:
    set.image = ren_new_image(width, height);

    // /* load glyphs */
    // float s = stbtt_ScaleForMappingEmToPixels(&font.stbfont, 1) / stbtt_ScaleForPixelHeight(
    //         &font.stbfont, 1);
    // int res = stbtt_BakeFontBitmap(font.data, 0, font.size * s,
    //         cast(void*) set.image.pixels, width, height, idx * 256, 256, set.glyphs);

    // /* retry with a larger image buffer if the buffer wasn't large enough */
    // if (res < 0)
    // {
    //     width *= 2;
    //     height *= 2;
    //     ren_free_image(set.image);
    //     goto retry;
    // }

    /* adjust glyph yoffsets and xadvance */
    int ascent = void, descent = void, linegap = void;
    try
    {
        stbtt_GetFontVMetrics(&font.stbfont, &ascent, &descent, &linegap);

        float scale = stbtt_ScaleForMappingEmToPixels(&font.stbfont, font.size);
        int scaled_ascent = cast(int)(ascent * scale + 0.5);
        for (int i = 0; i < 256; i++)
        {
            set.glyphs[i].yoff += scaled_ascent;
            set.glyphs[i].xadvance = floor(set.glyphs[i].xadvance);
        }
    }
    catch (Exception)
    {
        return null; // TODO
    }

    /* convert 8bit data to 32bit */
    for (int i = width * height - 1; i >= 0; i--)
    {
        ubyte n = *(cast(ubyte*) set.image.pixels + i);
        set.image.pixels[i] = RenColor(255, 255, 255, n);
    }

    return set;
}

private GlyphSet* get_glyphset(RenFont* font, int codepoint)
{
    int idx = (codepoint >> 8) % MAX_GLYPHSET;
    if (!font.sets[idx])
    {
        font.sets[idx] = load_glyphset(font, idx);
    }
    return font.sets[idx];
}

RenFont* ren_load_font(const(char)* filename, float size)
{
    RenFont* font = null;
    FILE* fp = null;

    /* init font */
    // font = check_alloc(calloc(1, RenFont.sizeof));
    font = new RenFont;
    font.size = size;

    /* load font into buffer */
    fp = fopen(filename, "rb");
    if (!fp)
    {
        return null;
    }
    /* get size */
    fseek(fp, 0, SEEK_END);
    int buf_size = cast(int) ftell(fp);
    fseek(fp, 0, SEEK_SET);
    /* load */
    font.data = check_alloc(malloc(buf_size));
    int _ = cast(int) fread(font.data, 1, buf_size, fp);
    cast(void) _;
    fclose(fp);
    fp = null;

    /* init stbfont */
    try
    {
        int ok = cast(int) stbtt_InitFont(&font.stbfont, cast(const(ubyte)*) font.data, 0);
        if (!ok)
        {
            goto fail;
        }

        /* get height and scale */
        int ascent = void, descent = void, linegap = void;
        stbtt_GetFontVMetrics(&font.stbfont, &ascent, &descent, &linegap);
        float scale = stbtt_ScaleForMappingEmToPixels(&font.stbfont, size);
        font.height = cast(int)((ascent - descent + linegap) * scale + 0.5);

        /* make tab and newline glyphs invisible */
        stbtt_bakedchar* g = get_glyphset(font, '\n').glyphs.ptr;
        g['\t'].x1 = g['\t'].x0;
        g['\n'].x1 = g['\n'].x0;

        return font;

    }
    catch (Exception)
    {
        goto fail;
    }

fail:
    if (fp)
    {
        fclose(fp);
    }
    if (font)
    {
        free(font.data);
    }
    free(font);
    return null;
}

void ren_free_font(RenFont* font)
{
    for (int i = 0; i < MAX_GLYPHSET; i++)
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
    uint codepoint = void;
    while (*p)
    {
        p = utf8_to_codepoint(p, &codepoint);
        GlyphSet* set = get_glyphset(font, codepoint);
        stbtt_bakedchar* g = &set.glyphs[codepoint & 0xff];
        x += g.xadvance;
    }
    return x;
}

int ren_get_font_height(RenFont* font)
{
    return font.height;
}

pragma(inline, true) private RenColor blend_pixel(RenColor dst, RenColor src)
{
    int ia = 0xff - src.a;
    dst.r = cast(ubyte)((src.r * src.a) + (dst.r * ia)) >> 8;
    dst.g = cast(ubyte)((src.g * src.a) + (dst.g * ia)) >> 8;
    dst.b = cast(ubyte)((src.b * src.a) + (dst.b * ia)) >> 8;
    return dst;
}

pragma(inline, true) private RenColor blend_pixel2(RenColor dst, RenColor src, RenColor color)
{
    src.a = (src.a * color.a) >> 8;
    int ia = 0xff - src.a;
    dst.r = cast(ubyte)(((src.r * color.r * src.a) >> 16) + ((dst.r * ia) >> 8));
    dst.g = cast(ubyte)(((src.g * color.g * src.a) >> 16) + ((dst.g * ia) >> 8));
    dst.b = cast(ubyte)(((src.b * color.b * src.a) >> 16) + ((dst.b * ia) >> 8));
    return dst;
}

void ren_draw_rect(RenRect rect, RenColor color)
{
    if (color.a == 0)
    {
        return;
    }

    int x1 = rect.x < clip.left ? clip.left : rect.x;
    int y1 = rect.y < clip.top ? clip.top : rect.y;
    int x2 = rect.x + rect.width;
    int y2 = rect.y + rect.height;
    x2 = x2 > clip.right ? clip.right : x2;
    y2 = y2 > clip.bottom ? clip.bottom : y2;

    SDL_Surface* surf = SDL_GetWindowSurface(window);
    RenColor* d = cast(RenColor*) surf.pixels;
    d += x1 + y1 * surf.w;
    int dr = surf.w - (x2 - x1);

    auto rect_draw_loop(RenColor expr)
    {
        for (int j = y1; j < y2; j++)
        {
            for (int i = x1; i < x2; i++)
            {
                *d = expr;
                d++;
            }
            d += dr;
        }
    }

    if (color.a == 0xff)
    {
        rect_draw_loop(color);
    }
    else
    {
        rect_draw_loop(blend_pixel(*d, color));
    }
}

void ren_draw_image(RenImage* image, RenRect* sub, int x, int y, RenColor color)
{
    if (color.a == 0)
    {
        return;
    }

    /* clip */
    int n = void;
    if ((n = clip.left - x) > 0)
    {
        sub.width -= n;
        sub.x += n;
        x += n;
    }
    if ((n = clip.top - y) > 0)
    {
        sub.height -= n;
        sub.y += n;
        y += n;
    }
    if ((n = x + sub.width - clip.right) > 0)
    {
        sub.width -= n;
    }
    if ((n = y + sub.height - clip.bottom) > 0)
    {
        sub.height -= n;
    }

    if (sub.width <= 0 || sub.height <= 0)
    {
        return;
    }

    /* draw */
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
    RenRect rect = void;
    const(char)* p = text;
    uint codepoint = void;
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
        x += g.xadvance;
    }
    return x;
}
