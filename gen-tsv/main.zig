const std = @import("std");
const print = std.debug.print;
const parser = @import("parser.zig");
const Allocator = std.mem.Allocator;

// The output of gen-tsv is input.tsv, which will be the input for Zeff. This is not typo.
const output_path = "./src/emoji/input.tsv";

const input_emoji_path = "./gen-tsv/data/emoji.txt";
const input_keywords_path = "./gen-tsv/data/keywords.tsv";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var emojiParser = parser.EmojiParser.init(allocator);
    defer emojiParser.deinit();

    try readEmojiFile(&emojiParser);

    try readKeywordsFile(&emojiParser);

    const result_file = try std.fs.cwd().openFile(output_path, std.fs.File.OpenFlags{ .mode = std.fs.File.OpenMode.write_only });

    var buf: [8192]u8 = undefined;

    var file_writer = result_file.writer(&buf);
    const writer = &file_writer.interface;

    // iterate emojiParser.map
    var iterator = emojiParser.map.iterator();
    while (iterator.next()) |entry| {
        const emoji = entry.value_ptr.*;
        try writer.print("{f}\n", .{emoji});
    }
}

fn readEmojiFile(emojiParser: *parser.EmojiParser) !void {
    const emoji_file = try std.fs.cwd().openFile(input_emoji_path, .{});

    var buffer: [2048]u8 = undefined;

    var file_reader = emoji_file.reader(&buffer);
    const reader = &file_reader.interface;

    while (reader.takeDelimiterExclusive('\n') catch null) |line| {
        try emojiParser.handleEmojiLine(line);
    }
}

fn readKeywordsFile(emojiParser: *parser.EmojiParser) !void {
    const keywords_file = try std.fs.cwd().openFile(input_keywords_path, .{});

    var buffer: [2048]u8 = undefined;
    var reader = keywords_file.reader(&buffer);

    const in_stream = &reader.interface;

    while (in_stream.takeDelimiterExclusive('\n') catch null) |line| {
        try emojiParser.handleKeywordsLine(line);
    }
}

test {
    std.testing.refAllDecls(@This());
}
