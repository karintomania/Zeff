const std = @import("std");
const Emoji = @import("emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const input_str = @embedFile("input.tsv");

pub const Emojis = struct {
    emojis: []Emoji,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) !Emojis {
        var arena =  std.heap.ArenaAllocator.init(allocator);

        const emojis = try getEmojiSlice(arena.allocator());

        return Emojis{
            .emojis = emojis,
            .arena = arena,
        };
    }

    pub fn deinit(self: Emojis) void {
        self.arena.deinit();
    }
};

fn getEmojiSlice(allocator: Allocator) ![]Emoji {
    var lines = std.mem.splitSequence(u8, input_str, "\n");
    var emojis_list = std.ArrayList(Emoji).init(allocator);

    while (lines.next()) |line| {
        if (line.len == 0) continue; // Skip empty lines

        const emoji = try Emoji.fromLine(line, allocator);
        try emojis_list.append(emoji);
    }

    return emojis_list.toOwnedSlice();
}

test "getEmojiSlice" {
    const emojis = try getEmojiSlice(std.testing.allocator);
    defer std.testing.allocator.free(emojis);

    const emoji1 = emojis[0];

    try std.testing.expectEqualSlices(u8, "😀", emoji1.character);

    // deinit
    for (emojis) |emoji| {
        emoji.deinit(std.testing.allocator);
    }
}
