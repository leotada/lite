module rencache;

import renderer;
import core.stdc.string : memset, memcpy, strlen;
import core.stdc.stdio : fprintf, stderr;
import core.stdc.stdlib : rand;

extern (C) @nogc nothrow:

// Constants
enum CELLS_X = 80;
enum CELLS_Y = 50;
enum CELL_SIZE = 96;
enum COMMAND_BUF_SIZE = 1024 * 512;

enum CommandType
{
    FREE_FONT,
    SET_CLIP,
    DRAW_TEXT,
    DRAW_RECT
}

struct Command
{
    CommandType type;
    int size;
    RenRect rect;
    RenColor color;
    RenFont* font;
    int tab_width;
    // char text[0]; // Flexible array simulated by pointer math
}

// Global state
private __gshared uint[CELLS_X * CELLS_Y] cells_buf1;
private __gshared uint[CELLS_X * CELLS_Y] cells_buf2;
private __gshared uint* cells_prev;
private __gshared uint* cells;
private __gshared RenRect[CELLS_X * CELLS_Y / 2] rect_buf;
private __gshared ubyte[COMMAND_BUF_SIZE] command_buf;
private __gshared int command_buf_idx;
private __gshared RenRect screen_rect;
private __gshared bool show_debug;
private __gshared bool initialized_ptrs;

// Init pointers (since D static arrays are values, we need pointers to them)
private void init_ptrs()
{
    if (!initialized_ptrs)
    {
        cells_prev = cells_buf1.ptr;
        cells = cells_buf2.ptr;
        initialized_ptrs = true;
    }
}

// Utils
private int min(int a, int b)
{
    return a < b ? a : b;
}

private int max(int a, int b)
{
    return a > b ? a : b;
}

// FNV-1a hash
enum HASH_INITIAL = 2166136261u;

private void hash(uint* h, const(void)* data, int size)
{
    const(ubyte)* p = cast(const(ubyte)*) data;
    while (size--)
    {
        *h = (*h ^ *p++) * 16777619;
    }
}

private int cell_idx(int x, int y)
{
    return x + y * CELLS_X;
}

private bool rects_overlap(RenRect a, RenRect b)
{
    return b.x + b.width >= a.x && b.x <= a.x + a.width
        && b.y + b.height >= a.y && b.y <= a.y + a.height;
}

private RenRect intersect_rects(RenRect a, RenRect b)
{
    int x1 = max(a.x, b.x);
    int y1 = max(a.y, b.y);
    int x2 = min(a.x + a.width, b.x + b.width);
    int y2 = min(a.y + a.height, b.y + b.height);
    return RenRect(x1, y1, max(0, x2 - x1), max(0, y2 - y1));
}

private RenRect merge_rects(RenRect a, RenRect b)
{
    int x1 = min(a.x, b.x);
    int y1 = min(a.y, b.y);
    int x2 = max(a.x + a.width, b.x + b.width);
    int y2 = max(a.y + a.height, b.y + b.height);
    return RenRect(x1, y1, x2 - x1, y2 - y1);
}

private Command* push_command(CommandType type, int size)
{
    int n = command_buf_idx + size;
    if (n > COMMAND_BUF_SIZE)
    {
        fprintf(stderr, "Warning: exhausted command buffer\n");
        return null;
    }
    Command* cmd = cast(Command*)(command_buf.ptr + command_buf_idx);
    command_buf_idx = n;
    memset(cmd, 0, size); // Clear memory
    cmd.type = type;
    cmd.size = size;
    return cmd;
}

private bool next_command(Command** prev)
{
    if (*prev == null)
    {
        *prev = cast(Command*) command_buf.ptr;
    }
    else
    {
        *prev = cast(Command*)(cast(char*)*prev + (*prev).size);
    }
    // Check if we reached the end
    return *prev != cast(Command*)(command_buf.ptr + command_buf_idx);
}

void rencache_show_debug(bool enable)
{
    show_debug = enable;
}

void rencache_free_font(RenFont* font)
{
    Command* cmd = push_command(CommandType.FREE_FONT, Command.sizeof);
    if (cmd)
    {
        cmd.font = font;
    }
}

void rencache_set_clip_rect(RenRect rect)
{
    Command* cmd = push_command(CommandType.SET_CLIP, Command.sizeof);
    if (cmd)
    {
        cmd.rect = intersect_rects(rect, screen_rect);
    }
}

void rencache_draw_rect(RenRect rect, RenColor color)
{
    if (!rects_overlap(screen_rect, rect))
        return;
    Command* cmd = push_command(CommandType.DRAW_RECT, Command.sizeof);
    if (cmd)
    {
        cmd.rect = rect;
        cmd.color = color;
    }
}

