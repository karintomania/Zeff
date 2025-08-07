const std = @import("std");
const Emoji = @import("../emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("../emoji/emojis.zig").Emojis;
const search = @import("../search/search.zig").search;
const SearchResult = @import("../search/search.zig").SearchResult;
const StateModule = @import("state.zig");
const State = @import("state.zig").State;
const handleKey = @import("state.zig").handleKey;
const KeyHandleResult = @import("state.zig").KeyHandleResult;
const ztb = @import("ztb");

const result_row_offset = 1;

const input_row_offset = 1;
const input_prefix: []const u8 = " > ";
const input_prefix_len: c_int = @as(c_int, @intCast(input_prefix.len));

const cursor_symbol: []const u8 = "> ";

const winResult = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn init(state: *State) winResult {
        return winResult{
            .x = 0,
            .y = 7,
            .w = 60,
            .h = state.max_visible_result + 3,
        };
    }

    pub fn draw(self: *winResult, state: *State) !void {
        // print result number
        try ztb.printf(self.x, self.y, ztb.GREEN, ztb.DEFAULT, "Result: {d}", .{state.results.len});

        // print result
        for (state.results, 0..) |result, result_idx| {
            if (result_idx < state.top_result_idx) {
                continue; // Skip self.results before the top idx
            }

            // i is the position in result list
            const i = result_idx - state.top_result_idx;

            const y_pos = self.y + @as(i32, @intCast(i)) + result_row_offset;

            if (i == state.cursor_idx) {
                // print selection cursor
                try ztb.print(self.x, y_pos, ztb.DEFAULT, ztb.DEFAULT, cursor_symbol);
                // print the result with bold and blue
                try printEmoji(self.x + 2, y_pos, ztb.DEFAULT, ztb.DEFAULT, result.emoji.character);
                try ztb.print(self.x + 8, y_pos, ztb.BLUE | ztb.REVERSE | ztb.BOLD, ztb.DEFAULT, result.label);
            } else {
                try printEmoji(self.x + 2, y_pos, ztb.DEFAULT, ztb.DEFAULT, result.emoji.character);
                try ztb.print(self.x + 8, y_pos, ztb.DEFAULT, ztb.DEFAULT, result.label);
            }

            if (i >= state.max_visible_result - 1 or i >= state.results.len - 1) {
                break; // Limit to visible state.results
            }
        }
    }
};

const winInput = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn init() winInput {
        return winInput{
            .x = 0,
            .y = 1,
            .w = 40,
            .h = 3,
        };
    }

    pub fn draw(self: *winInput, state: *State) !void {
        try drawBox(self.x, self.y, self.w, self.h, ztb.CYAN, ztb.DEFAULT);

        // Print title
        try ztb.print(self.x + input_row_offset + 1, self.y, ztb.CYAN, ztb.DEFAULT, "Type keywords 🔍");

        // Print input prefix
        try ztb.print(self.x + input_row_offset, self.y + 1, ztb.DEFAULT, ztb.DEFAULT, input_prefix);

        // Print input buffer
        if (state.input_buf.items.len > 0) {
            try ztb.print(self.x + input_row_offset + input_prefix_len, self.y + 1, ztb.DEFAULT, ztb.DEFAULT, state.input_buf.items);
        }

        // Set cursor position
        const cursor_x = self.x + input_row_offset + @as(i32, @intCast(state.input_buf.items.len)) + input_prefix_len;
        try ztb.setCursor(cursor_x, self.y + 1);
    }

    pub fn readCh(self: *winInput) !ztb.Event {
        _ = self;
        var event = ztb.newEvent();
        try ztb.pollEvent(&event);
        return event;
    }

    pub fn deinit(self: *winInput) void {
        _ = self;
    }
};

fn drawWinInstruction() !void {
    try ztb.print(0, 4, ztb.DEFAULT, ztb.DEFAULT, "<↑↓> Move <Ctrl+C> quit");
    try ztb.print(0, 5, ztb.DEFAULT, ztb.DEFAULT, "<Enter> Select emoji <?> Select Skin Tone");
}

