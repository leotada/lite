module stb_truetype;

extern (C) @nogc nothrow:

struct stbtt_fontinfo
{
    // opaque enough for us if we don't access fields directly
    void*[4] userdata;
    ubyte* data;
    int fontstart;
    int numGlyphs;
    int loca, head, glyf, hhea, hmtx, kern, gpos, svg;
    int index_map;
    int indexToLocFormat;
    // ... incomplete struct definition is risky if passed by value, but it is usually passed by pointer
    // However, the C code includes it directly in RenFont struct.
    // So we MUST match the size or use a pointer.
    // In src/renderer.c: stbtt_fontinfo stbfont; (by value)
    // So we need the FULL definition or a compatible blob.
    // For now I will use a byte blob large enough.
    ubyte[256] buffer;
}

struct stbtt_bakedchar
{
    ushort x0, y0, x1, y1;
    float xoff, yoff, xadvance;
}

int stbtt_InitFont(stbtt_fontinfo* info, const(ubyte)* data, int offset);
void stbtt_GetFontVMetrics(const(stbtt_fontinfo)* info, int* ascent, int* descent, int* lineGap);
float stbtt_ScaleForMappingEmToPixels(const(stbtt_fontinfo)* info, float pixels);
float stbtt_ScaleForPixelHeight(const(stbtt_fontinfo)* info, float pixels);
int stbtt_BakeFontBitmap(const(ubyte)* data, int offset, float pixel_height, ubyte* pixels, int pw, int ph, int first_char, int num_chars, stbtt_bakedchar* chardata);
