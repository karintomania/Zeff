const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Emoji = struct {
    character: []const u8,
    category: []const u8,
    subcategory: []const u8,
    name: []const u8,
    keywords: []const []const u8,
    skin_tones: [5]ArrayList([]const u8),

    pub fn fromLine(line: []const u8, allocator: Allocator) !Emoji {
        var parts = std.mem.splitSequence(u8, line, "\t");

        const character = try allocator.dupe(u8, parts.next() orelse return error.InvalidFormat);
        const category = try allocator.dupe(u8, parts.next() orelse return error.InvalidFormat);
        const subcategory = try allocator.dupe(u8, parts.next() orelse return error.InvalidFormat);
        const name = try allocator.dupe(u8, parts.next() orelse return error.InvalidFormat);
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

    pub fn format(value: Emoji, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}\t{s}\t{s}\t{s}\t", .{
            value.character,
            value.group,
            value.subgroup,
            value.desc,
        });

        // Display keywords
        for (value.keywords, 0..) |keyword, i| {
            if (i > 0) try writer.print(",", .{});

            try writer.print("{s}", .{keyword});
        }

        try writer.print("\t", .{});

        // Display skintones
        for (value.skin_tones) |skin_tone_list| {
            if (skin_tone_list.items.len > 0) {
                for (skin_tone_list.items, 0..) |skin_emoji, j| {
                    if (j > 0) try writer.print(",", .{});
                    try writer.print("{s}",.{skin_emoji});
                }
                try writer.print("\t", .{});
            }
        }
    }

    pub fn deinit(self: Emoji, allocator: Allocator) void {
        allocator.free(self.character);
        allocator.free(self.category);
        allocator.free(self.subcategory);
        allocator.free(self.name);

        for (self.keywords) |keyword| {
            allocator.free(keyword);
        }

        for (self.skin_tones) |skin_tone| {
            allocator.free(skin_tone);
        }
        allocator.free(self.keywords);
        allocator.free(self.skin_tones);
    }
};


fn splitStringToArrayList(str: []const u8, delimiter: []const u8, allocator: Allocator) !ArrayList([]const u8) {
    var parts = std.mem.splitSequence(u8, str, delimiter);

    var list = ArrayList([]const u8).init(allocator);

    while (parts.next()) |part| {
        if (part.len == 0) continue; // Skip empty parts

        const allocated_part = try allocator.dupe(u8, part);
        try list.append(allocated_part);
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

        defer allocator.free(result.items[i]);
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

test "Emoji format function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var keywords = [_][]const u8{ "happy", "smile" };

    const emoji = Emoji{
        .character = "😀",
        .category = "Smileys & Emotion",
        .subcategory = "face-smiling",
        .name = "grinning face",
        .keywords = &keywords,
        .skin_tones = [5]ArrayList([]const u8){
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
        },
    };

    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    try std.fmt.format(buffer.writer(), "{}", .{emoji});

    const expected = "😀\tSmileys & Emotion\tface-smiling\tgrinning face\thappy,smile\t";
    try std.testing.expectEqualStrings(expected, buffer.items);
}
