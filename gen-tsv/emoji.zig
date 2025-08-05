const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const OriginEmoji = @import("emoji").Emoji;

pub const Emoji = struct {
    emoji: []const u8,
    group: []const u8,
    subgroup: []const u8,
    desc: []const u8,
    keywords: [][]const u8,
    skin_tones: [5]ArrayList([]const u8),

    pub fn format(value: Emoji, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}\t{s}\t{s}\t{s}\t", .{
            value.emoji,
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
};

test "test origin" {
    const origin_emoji = OriginEmoji{
        .character = "🦓",
        .category = "animal",
        .subcategory = "animal",
        .name = "zebra",
        .keywords = &.{},
        .skin_tones = &.{},
    };

    try testing.expectEqualStrings("🦓a", origin_emoji.character);
}

test "Emoji format function" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var keywords = [_][]const u8{ "happy", "smile" };

    const emoji = Emoji{
        .emoji = "😀",
        .group = "Smileys & Emotion",
        .subgroup = "face-smiling",
        .desc = "grinning face",
        .keywords = &keywords,
        .skin_tones = [5]ArrayList([]const u8){
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
        },
    };

    var buffer = std.ArrayList(u8).init(testing.allocator);
    defer buffer.deinit();

    try std.fmt.format(buffer.writer(), "{}", .{emoji});

    const expected = "😀\tSmileys & Emotion\tface-smiling\tgrinning face\thappy,smile\t";
    try testing.expectEqualStrings(expected, buffer.items);
}
