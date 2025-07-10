const std = @import("std");
const Emoji = @import("emoji.zig").Emoji;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const input = try std.fs.cwd().openFile("input.tsv", .{});
    defer input.close();

    var buf_reader = std.io.bufferedReader(input.reader());
    var in_stream = buf_reader.reader();

    var buf: [2048]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const emoji = Emoji.fromLine(line, allocator);

        std.debug.print("Emoji: {any}", .{emoji});
    }
}

