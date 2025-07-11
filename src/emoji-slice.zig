const std = @import("std");
const Emoji = @import("emoji.zig").Emoji;
const Allocator = std.mem.Allocator;

pub const Emojis = struct {
    emojis: []Emoji,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator, input_file_path: []const u8) !Emojis {
        var arena =  std.heap.ArenaAllocator.init(allocator);

        const emojis = try getEmojiSlice(input_file_path, arena.allocator());

        return Emojis{
            .emojis = emojis,
            .arena = arena,
        };
    }

    pub fn deinit(self: Emojis) void {
        self.arena.deinit();
    }

};

fn getEmojiSlice(input_file_path: []const u8, allocator: Allocator) ![]Emoji {
    const input = try std.fs.cwd().openFile(input_file_path, .{});
    defer input.close();

    var buf_reader = std.io.bufferedReader(input.reader());
    var in_stream = buf_reader.reader();

    var buf: [2048]u8 = undefined;

    var emojis_list = std.ArrayList(Emoji).init(allocator);

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const emoji = try Emoji.fromLine(line, allocator);
        try emojis_list.append(emoji);
    }

    return emojis_list.toOwnedSlice();
}


