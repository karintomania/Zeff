const std = @import("std");
const Emoji = @import("../emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("../emoji/emojis.zig").Emojis;
const search = @import("../search/search.zig").search;
const SearchResult = @import("../search/search.zig").SearchResult;
const State = @import("state.zig").State;
const handleKey = @import("state.zig").handleKey;

const c = @cImport({
    @cInclude("stdwrap.c");
    @cInclude("locale.h");
    @cInclude("ncurses.h");
});

const result_row_offset = 1;

const input_row_offset = 1;
const input_prefix: []const u8 = " > ";
const input_prefix_len: c_int = @as(c_int, @intCast(input_prefix.len));

const cursor_symbol: []const u8 = "> ";

const color_cyan: c_short = 1;
const color_blue: c_short = 2;
const color_green: c_short = 3;

const winResult = struct {
    win: *c.WINDOW,

    pub fn init(state: *State) winResult {
        const win = c.newwin(state.max_visible_result + 3, 60, 6, 0).?;

        return winResult{
            .win = win,
        };
    }

    pub fn draw(self: *winResult, state: *State, allocator: Allocator) !void {
        defer _ = c.wrefresh(self.win);

        _ = c.wclear(self.win);

        // print result number
        _ = c.wattron(self.win, c.COLOR_PAIR(color_green));
        _ = c.mvwprintw(self.win, 0, 0, "Result: %d", state.results.len);
        _ = c.wattroff(self.win, c.COLOR_PAIR(color_green));

        // print result
        for (state.results, 0..) |result, result_idx| {
            if (result_idx < state.top_result_idx) {
                continue; // Skip self.results before the top idx
            }

            // i is the position in result list
            const i = result_idx - state.top_result_idx;

            const result_str = try std.fmt.allocPrintZ(allocator, "{s}\t{s}", .{ result.emoji.character, result.label });

            _ = c.mvwprintw(self.win, @as(c_int, @intCast(i)) + result_row_offset, 2, result_str);
            if (i == state.cursor_idx) {
                // print selection cursor
                _ = c.mvwprintw(self.win, @as(c_int, @intCast(i)) + result_row_offset, 0, cursor_symbol.ptr);

                // make the line bold and green
                _ = c.mvwchgat(self.win, @as(c_int, @intCast(i)) + result_row_offset, 1, -1, c.A_BOLD, color_blue, null);
            }

            allocator.free(result_str);

            if (i >= state.max_visible_result - 1 or i >= state.results.len - 1) {
                break; // Limit to visible state.results
            }
        }
    }
};

const winInput = struct {
    win: *c.WINDOW,

    pub fn init() winInput {
        const win = c.newwin(3, 40, 1, 0).?;
        _ = c.keypad(win, true);

        return winInput{
            .win = win,
        };
    }

    pub fn draw(self: *winInput, state: *State) void {
        _ = c.wclear(self.win);

        _ = c.wattron(self.win, c.COLOR_PAIR(color_cyan));
        _ = c.box(self.win, 0, 0);

        _ = c.mvwprintw(self.win, 0, input_row_offset + 1, "Type keywords 🔍 ");

        _ = c.mvwprintw(self.win, 1, input_row_offset, input_prefix.ptr);

        _ = c.wattroff(self.win, c.COLOR_PAIR(color_cyan));

        // print input_buf
        if (state.input_buf.items.len > 0) {
            _ = c.mvwprintw(
                self.win,
                1,
                input_row_offset + input_prefix_len,
                "%.*s",
                @as(c_int, @intCast(state.input_buf.items.len)),
                state.input_buf.items.ptr,
            );
        }

        // move input cursor to next letter
        const input_cursor_pos: c_int = input_row_offset + @as(c_int, @intCast(state.input_buf.items.len)) + input_prefix_len;

        _ = c.wmove(self.win, 1, input_cursor_pos);

        _ = c.wrefresh(self.win);
    }

    pub fn readCh(self: *winInput) c_int {
        const ch: c_int = c.wgetch(self.win);
        return ch;
    }

    pub fn deinit(self: *winInput) void {
        _ = self;
    }
};

fn drawWinInstruction() void {
    const win_instruction = c.newwin(1, 50, 4, 0);

    _ = c.wprintw(win_instruction, "<↑↓> Move <Enter> Select emoji <Ctrl+C> quit");

    _ = c.wrefresh(win_instruction);
}

fn initColors() void {
    _ = c.init_pair(color_cyan, c.COLOR_CYAN, -1);
    _ = c.init_pair(color_blue, c.COLOR_BLUE, -1);
    _ = c.init_pair(color_green, c.COLOR_GREEN, -1);
}

pub fn startUI(emojis: *const Emojis, allocator: Allocator) !?*const Emoji {
    // Set locale for UTF-8 support
    _ = c.setlocale(c.LC_ALL, "");

    // use newterm instead of initscr(). This enables linux pipe like $ zeff | x-copy
    _ = c.newterm(null, c.getstderr(), c.getstdin());

    defer _ = c.endwin();

    _ = c.noecho();
    _ = c.cbreak();

    _ = c.start_color();
    _ = c.use_default_colors();

    initColors();

    drawWinInstruction();

    var state = try State.init(emojis, allocator);
    defer state.deinit();

    var win_result = winResult.init(&state);

    var win_input = winInput.init();
    defer win_input.deinit();

    while (true) {
        // Draw
        try win_result.draw(&state, allocator);
        win_input.draw(&state);

        // Read and Process Ch
        const ch: c_int = win_input.readCh();

        const emoji = try handleKey(ch, &state);

        if (emoji != null) {
            return emoji;
        }
    }
}
