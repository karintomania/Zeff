const std = @import("std");
const Emoji = @import("../emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("../emoji/emojis.zig").Emojis;
const search = @import("../search/search.zig").search;
const SearchResult = @import("../search/search.zig").SearchResult;

const c = @cImport({
    @cInclude("locale.h");
    @cInclude("ncurses.h");
});

const result_row_offset = 1;
const visible_result = 10;
const default_limit = 100;

const input_row_offset = 1;
const input_limit = 30;
const input_prefix: []const u8 = " > ";
const input_prefix_len: c_int = @as(c_int, @intCast(input_prefix.len));

const cursor_symbol: []const u8 = "> ";

const color_cyan: c_short = 1;
const color_blue: c_short = 2;
const color_green: c_short = 3;

const winResult = struct {
    win: *c.WINDOW,
    cursor_idx: c_int,
    cursor_max_idx: c_int,
    top_result_idx: usize,
    results: []SearchResult,
    emojis: *const Emojis,

    pub fn init(emojis: *const Emojis) winResult {
        const win = c.newwin(visible_result + 3, 60, 6, 0).?;

        return winResult{
            .win = win,
            .cursor_idx = 0,
            .cursor_max_idx = 0,
            .top_result_idx = 0,
            .emojis = emojis,
            .results = &.{},
        };
    }

    pub fn updateQuery(self: *winResult, query: []const u8, allocator: Allocator) !void {
        allocator.free(self.results);

        // reset the top_result_idx with query update
        self.top_result_idx = 0;

        if (query.len > 0) {
            self.results = try search(query, default_limit, self.emojis.emojis, allocator);
        } else {
            // TODO: show history if the query is empty
            self.cursor_idx = 0;
            self.cursor_max_idx = 0;
            self.results = &.{};
        }

        if (self.results.len > 0) {
            self.cursor_max_idx = @min(@as(c_int, @intCast(self.results.len - 1)), visible_result - 1);

            self.cursor_idx = @min(self.cursor_idx, self.cursor_max_idx);
        } else {
            self.cursor_max_idx = 0;
            self.cursor_idx = 0;
        }
    }

    pub fn draw(self: *winResult, allocator: Allocator) !void {
        _ = c.wclear(self.win);

        // print result number
        _ = c.wattron(self.win, c.COLOR_PAIR(color_green));
        _ = c.mvwprintw(self.win, 0, 0, "Result: %d", self.results.len);
        _ = c.wattroff(self.win, c.COLOR_PAIR(color_green));

        // print result
        for (self.results, 0..) |result, result_idx| {
            if (result_idx < self.top_result_idx) {
                continue; // Skip self.results before the top idx
            }

            // i is the position in result list
            const i = result_idx - self.top_result_idx;


            const result_str = try std.fmt.allocPrintZ(allocator, "{s}\t{s}", .{ result.emoji.character, result.label });

            _ = c.mvwprintw(self.win, @as(c_int, @intCast(i)) + result_row_offset, 2, result_str);
            if (i == self.cursor_idx) {
                // print selection cursor
                _ = c.mvwprintw(self.win, @as(c_int, @intCast(i)) + result_row_offset, 0, cursor_symbol.ptr);

                // make the line bold and green
                _ = c.mvwchgat(self.win, @as(c_int, @intCast(i)) + result_row_offset, 1, -1, c.A_BOLD, color_blue, null);
            }

            allocator.free(result_str);

            if (i >= visible_result - 1 or i >= self.results.len - 1) {
                break; // Limit to visible self.results
            }
        }


        _ = c.wrefresh(self.win);
    }

    pub fn moveCursorUp(self: *winResult) void {
        // Move cursor up
        if (self.cursor_idx > 0) {
            self.cursor_idx -= 1;
        } else if (self.cursor_idx == 0 and self.top_result_idx > 0) {
            self.top_result_idx = self.top_result_idx - 1;
        }
    }

    pub fn moveCursorDown(self: *winResult) void {
        if (self.results.len == 0 or self.cursor_idx >= self.results.len - 1) {
            return;
        }

        if (self.cursor_idx == self.cursor_max_idx and self.results.len - 1 > (self.top_result_idx + @as(usize, @intCast(self.cursor_idx)))) {
            // scroll the resslt
            self.top_result_idx += 1;
        } else if (self.cursor_idx < self.cursor_max_idx) {
            self.cursor_idx += 1;
        }
    }

    pub fn getSelectedEmoji(self: *winResult) ?*const Emoji {
        if (self.results.len == 0) {
            return null; // No results found
        }

        const selected_index = @as(usize, @intCast(self.cursor_idx)) + self.top_result_idx;

        const selected_emoji = self.results[selected_index].emoji;

        return selected_emoji;
    }
};

const winInput = struct {
    win: *c.WINDOW,
    input_buf: *std.ArrayList(u8),

    pub fn init(input_buf: *std.ArrayList(u8)) winInput {
        const win = c.newwin(3, 40, 1, 0).?;
        _ = c.keypad(win, true);

        return winInput{
            .win = win,
            .input_buf = input_buf,
        };
    }

    pub fn draw(self: *winInput) void {
        _ = c.wclear(self.win);

        _ = c.wattron(self.win, c.COLOR_PAIR(color_cyan));
        _ = c.box(self.win, 0, 0);

        _ = c.mvwprintw(self.win, 0, input_row_offset + 1, "Type keywords 🔍 ");

        _ = c.mvwprintw(self.win, 1, input_row_offset, input_prefix.ptr);

        _ = c.wattroff(self.win, c.COLOR_PAIR(color_cyan));

        // print input_buf
        if (self.input_buf.items.len > 0) {
            _ = c.mvwprintw(
                self.win,
                1,
                input_row_offset + input_prefix_len,
                "%.*s",
                @as(c_int, @intCast(self.input_buf.items.len)),
                self.input_buf.items.ptr,
            );
        }

        // move input cursor to next letter
        const input_cursor_pos: c_int = input_row_offset + @as(c_int, @intCast(self.input_buf.items.len)) + input_prefix_len;

        _ = c.wmove(self.win, 1, input_cursor_pos);

        _ = c.wrefresh(self.win);
    }

    pub fn readCh(self: *winInput) c_int {
        const ch: c_int = c.wgetch(self.win);
        return ch;
    }

    pub fn appendInputBuf(self: *winInput, ch: c_int) !void {
        if (self.input_buf.items.len < input_limit) {
            try self.input_buf.append(@as(u8, @intCast(ch)));
        }
    }

    pub fn deleteLastInputBuf(self: *winInput) void {
        // Handle backspace, delete
        if (self.input_buf.items.len > 0) {
            _ = self.input_buf.pop();
        }
    }

    pub fn deinit(self: *winInput) void {
        self.input_buf.deinit();
    }
};

fn drawWinInstruction() void {
    const win_instruction = c.newwin(1, 50, 4, 0);

    _ = c.wprintw(win_instruction, "<↑↓> Move <Enter> Select emoji <Ctrl+C> quit");

    _ = c.wrefresh(win_instruction);

}

pub fn startUI(emojis: *const Emojis, allocator: Allocator) !?*const Emoji {
    // Set locale for UTF-8 support
    _ = c.setlocale(c.LC_ALL, "");

    // use newterm instead of initscr(). This enables linux pipe like $ zeff | x-copy
    _ = c.newterm(null, c.stderr(), c.stdin());

    defer _ = c.endwin();

    _ = c.noecho();
    _ = c.cbreak();

    _ = c.start_color();
    _ = c.use_default_colors();

    initColors();

    drawWinInstruction();

    var win_result = winResult.init(emojis);

    var input_buf = std.ArrayList(u8).init(allocator);
    var win_input = winInput.init(&input_buf);
    defer win_input.deinit();

    while (true) {
        // Draw
        try win_result.draw(allocator);
        win_input.draw();

        // Read and Process Ch
        const ch: c_int = win_input.readCh();

        if (ch == c.KEY_BACKSPACE or ch == 127 or ch == 8) {
            win_input.deleteLastInputBuf();

            try win_result.updateQuery(win_input.input_buf.items, allocator);
        } else if (isValidCharacter(ch)) {
            try win_input.appendInputBuf(ch);

            try win_result.updateQuery(win_input.input_buf.items, allocator);
        }

        // Move cursor
        if (ch == c.KEY_UP) {
            win_result.moveCursorUp();
        } else if (ch == c.KEY_DOWN) {
            win_result.moveCursorDown();
        }

        // handle Enter
        if (ch == 10 or ch == 13) {
            break;
        }
    }

    const selected_emoji = win_result.getSelectedEmoji();

    return selected_emoji;
}

fn initColors() void {
    _ = c.init_pair(color_cyan, c.COLOR_CYAN, -1);
    _ = c.init_pair(color_blue, c.COLOR_BLUE, -1);
    _ = c.init_pair(color_green, c.COLOR_GREEN, -1);
}

fn isValidCharacter(ch: c_int) bool {
    return (ch >= '0' and ch <= '9') or (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == ' ';
}
