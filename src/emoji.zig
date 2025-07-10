const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Emoji = struct {
    character: []const u8,
    category: []const u8,
    subcategory: []const u8,
    name: []const u8,
    keywords: []const []const u8,
    skin_tones: []const []const u8,

    pub fn fromLine(line: []const u8, allocator: Allocator) !Emoji {
        var parts = std.mem.splitSequence(u8, line, "\t");

        const character = parts.next() orelse return error.InvalidFormat;
        const category = parts.next() orelse return error.InvalidFormat;
        const subcategory = parts.next() orelse return error.InvalidFormat;
        const name = parts.next() orelse return error.InvalidFormat;
        const keywords_str = parts.next() orelse return error.InvalidFormat;
        const skin_tones_str = parts.next() orelse "";

        var keywords_list = try splitStringToArrayList(keywords_str, ",", allocator);
        var skin_tones_list = try splitStringToArrayList(skin_tones_str, "\t", allocator);

        return Emoji{
            .character = character,
            .category = category,
            .subcategory = subcategory,
            .name = name,
            .keywords = try keywords_list.toOwnedSlice(),
            .skin_tones = try skin_tones_list.toOwnedSlice(),
        };
    }

    pub fn deinit(self: Emoji, allocator: Allocator) void {
        allocator.free(self.keywords);
        allocator.free(self.skin_tones);
    }
};

fn splitStringToArrayList(str: []const u8, delimiter: []const u8, allocator: Allocator) !ArrayList([]const u8)
{
    var parts = std.mem.splitSequence(u8, str, delimiter);

    var list = ArrayList([]const u8).init(allocator);

    while (parts.next()) |part| {
        if (part.len == 0) continue; // Skip empty parts
        try list.append(part);
    }

    return list;
}

test "splitStringToArrayList" {
    const allocator = std.testing.allocator;

    const input = "apple,banana,cherry";
    const expected = [_][]const u8{ "apple", "banana", "cherry" };

    const result = try splitStringToArrayList(input, ",", allocator);
    defer result.deinit();

    for (0..result.items.len) |i| {
        try std.testing.expectEqualSlices(u8, expected[i], result.items[i]);
    }
}

test "emoji fromLine" {
    const allocator = std.testing.allocator;
    const input = "😀\tSmileys & Emotion\tface-smiling\tgrinning face\tgrin,smile,happy";

    const emoji = try Emoji.fromLine(input, allocator);

    defer emoji.deinit(allocator);

    try std.testing.expectEqualSlices(u8, "😀", emoji.character);
    try std.testing.expectEqualSlices(u8, "Smileys & Emotion", emoji.category);
    try std.testing.expectEqualSlices(u8, "face-smiling", emoji.subcategory);
    try std.testing.expectEqualSlices(u8, "grinning face", emoji.name);

    const expected_keywords = [_][]const u8{ "grin", "smile", "happy" };

    try std.testing.expectEqual(expected_keywords.len, emoji.keywords.len);
    for (0..emoji.keywords.len) |i| {
        try std.testing.expectEqualSlices(u8, expected_keywords[i], emoji.keywords[i]);
    }

    try std.testing.expectEqual(0, emoji.skin_tones.len);
}
