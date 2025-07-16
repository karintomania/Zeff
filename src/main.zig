const std = @import("std");
const Emoji = @import("emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("emojis.zig").Emojis;
const search = @import("search.zig").search;
const SearchResult = @import("search.zig").SearchResult;

const c = @cImport({
    @cInclude("locale.h");
    @cInclude("ncurses.h");
});

const default_limit = 20;

const input_row: c_int = 2;
const input_col: c_int = 5;
const input_prefix: []const u8 = "🔍:";
const input_prefix_len: c_int = @as(c_int, @intCast(input_prefix.len));

const hit_number_row: c_int = 3;
const hit_number_col: c_int = input_col;

const result_row: c_int = hit_number_row + 2;
const result_col: c_int = input_col + input_prefix_len;

const cursor_symbol: []const u8 = ">";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const emojis = Emojis.init(allocator) catch |err| {
        std.debug.print("Error initializing Emojis: {}\n", .{err});
        return err;
    };

    defer emojis.deinit();

    const selected_emoji = try startUI(emojis, allocator);

    if (selected_emoji != null) {
        const stdow = std.io.getStdOut().writer();
        try stdow.print("{s}", .{selected_emoji.?.character});
    }
}

fn startUI(emojis: Emojis, allocator: Allocator) !?Emoji {
    // Set locale for UTF-8 support
    _ = c.setlocale(c.LC_ALL, "");

    // use newterm instead of initscr(). This enables linux pipe like $ zeff | x-copy
    _ = c.newterm(null, c.stderr, c.stdin);

    defer _ = c.endwin();

    _ = c.noecho();
    _ = c.cbreak();
    _ = c.keypad(c.stdscr, true);
    // Disable cursor visibility
    // _ = c.curs_set(0);

    // buffer for user input
    var input_buf = std.ArrayList(u8).init(allocator);
    defer input_buf.deinit();

    var cursor_row: c_int = result_row;

    var cursor_max_row: c_int = result_row; // the cursor goes result_row + result.len
    //
    var results: []SearchResult = &.{};

    while (true) {
        // Clear the screen
        _ = c.clear();

        _ = c.mvprintw(input_row - 2, input_col, "Type keywords. (Enter: Select | Ctrl+C: quit)");
        _ = c.mvprintw(input_row, input_col, "🔍:");

        if (input_buf.items.len > 0) {
            _ = c.mvprintw(input_row, input_col + input_prefix_len, "%.*s", @as(c_int, @intCast(input_buf.items.len)), input_buf.items.ptr);

            _ = c.mvprintw(cursor_row, result_col - 2, cursor_symbol.ptr);

            results = try search(input_buf.items, default_limit, emojis.emojis, allocator);

            cursor_max_row = result_row + @as(c_int, @intCast(results.len)) - 1;

            var i: c_int = 0;
            for (results) |result| {
                const result_str = try std.fmt.allocPrintZ(allocator, "{s}\t{s}", .{result.emoji.character, result.label});
                _ = c.mvprintw(result_row + i, result_col, result_str);
                allocator.free(result_str);
                i += 1;
            }

            // allocator.free(results);
        } else {
            cursor_row = result_row;
            cursor_max_row = result_row;

            results = &.{};

        }
        _ = c.mvprintw(hit_number_row, hit_number_col + input_prefix_len, "Found: %d", results.len);

        _ = c.move(input_row, input_col + @as(c_int, @intCast(input_buf.items.len)) + input_prefix_len);

        _ = c.refresh();

        const ch: c_int = c.getch();

        if (ch == c.KEY_BACKSPACE or ch == 127 or ch == 8) {
            // Handle backspace, delete
            if (input_buf.items.len > 0) {
                _ = input_buf.pop();
            }
        } else if (isValidCharacter(ch)) {
            try input_buf.append(@as(u8, @intCast(ch)));
        }

        if (ch == c.KEY_UP) {
            // Move cursor up
            if (cursor_row > result_row) {
                cursor_row -= 1;
            }
        } else if (ch == c.KEY_DOWN) {
            // Move cursor down
            if (cursor_row < cursor_max_row) {
                cursor_row += 1;
            }
        } else if (ch == 10 or ch == 13) {
            break;
        }
    }

    if (results.len == 0) {
        return null; // No results found
    }

    const selected_index = @as(usize, @intCast(cursor_row - result_row));
    const selected_emoji = results[selected_index].emoji;

    return selected_emoji;

}

fn isValidCharacter(ch: c_int) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == ' ';
}
