const std = @import("std");
const Emoji = @import("../emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("../emoji/emojis.zig").Emojis;
const search = @import("../search/search.zig").search;
const SearchResult = @import("../search/search.zig").SearchResult;
const ztb = @import("ztb");

pub const KeyHandleResult = union(enum) {
    emoji: *const Emoji,
    finish_program,
    continue_processing,
};

pub const State = struct {
    cursor_idx: c_int,
    cursor_max_idx: c_int,
    top_result_idx: usize,
    results: []SearchResult,
    emojis: *const Emojis,
    input_buf: std.ArrayList(u8),

    max_visible_result: u8,
    input_limit: u8,
    default_limit: u8,

    allocator: Allocator,

    pub fn init(emojis: *const Emojis, allocator: Allocator) !State {
        const input_buf = std.ArrayList(u8).init(allocator);

        return State{
            .cursor_idx = 0,
            .cursor_max_idx = 0,
            .top_result_idx = 0,
            .results = &.{},
            .max_visible_result = 10,
            .input_limit = 30,
            .default_limit = 100,
            .emojis = emojis,
            .input_buf = input_buf,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *State) void {
        self.input_buf.deinit();
    }
};

pub fn handleKey(key: i32, state: *State) !KeyHandleResult {
    if (key == ztb.KEY_BACKSPACE or key == ztb.KEY_BACKSPACE2) {
        try handleDeleteKey(state);
    } else if (isValidCharacter(key)) {
        try handleAlphabet(state, key);
    }

    // Move cursor
    if (key == ztb.KEY_ARROW_UP) {
        try handleArrowUp(state);
    } else if (key == ztb.KEY_ARROW_DOWN) {
        try handleArrowDown(state);
    }

    // handle Enter
    if (key == ztb.KEY_ENTER) {
        if (getSelectedEmoji(state)) |emoji| {
            return KeyHandleResult{ .emoji = emoji };
        }
    }

    // handle Ctrl+C
    if (key == ztb.KEY_CTRL_C) {
        return KeyHandleResult.finish_program;
    }

    return KeyHandleResult.continue_processing;
}

fn handleDeleteKey(state: *State) !void {
    if (state.input_buf.items.len > 0) {
        _ = state.input_buf.pop();
    }

    try updateQuery(state);
}

fn handleAlphabet(state: *State, ch: i32) !void {
    if (state.input_buf.items.len < state.input_limit) {
        try state.input_buf.append(@as(u8, @intCast(ch)));
    }

    try updateQuery(state);
}

fn handleArrowUp(state: *State) !void {
    // Move cursor up
    if (state.cursor_idx > 0) {
        state.cursor_idx -= 1;
    } else if (state.cursor_idx == 0 and state.top_result_idx > 0) {
        state.top_result_idx = state.top_result_idx - 1;
    }
}

fn handleArrowDown(state: *State) !void {
    if (state.results.len == 0 or state.cursor_idx >= state.results.len - 1) {
        return;
    }

    if (state.cursor_idx == state.cursor_max_idx and state.results.len - 1 > (state.top_result_idx + @as(usize, @intCast(state.cursor_idx)))) {
        // scroll the result
        state.top_result_idx += 1;
    } else if (state.cursor_idx < state.cursor_max_idx) {
        state.cursor_idx += 1;
    }
}

fn getSelectedEmoji(state: *State) ?*const Emoji {
    if (state.results.len == 0) {
        return null; // No results found
    }

    const selected_index = @as(usize, @intCast(state.cursor_idx)) + state.top_result_idx;

    const selected_emoji = state.results[selected_index].emoji;

    return selected_emoji;
}

fn updateQuery(state: *State) !void {
    state.allocator.free(state.results);

    const query = state.input_buf.items;

    // reset the top_result_idx with query update
    state.top_result_idx = 0;

    if (query.len > 0) {
        state.results = try search(query, state.default_limit, state.emojis.emojis, state.allocator);
    } else {
        // TODO: show history if the query is empty
        state.cursor_idx = 0;
        state.cursor_max_idx = 0;
        state.results = &.{};
    }

    if (state.results.len > 0) {
        state.cursor_max_idx = @min(@as(c_int, @intCast(state.results.len - 1)), state.max_visible_result - 1);

        state.cursor_idx = @min(state.cursor_idx, state.cursor_max_idx);
    } else {
        state.cursor_max_idx = 0;
        state.cursor_idx = 0;
    }
}

fn isValidCharacter(ch: i32) bool {
    return (ch >= '0' and ch <= '9') or (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == ' ';
}