int rencache_draw_text(RenFont* font, const(char)* text, int x, int y, RenColor color)
{
    RenRect rect;
    rect.x = x;
    rect.y = y;
    rect.width = ren_get_font_width(font, text);
    rect.height = ren_get_font_height(font);

    if (rects_overlap(screen_rect, rect))
    {
        size_t len = strlen(text) + 1;
        int sz = cast(int)(Command.sizeof + len);
        // Align to 4 bytes if necessary, but C didn't, so we should be careful.
        // Command struct is likely aligned.

        Command* cmd = push_command(CommandType.DRAW_TEXT, sz);
        if (cmd)
        {
            // Copy text to after the struct
            char* dest = cast(char*)(cmd + 1); // Pointer arithmetic moves one Command struct forward
            memcpy(dest, text, len);

            cmd.color = color;
            cmd.font = font;
            cmd.rect = rect;
            cmd.tab_width = ren_get_font_tab_width(font);
        }
    }
    return x + rect.width;
}

void rencache_invalidate()
{
    init_ptrs();
    memset(cells_prev, 0xff, cells_buf1.length * uint.sizeof);
}

void rencache_begin_frame()
{
    init_ptrs();
    int w, h;
    ren_get_size(&w, &h);
    if (screen_rect.width != w || h != screen_rect.height)
    {
        screen_rect.width = w;
        screen_rect.height = h;
        rencache_invalidate();
    }
}

private void update_overlapping_cells(RenRect r, uint h)
{
    int x1 = r.x / CELL_SIZE;
    int y1 = r.y / CELL_SIZE;
    int x2 = (r.x + r.width) / CELL_SIZE;
    int y2 = (r.y + r.height) / CELL_SIZE;

    for (int y = y1; y <= y2; y++)
    {
        for (int x = x1; x <= x2; x++)
        {
            int idx = cell_idx(x, y);
            hash(&cells[idx], &h, h.sizeof);
        }
    }
}

private void push_rect(RenRect r, int* count)
{
    // Try to merge
    for (int i = *count - 1; i >= 0; i--)
    {
        RenRect* rp = &rect_buf[i];
        if (rects_overlap(*rp, r))
        {
            *rp = merge_rects(*rp, r);
            return;
        }
    }
    rect_buf[(*count)++] = r;
}

void rencache_end_frame()
{
    init_ptrs();

    // Update cells from commands
    Command* cmd = null;
    RenRect cr = screen_rect;
    while (next_command(&cmd))
    {
        if (cmd.type == CommandType.SET_CLIP)
        {
            cr = cmd.rect;
        }
        RenRect r = intersect_rects(cmd.rect, cr);
        if (r.width == 0 || r.height == 0)
            continue;
        uint h = HASH_INITIAL;
        hash(&h, cmd, cmd.size);
        update_overlapping_cells(r, h);
    }

    // Push rects from changed cells
    int rect_count = 0;
    int max_x = screen_rect.width / CELL_SIZE + 1;
    int max_y = screen_rect.height / CELL_SIZE + 1;
    for (int y = 0; y < max_y; y++)
    {
        for (int x = 0; x < max_x; x++)
        {
            int idx = cell_idx(x, y);
            if (cells[idx] != cells_prev[idx])
            {
                push_rect(RenRect(x, y, 1, 1), &rect_count);
            }
            cells_prev[idx] = HASH_INITIAL;
        }
    }

    // Expand rects
    for (int i = 0; i < rect_count; i++)
    {
        RenRect* r = &rect_buf[i];
        r.x *= CELL_SIZE;
        r.y *= CELL_SIZE;
        r.width *= CELL_SIZE;
        r.height *= CELL_SIZE;
        *r = intersect_rects(*r, screen_rect);
    }

    // Redraw
    bool has_free_commands = false;
    for (int i = 0; i < rect_count; i++)
    {
        RenRect r = rect_buf[i];
        ren_set_clip_rect(r);

        cmd = null;
        while (next_command(&cmd))
        {
            switch (cmd.type)
            {
            case CommandType.FREE_FONT:
                has_free_commands = true;
                break;
            case CommandType.SET_CLIP:
                ren_set_clip_rect(intersect_rects(cmd.rect, r));
                break;
            case CommandType.DRAW_RECT:
                ren_draw_rect(cmd.rect, cmd.color);
                break;
            case CommandType.DRAW_TEXT:
                ren_set_font_tab_width(cmd.font, cmd.tab_width);
                char* text = cast(char*)(cmd + 1);
                ren_draw_text(cmd.font, text, cmd.rect.x, cmd.rect.y, cmd.color);
                break;
            default:
                break;
            }
        }

        if (show_debug)
        {
            RenColor color = RenColor(
                cast(ubyte) rand(), cast(ubyte) rand(), cast(ubyte) rand(), 50
            );
            ren_draw_rect(r, color);
        }
    }

    // Update dirty rects
    if (rect_count > 0)
    {
        ren_update_rects(rect_buf.ptr, rect_count);
    }

    // Free fonts
    if (has_free_commands)
    {
        cmd = null;
        while (next_command(&cmd))
        {
            if (cmd.type == CommandType.FREE_FONT)
            {
                rencache_free_font(cmd.font);
            }
        }
    }

    // Swap buffers
    uint* tmp = cells;
    cells = cells_prev;
    cells_prev = tmp;
    command_buf_idx = 0;
}