const winSkinTone = struct {
    x: i32,
    y: i32,
    w: i32,

    pub fn init() winSkinTone {
        return winSkinTone{
            .x = 20,
            .y = 8,
            .w = 20,
        };
    }

    pub fn draw(self: *winSkinTone, state: *State) !void {
        if (state.window_focused == StateModule.WindowFocused.skin_tones and state.skin_tone.emoji != null) {
            const default_h: i32 = switch (state.skin_tone.skin_tone_type) {
                .default_only => 3,
                .simple => 8,
                .combined => 14,
            };

            const h = @min(state.skin_tone.max_visible_result + 4, default_h);

            try drawBox(self.x, self.y, self.w, h, ztb.BLUE | ztb.BOLD, ztb.DEFAULT);

            try ztb.print(self.x + 2, self.y + h - 1, ztb.DEFAULT, ztb.DEFAULT, "<Enter> / <ESC>");

            const emoji = state.skin_tone.emoji.?;

            const x = self.x + 2;
            var y = self.y + 1;
            var idx: u8 = 0;

            // print default

            if (state.skin_tone.top_result_idx == 0) {
                const fg: u64 = if (state.skin_tone.cursor_idx == idx) ztb.DEFAULT | ztb.REVERSE else ztb.DEFAULT;
                try printEmoji(x, y, ztb.DEFAULT, ztb.DEFAULT, emoji.character);
                try ztb.print(x + 8, y, fg, ztb.DEFAULT, "default");
                y += 1;
            }

            idx += 1;

            for (emoji.skin_tones, 0..) |skin_tone, i| {
                for (skin_tone.items, 0..) |em, j| {
                    if (idx >= state.skin_tone.top_result_idx and idx <= state.skin_tone.top_result_idx + state.skin_tone.max_visible_result) {
                        const current_idx = state.skin_tone.cursor_idx + state.skin_tone.top_result_idx;

                        const fg: u64 = if (current_idx == idx) ztb.DEFAULT | ztb.REVERSE else ztb.DEFAULT;
                        // print skin tone 0
                        try printEmoji(x, y, ztb.DEFAULT, ztb.DEFAULT, em);

                        if (state.skin_tone.skin_tone_type == .simple) {
                            try ztb.printf(x + 8, y, fg, ztb.DEFAULT, "  ({d})  ", .{i + 1});
                        } else if (state.skin_tone.skin_tone_type == .combined) {
                            try ztb.printf(x + 8, y, fg, ztb.DEFAULT, "  ({d},{d}) ", .{ i + 1, j + 1 });
                        }

                        y += 1;
                    }
                    idx += 1;
                }
            }
        }
    }
};

pub fn startUI(emojis: *const Emojis, allocator: Allocator) !?[]const u8 {
    try ztb.init();
    defer ztb.shutdown();

    try drawWinInstruction();

    var state = try State.init(emojis, allocator);
    defer state.deinit();

    var win_result = winResult.init(&state);
    var win_input = winInput.init();
    var win_skin_tone = winSkinTone.init();
    defer win_input.deinit();

    while (true) {
        // Clear screen
        try ztb.clear();

        // Draw
        try win_result.draw(&state);
        try win_input.draw(&state);
        try drawWinInstruction();
        try win_skin_tone.draw(&state);

        // Present changes to screen
        try ztb.present();

        // Read and Process Event
        const event = try win_input.readCh();

        // Extract key from ztb event for handleKey function
        var key: i32 = 0;
        if (event.type == ztb.EVENT_KEY) {
            if (event.key != 0) {
                key = @as(i32, @intCast(event.key));
            } else if (event.ch != 0) {
                key = @as(i32, @intCast(event.ch));
            }
        }

        const result = try handleKey(key, &state);

        switch (result) {
            .emoji => |emoji| return emoji,
            .finish_program => return null,
            .continue_processing => {},
        }
    }
}

fn drawBox(x: i32, y: i32, w: i32, h: i32, fg: u64, bg: u64) !void {
    const width = @as(usize, @intCast(w));
    const height = @as(usize, @intCast(h));
    // Draw box border with cyan color using Unicode box drawing characters
    for (0..width) |x_idx| {
        try ztb.setCell(x + @as(i32, @intCast(x_idx)), y, '─', fg, bg);
        try ztb.setCell(x + @as(i32, @intCast(x_idx)), y + h - 1, '─', fg, bg);
    }
    for (0..height) |y_idx| {
        try ztb.setCell(x, y + @as(i32, @intCast(y_idx)), '│', fg, bg);
        try ztb.setCell(x + w - 1, y + @as(i32, @intCast(y_idx)), '│', fg, bg);
    }
    // Box corners
    try ztb.setCell(x, y, '┌', fg, bg);
    try ztb.setCell(x + w - 1, y, '┐', fg, bg);
    try ztb.setCell(x, y + h - 1, '└', fg, bg);
    try ztb.setCell(x + w - 1, y + h - 1, '┘', fg, bg);

    // remove old contents by writing space
    // ztb.clear does this, but it doesn't work with pop up window
    for (1..height - 1) |y_idx| {
        for (1..width - 1) |x_idx| {
            try ztb.setCell(x + @as(i32, @intCast(x_idx)), y + @as(i32, @intCast(y_idx)), ' ', fg, bg);
        }
    }
}

// Combined emojis use multiple cell with ztb.print()
// This funcgion forces all emoji to fit in one cell
fn printEmoji(x: i32, y: i32, fg: u64, bg: u64, emoji: []const u8) !void {
    var buf: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);

    var utf32_sequence = std.ArrayList(u32).init(fba.allocator());

    var i: usize = 0;
    while (i < emoji.len) {
        const r = try ztb.utf8CharToUnicode(emoji[i..emoji.len]);
        try utf32_sequence.append(r.unicode);
        i += @as(usize, @intCast(r.length));
    }

    try ztb.setCell(x, y, utf32_sequence.items[0], fg, bg);

    i = 1;
    while (i < utf32_sequence.items.len) {
        try ztb.extendCell(x, y, utf32_sequence.items[i]);
        i += 1;
    }
}
