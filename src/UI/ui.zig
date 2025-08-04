const std = @import("std");
const Emoji = @import("../emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("../emoji/emojis.zig").Emojis;
const search = @import("../search/search.zig").search;
const SearchResult = @import("../search/search.zig").SearchResult;
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
    width: i32,
    height: i32,

    pub fn init(state: *State) winResult {
        return winResult{
            .x = 0,
            .y = 6,
            .width = 60,
            .height = state.max_visible_result + 3,
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
                try ztb.print(self.x + 2, y_pos, ztb.BLUE | ztb.BOLD, ztb.DEFAULT, result.emoji.character);
                try ztb.print(self.x + 9, y_pos, ztb.BLUE | ztb.BOLD, ztb.DEFAULT, result.label);
            } else {
                try ztb.print(self.x + 2, y_pos, ztb.DEFAULT, ztb.DEFAULT, result.emoji.character);
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
    width: i32,
    height: i32,

    pub fn init() winInput {
        return winInput{
            .x = 0,
            .y = 1,
            .width = 40,
            .height = 3,
        };
    }

    pub fn draw(self: *winInput, state: *State) !void {
        try self.drawBox();

        // Print title
        try ztb.print(self.x + input_row_offset + 1, self.y, ztb.CYAN, ztb.DEFAULT, "Type keywords 🔍 ");

        // Print input prefix
        try ztb.print(self.x + input_row_offset, self.y + 1, ztb.DEFAULT, ztb.DEFAULT, input_prefix);

        // Print input buffer
        if (state.input_buf.items.len > 0) {
            try ztb.print(
                self.x + input_row_offset + input_prefix_len,
                self.y + 1,
                ztb.DEFAULT,
                ztb.DEFAULT,
                state.input_buf.items
            );
        }

        // Set cursor position
        const cursor_x = self.x + input_row_offset + @as(i32, @intCast(state.input_buf.items.len)) + input_prefix_len;
        try ztb.setCursor(cursor_x, self.y + 1);
    }

    fn drawBox(self: *winInput) !void {
        // Draw box border with cyan color using Unicode box drawing characters
        for (0..@as(usize, @intCast(self.width))) |x| {
            try ztb.setCell(self.x + @as(i32, @intCast(x)), self.y, '─', ztb.CYAN, ztb.DEFAULT);
            try ztb.setCell(self.x + @as(i32, @intCast(x)), self.y + self.height - 1, '─', ztb.CYAN, ztb.DEFAULT);
        }
        for (0..@as(usize, @intCast(self.height))) |y| {
            try ztb.setCell(self.x, self.y + @as(i32, @intCast(y)), '│', ztb.CYAN, ztb.DEFAULT);
            try ztb.setCell(self.x + self.width - 1, self.y + @as(i32, @intCast(y)), '│', ztb.CYAN, ztb.DEFAULT);
        }
        // Box corners
        try ztb.setCell(self.x, self.y, '┌', ztb.CYAN, ztb.DEFAULT);
        try ztb.setCell(self.x + self.width - 1, self.y, '┐', ztb.CYAN, ztb.DEFAULT);
        try ztb.setCell(self.x, self.y + self.height - 1, '└', ztb.CYAN, ztb.DEFAULT);
        try ztb.setCell(self.x + self.width - 1, self.y + self.height - 1, '┘', ztb.CYAN, ztb.DEFAULT);
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
    try ztb.print(0, 4, ztb.DEFAULT, ztb.DEFAULT, "<↑↓> Move <Enter> Select emoji <Ctrl+C> quit");
}


pub fn startUI(emojis: *const Emojis, allocator: Allocator) !?*const Emoji {
    try ztb.init();
    defer ztb.shutdown();

    try drawWinInstruction();

    var state = try State.init(emojis, allocator);
    defer state.deinit();

    var win_result = winResult.init(&state);
    var win_input = winInput.init();
    defer win_input.deinit();

    while (true) {
        // Clear screen
        try ztb.clear();

        // Draw
        try win_result.draw(&state);
        try win_input.draw(&state);
        try drawWinInstruction();

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
