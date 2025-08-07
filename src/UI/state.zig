const std = @import("std");
const Emoji = @import("../emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("../emoji/emojis.zig").Emojis;
const search = @import("../search/search.zig").search;
const SearchResult = @import("../search/search.zig").SearchResult;
const ztb = @import("ztb");

pub const KeyHandleResult = union(enum) {
    emoji: []const u8,
    finish_program,
    continue_processing,
};

pub const WindowFocused = enum {
    main,
    skin_tones,
};

pub const SkinToneType = enum {
    default_only, // no skin tone variation
    simple, // 1 default + 5 variations: light~dark
    combined, // 1 default + 5 * 5 variations: e.g, Handshake 🤝 has light & light x 1, light & others x 4, others & light x 4
};

pub const SkinToneState = struct {
    emoji: ?*const Emoji = null,
    cursor_idx: u8 = 0,

    cursor_max_idx: c_int = 0,
    top_result_idx: usize = 0,
    skin_tone_type: SkinToneType = .default_only,

    max_visible_result: u8 = 10,

    pub fn reset(self: *SkinToneState) void {
        self.emoji = null;
        self.cursor_idx = 0;
        self.cursor_max_idx = 0;
        self.top_result_idx = 0;
        self.skin_tone_type = .default_only;
    }
};

pub const State = struct {
    window_focused: WindowFocused,
    allocator: Allocator,
    emojis: *const Emojis,

    // Search Result
    cursor_idx: c_int,
    cursor_max_idx: c_int,
    top_result_idx: usize,
    results: []SearchResult,
    max_visible_result: u8,
    default_limit: u8,

    // input
    input_buf: std.ArrayList(u8),
    input_limit: u8,

    skin_tone: SkinToneState,

    pub fn init(emojis: *const Emojis, allocator: Allocator) !State {
        const input_buf = std.ArrayList(u8).init(allocator);

        return State{
            .window_focused = WindowFocused.main,
            .cursor_idx = 0,
            .cursor_max_idx = 0,
            .top_result_idx = 0,
            .results = &.{},
            .emojis = emojis,
            .input_buf = input_buf,
            .allocator = allocator,
            .max_visible_result = 10,
            .default_limit = 100,
            .input_limit = 30,
            .skin_tone = SkinToneState{ .emoji = null, .cursor_idx = 0 },
        };
    }

    pub fn deinit(self: *State) void {
        self.input_buf.deinit();
    }
};

pub fn handleKey(key: i32, state: *State) !KeyHandleResult {
    if (key == ztb.KEY_BACKSPACE or key == ztb.KEY_BACKSPACE2) {
        try handleDeleteKey(state);
    }

    if (isValidCharacter(key)) {
        try handleAlphabet(state, key);
    }

    // Move cursor
    if (key == ztb.KEY_ARROW_UP) {
        try handleArrowUp(state);
    } else if (key == ztb.KEY_ARROW_DOWN) {
        try handleArrowDown(state);
    }

    if (key == '?') {
        handleSkinTone(state);
    }

    // handle Enter
    if (key == ztb.KEY_ENTER) {
        if (getSelectedEmoji(state)) |emoji| {
            return KeyHandleResult{ .emoji = emoji.character };
        }
    }

    // handle Ctrl+C
    if (key == ztb.KEY_CTRL_C) {
        return KeyHandleResult.finish_program;
    }

    if (key == ztb.KEY_ESC) {
        switch (state.window_focused) {
            .main => {
                return KeyHandleResult.finish_program;
            },
            .skin_tones => {
                state.window_focused = .main;
                state.skin_tone.reset();
            },
        }
    }

    return KeyHandleResult.continue_processing;
}

fn handleDeleteKey(state: *State) !void {
    if (state.window_focused != .main) {
        return;
    }

    if (state.input_buf.items.len > 0) {
        _ = state.input_buf.pop();
    }

    try updateQuery(state);
}

fn handleAlphabet(state: *State, ch: i32) !void {
    if (state.window_focused != WindowFocused.main) {
        return;
    }

    if (state.input_buf.items.len < state.input_limit) {
        try state.input_buf.append(@as(u8, @intCast(ch)));
    }

    try updateQuery(state);
}

fn handleArrowUp(state: *State) !void {
    switch (state.window_focused) {
        .main => {
            // Move cursor up
            if (state.cursor_idx > 0) {
                state.cursor_idx -= 1;
            } else if (state.cursor_idx == 0 and state.top_result_idx > 0) {
                state.top_result_idx = state.top_result_idx - 1;
            }
        },
        .skin_tones => {
            if (state.skin_tone.cursor_idx > 0) {
                state.skin_tone.cursor_idx -= 1;
            } else if (state.skin_tone.cursor_idx == 0 and state.skin_tone.top_result_idx > 0) {
                state.skin_tone.top_result_idx = state.skin_tone.top_result_idx - 1;
            }
        },
    }
}

fn handleArrowDown(state: *State) !void {
    switch (state.window_focused) {
        .main => {
            if (state.results.len == 0 or state.cursor_idx >= state.results.len - 1) {
                return;
            }

            const bottom_idx = state.top_result_idx + @as(usize, @intCast(state.cursor_max_idx));
            if (state.cursor_idx == state.cursor_max_idx and state.results.len - 1 > bottom_idx) {
                // scroll the result
                state.top_result_idx += 1;
            } else if (state.cursor_idx < state.cursor_max_idx) {
                state.cursor_idx += 1;
            }
        },
        .skin_tones => {
            const skin_tone_num: usize = switch (state.skin_tone.skin_tone_type) {
                .default_only => 1,
                .simple => 5 + 1,
                .combined => 25 + 1,
            };

            if (state.skin_tone.cursor_idx >= skin_tone_num - 1) {
                return;
            }

            const bottom_idx = state.skin_tone.top_result_idx + @as(usize, @intCast(state.skin_tone.cursor_max_idx));
            if (state.skin_tone.cursor_idx == state.skin_tone.cursor_max_idx and skin_tone_num - 1 > bottom_idx) {
                // scroll the result
                state.skin_tone.top_result_idx += 1;
            } else if (state.skin_tone.cursor_idx < state.skin_tone.cursor_max_idx) {
                state.skin_tone.cursor_idx += 1;
            }
        },
    }
}

fn handleSkinTone(state: *State) void {
    state.skin_tone.emoji = getSelectedEmoji(state);

    if (state.skin_tone.emoji == null) {
        return;
    }

    switch (state.skin_tone.emoji.?.skin_tones[0].items.len) {
        0 => {
            state.skin_tone.skin_tone_type = SkinToneType.default_only;
            state.skin_tone.cursor_max_idx = 0;
        },
        1 => {
            state.skin_tone.skin_tone_type = .simple;
            state.skin_tone.cursor_max_idx = 5;
        },
        5 => {
            state.skin_tone.skin_tone_type = .combined;
            state.skin_tone.cursor_max_idx = state.skin_tone.max_visible_result;
        },
        else => @panic("invalid skin tone length detected"),
    }

    state.window_focused = WindowFocused.skin_tones;
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
