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

const input_prefix: []const u8 = " >";
const input_prefix_len: c_int = @as(c_int, @intCast(input_prefix.len));

const cursor_symbol: []const u8 = ">";

const winResult = struct {
    win: *c.WINDOW,
    cursor_idx: c_int,
    cursor_max_idx: c_int,
    top_result_idx: usize,
    results: []SearchResult,
    emojis: *const Emojis,

    pub fn init(emojis: *const Emojis) winResult {
        const win = c.newwin(visible_result + 3, 50, 6, 0).?;

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
        _ = c.wclear(self.win);

        self.results = try search(query, default_limit, self.emojis.emojis, allocator);

        if (self.results.len > 0) {
            self.cursor_max_idx = @min(@as(c_int, @intCast(self.results.len - 1)), visible_result - 1);
            self.cursor_idx = @min(self.cursor_idx, self.cursor_max_idx);
            _ = c.mvwprintw(self.win, self.cursor_idx + result_row_offset, 1, cursor_symbol.ptr);
            self.top_result_idx = @min(self.results.len - 1, self.top_result_idx);
        } else {
            self.cursor_max_idx = 0;
            self.cursor_idx = 0;
        }

        for (self.results, 0..) |result, result_idx| {
            if (result_idx < self.top_result_idx) {
                continue; // Skip self.results above the top idx
            }

            // i is the position in result list
            const i = result_idx - self.top_result_idx;

            const result_str = try std.fmt.allocPrintZ(allocator, "{s}\t{s}", .{ result.emoji.character, result.label });

            _ = c.mvwprintw(self.win, @as(c_int, @intCast(i)) + result_row_offset, 2, result_str);
            allocator.free(result_str);

            if (i >= visible_result - 1 or i >= self.results.len - 1) {
                break; // Limit to visible self.results
            }
        }

        _ = c.mvwprintw(self.win, 0, 0, "Result: %d", self.results.len);

        _ = c.wrefresh(self.win);
    }

    pub fn noInput(self: *winResult) void {
        self.cursor_idx = 0;
        self.cursor_max_idx = 0;
        self.results = &.{};
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
            if (self.cursor_idx == self.cursor_max_idx) {
                self.top_result_idx += 1;
            }

            if (self.cursor_idx < self.cursor_max_idx) {
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

    pub fn update(self: *winInput) void {
        _ = c.wclear(self.win);

        _ = c.box(self.win, 0, 0);

        _ = c.mvwprintw(self.win, 0, 2, "Type keywords 🔍 ");
        _ = c.mvwprintw(self.win, 1, 2, ">");

        std.debug.print("length {d}", .{self.input_buf.items.len});
        if (self.input_buf.items.len > 0) {
            _ = c.mvwprintw(
                self.win, 1, 4,
                "%.*s",
                @as(c_int, @intCast(self.input_buf.items.len)), self.input_buf.items.ptr,
            );
            _ = c.wmove(self.win, 1, 2 + @as(c_int, @intCast(self.input_buf.items.len)) + input_prefix_len);
        }

        _ = c.wrefresh(self.win);
    }

    pub fn readCh(self: *winInput) c_int {
        const ch: c_int = c.wgetch(self.win);
        return ch;
    }

    pub fn addCh(self: *winInput, ch: c_int) !void {
        try self.input_buf.append(@as(u8, @intCast(ch)));
    }

    pub fn deleteCh(self: *winInput) void {
            // Handle backspace, delete
            if (self.input_buf.items.len > 0) {
                _ = self.input_buf.pop();
            }
    }


    pub fn deinit(self: *winInput) void {
        self.input_buf.deinit();
    }
};

pub fn startUI(emojis: *const Emojis, allocator: Allocator) !?*const Emoji {
    // Set locale for UTF-8 support
    _ = c.setlocale(c.LC_ALL, "");

    // use newterm instead of initscr(). This enables linux pipe like $ zeff | x-copy
    _ = c.newterm(null, c.stderr, c.stdin);

    defer _ = c.endwin();

    _ = c.noecho();
    _ = c.cbreak();

    var has_query_changed = false;

    const win_instruction = c.newwin(1, 50, 4, 0);
    _ = c.wprintw(win_instruction, "<↑↓> Move <Enter> Select emoji <Ctrl+C> quit");
    _ = c.wrefresh(win_instruction);

    var win_result = winResult.init(emojis);

    var input_buf = std.ArrayList(u8).init(allocator);
    var win_input = winInput.init(&input_buf);
    defer win_input.deinit();

    while (true) {


        if (win_input.input_buf.items.len > 0) {
            try win_result.updateQuery(win_input.input_buf.items, allocator);
        } else {
            win_result.noInput();
        }

        win_input.update();

        const ch: c_int = win_input.readCh();

        if (ch == c.KEY_BACKSPACE or ch == 127 or ch == 8) {
            has_query_changed = true;
            win_input.deleteCh();

            continue;
        } else if (isValidCharacter(ch)) {
            has_query_changed = true;

            try win_input.addCh(ch);

            continue;
        }

        if (ch == c.KEY_UP) {
            // Move cursor up
            win_result.moveCursorUp();
        } else if (ch == c.KEY_DOWN) {
            win_result.moveCursorDown();
        } else if (ch == 10 or ch == 13) {
            break;
        }

        has_query_changed = false;
    }

    const selected_emoji = win_result.getSelectedEmoji();

    return selected_emoji;
}

fn isValidCharacter(ch: c_int) bool {
    return (ch >= '0' and ch <= '9') or (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == ' ';
}
