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

pub fn startUI(emojis: *const Emojis, allocator: Allocator) !?*const Emoji {
    // Set locale for UTF-8 support
    _ = c.setlocale(c.LC_ALL, "");

    // use newterm instead of initscr(). This enables linux pipe like $ zeff | x-copy
    _ = c.newterm(null, c.stderr, c.stdin);

    defer _ = c.endwin();

    _ = c.noecho();
    _ = c.cbreak();

    // buffer for user input
    var input_buf = std.ArrayList(u8).init(allocator);
    defer input_buf.deinit();

    var cursor_index: c_int = 0;
    var cursor_max_index: c_int = 0; // the cursor goes result_row + result.len
    var top_result_index: u16 = 0; // The index of the top visible result
    var has_query_changed = false;

    var results: []SearchResult = &.{};

    const win_input = c.newwin(3, 40, 1, 0);
    _ = c.keypad(win_input, true);

    const win_instruction = c.newwin(1, 50, 4, 0);
    _ = c.wprintw(win_instruction, "<↑↓> Move <Enter> Select emoji <Ctrl+C> quit");
    _ = c.wrefresh(win_instruction);

    const win_result = c.newwin(visible_result + 3, 50, 6, 0);

    while (true) {
        _ = c.wclear(win_input);
        _ = c.wclear(win_result);

        _ = c.box(win_input, 0, 0);

        _ = c.mvwprintw(win_input, 0, 2, "Type keywords 🔍 ");
        _ = c.mvwprintw(win_input, 1, 2, ">");

        if (input_buf.items.len > 0) {
            _ = c.mvwprintw(win_input, 1, 4, "%.*s", @as(c_int, @intCast(input_buf.items.len)), input_buf.items.ptr);

            // TODO: When scrolling, no need to run search again
            if (has_query_changed) {
                results = try search(input_buf.items, default_limit, emojis.emojis, allocator);
            }

            if (results.len > 0) {
                cursor_max_index = @min(@as(c_int, @intCast(results.len - 1)), visible_result - 1);
                cursor_index = @min(cursor_index, cursor_max_index);
                _ = c.mvwprintw(win_result, cursor_index + result_row_offset, 1, cursor_symbol.ptr);
                top_result_index = @min(results.len - 1, top_result_index);
            } else {
                cursor_max_index = 0;
                cursor_index = 0;
            }

            for (results, 0..) |result, result_idx| {
                if (result_idx < top_result_index) {
                    continue; // Skip results above the top index
                }

                // i is the position in result list
                const i = result_idx - top_result_index;

                const result_str = try std.fmt.allocPrintZ(allocator, "{s}\t{s}", .{ result.emoji.character, result.label });

                _ = c.mvwprintw(win_result, @as(c_int, @intCast(i)) + result_row_offset, 2, result_str);
                allocator.free(result_str);

                if (i >= visible_result - 1 or i >= results.len - 1) {
                    break; // Limit to visible results
                }
            }
        } else {
            cursor_index = 0;
            cursor_max_index = 0;

            results = &.{};
        }
        _ = c.mvwprintw(win_result, 0, 0, "Result: %d", results.len);

        _ = c.wrefresh(win_input);
        _ = c.wrefresh(win_result);

        _ = c.wmove(win_input, 1, 2 + @as(c_int, @intCast(input_buf.items.len)) + input_prefix_len);

        const ch: c_int = c.wgetch(win_input);

        if (ch == c.KEY_BACKSPACE or ch == 127 or ch == 8) {
            has_query_changed = true;
            // Handle backspace, delete
            if (input_buf.items.len > 0) {
                _ = input_buf.pop();
            }

            allocator.free(results);
            continue;
        } else if (isValidCharacter(ch)) {
            has_query_changed = true;

            try input_buf.append(@as(u8, @intCast(ch)));

            allocator.free(results);
            continue;
        }

        if (ch == c.KEY_UP) {
            // Move cursor up
            if (cursor_index > 0) {
                cursor_index -= 1;
            } else if (cursor_index == 0 and top_result_index > 0) {
                top_result_index = top_result_index - 1;
            }
        } else if (ch == c.KEY_DOWN) {
            if (cursor_index == cursor_max_index and (cursor_index + top_result_index) < (results.len - 1)) {
                top_result_index += 1;
            }

            if (cursor_index < cursor_max_index) {
                cursor_index += 1;
            }
        } else if (ch == 10 or ch == 13) {
            break;
        }

        has_query_changed = false;
    }

    if (results.len == 0) {
        return null; // No results found
    }

    const selected_index = @as(usize, @intCast(cursor_index)) + top_result_index;
    const selected_emoji = results[selected_index].emoji;

    return selected_emoji;
}

fn isValidCharacter(ch: c_int) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == ' ';
}
