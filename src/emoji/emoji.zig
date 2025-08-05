const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Emoji = struct {
    character: []const u8,
    group: []const u8,
    subgroup: []const u8,
    name: []const u8,
    keywords: []const []const u8,
    skin_tones: [5]ArrayList([]const u8),

    pub fn fromLine(line: []const u8, allocator: Allocator) !Emoji {
        var parts = std.mem.splitSequence(u8, line, "\t");

        const character = parts.next() orelse return error.InvalidFormat;
        const category = parts.next() orelse return error.InvalidFormat;
        const subcategory = parts.next() orelse return error.InvalidFormat;
        const name = parts.next() orelse return error.InvalidFormat;
        const keywords_str = parts.next() orelse return error.InvalidFormat;

        const keywords = try splitStringToSlice(keywords_str, ",", allocator);
        defer allocator.free(keywords);

        var skin_tones_lists = [_][]const []const u8{undefined} ** 5;

        for (0..5) |i| {
            const skin_tones_str = parts.next() orelse "";
            skin_tones_lists[i] = try splitStringToSlice(skin_tones_str, ",", allocator);
        }

        defer {
            for (skin_tones_lists) |skin_tones_list| {
                allocator.free(skin_tones_list);
            }
        }

        return try init(character, category, subcategory, name, keywords, skin_tones_lists, allocator);
    }

    pub fn init(
        character: []const u8,
        category: []const u8,
        subcategory: []const u8,
        name: []const u8,
        keywords: []const []const u8,
        skin_tones_lists: [5][]const []const u8,
        allocator: Allocator,
    ) !Emoji {
        const allocated_character = try allocator.dupe(u8, character);
        const allocated_category = try allocator.dupe(u8, category);
        const allocated_subcategory = try allocator.dupe(u8, subcategory);
        const allocated_name = try allocator.dupe(u8, name);

        // Allocate keywords array and duplicate each keyword
        const allocated_keywords = try allocator.alloc([]const u8, keywords.len);
        for (keywords, 0..) |keyword, i| {
            allocated_keywords[i] = try allocator.dupe(u8, keyword);
        }

        // Initialize skin tones arrays
        var skin_tones = [_]ArrayList([]const u8){undefined} ** 5;
        for (0..5) |i| {
            skin_tones[i] = ArrayList([]const u8).init(allocator);
            for (skin_tones_lists[i]) |skin_tone| {
                const allocated_skin_tone = try allocator.dupe(u8, skin_tone);
                try skin_tones[i].append(allocated_skin_tone);
            }
        }

        return Emoji{
            .character = allocated_character,
            .group = allocated_category,
            .subgroup = allocated_subcategory,
            .name = allocated_name,
            .keywords = allocated_keywords,
            .skin_tones = skin_tones,
        };
    }

    pub fn format(value: Emoji, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}\t{s}\t{s}\t{s}\t", .{
            value.character,
            value.group,
            value.subgroup,
            value.name,
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
        allocator.free(self.group);
        allocator.free(self.subgroup);
        allocator.free(self.name);

        for (self.keywords) |keyword| {
            allocator.free(keyword);
        }

        for (self.skin_tones) |skin_tone| {
            for (skin_tone.items) |skin_tone_emoji| {
                allocator.free(skin_tone_emoji);
            }
            skin_tone.deinit();
        }

        allocator.free(self.keywords);
    }
};


fn splitStringToSlice(str: []const u8, delimiter: []const u8, allocator: Allocator) ![]const []const u8 {
    var parts = std.mem.splitSequence(u8, str, delimiter);

    var list = ArrayList([]const u8).init(allocator);
    defer list.deinit();

    while (parts.next()) |part| {
        if (part.len == 0) continue; // Skip empty parts
        try list.append(part);
    }

    return list.toOwnedSlice();
}

test "splitStringToArrayList" {
    const allocator = std.testing.allocator;

    const input = "apple,banana,cherry";
    const expected = [_][]const u8{ "apple", "banana", "cherry" };

    const result = try splitStringToSlice(input, ",", allocator);
    defer allocator.free(result);

    for (0..result.len) |i| {
        try std.testing.expectEqualSlices(u8, expected[i], result[i]);
    }
}

test "emoji fromLine" {
    const allocator = std.testing.allocator;
    const input = "😀\tSmileys & Emotion\tface-smiling\tgrinning face\tgrin,smile,happy";

    const emoji = try Emoji.fromLine(input, allocator);

    defer emoji.deinit(allocator);

    try std.testing.expectEqualSlices(u8, "😀", emoji.character);
    try std.testing.expectEqualSlices(u8, "Smileys & Emotion", emoji.group);
    try std.testing.expectEqualSlices(u8, "face-smiling", emoji.subgroup);
    try std.testing.expectEqualSlices(u8, "grinning face", emoji.name);

    const expected_keywords = [_][]const u8{ "grin", "smile", "happy" };

    try std.testing.expectEqual(expected_keywords.len, emoji.keywords.len);
    for (0..emoji.keywords.len) |i| {
        try std.testing.expectEqualSlices(u8, expected_keywords[i], emoji.keywords[i]);
    }

    try std.testing.expectEqual(5, emoji.skin_tones.len);
}

test "emoji skin tones" {
    const allocator = std.testing.allocator;
    const input = "🧑\tPeople & Body\tperson\tperson\tperson,human,individual,anyone,someone\t🧑🏻\t🧑🏼\t🧑🏽\t🧑🏾\t🧑🏿\t";

    const emoji = try Emoji.fromLine(input, allocator);

    defer emoji.deinit(allocator);

    try std.testing.expectEqualSlices(u8, "🧑", emoji.character);
    try std.testing.expectEqualSlices(u8, "People & Body", emoji.group);
    try std.testing.expectEqualSlices(u8, "person", emoji.subgroup);
    try std.testing.expectEqualSlices(u8, "person", emoji.name);

    const expected_keywords = [_][]const u8{ "person", "human", "individual", "anyone", "someone" };

    try std.testing.expectEqual(expected_keywords.len, emoji.keywords.len);
    for (0..emoji.keywords.len) |i| {
        try std.testing.expectEqualSlices(u8, expected_keywords[i], emoji.keywords[i]);
    }

    const expected_skin_tones = [_][]const u8{"🧑🏻", "🧑🏼", "🧑🏽", "🧑🏾", "🧑🏿"};

    try std.testing.expectEqual(5, emoji.skin_tones.len);
    for (0..5) |i| {
        try std.testing.expectEqualStrings(expected_skin_tones[i], emoji.skin_tones[i].items[0]);
    }
}

test "Emoji init function" {
    const allocator = std.testing.allocator;
    
    const keywords = [_][]const u8{ "grin", "smile", "happy" };
    const skin_tones_lists = [_][]const []const u8{
        &[_][]const u8{"🧑🏻"},
        &[_][]const u8{"🧑🏼"},
        &[_][]const u8{"🧑🏽"},
        &[_][]const u8{"🧑🏾"},
        &[_][]const u8{"🧑🏿"},
    };

    const emoji = try Emoji.init(
        "😀",
        "Smileys & Emotion",
        "face-smiling",
        "grinning face",
        &keywords,
        skin_tones_lists,
        allocator,
    );
    defer emoji.deinit(allocator);

    try std.testing.expectEqualSlices(u8, "😀", emoji.character);
    try std.testing.expectEqualSlices(u8, "Smileys & Emotion", emoji.group);
    try std.testing.expectEqualSlices(u8, "face-smiling", emoji.subgroup);
    try std.testing.expectEqualSlices(u8, "grinning face", emoji.name);

    const expected_keywords = [_][]const u8{ "grin", "smile", "happy" };
    try std.testing.expectEqual(expected_keywords.len, emoji.keywords.len);
    for (0..emoji.keywords.len) |i| {
        try std.testing.expectEqualSlices(u8, expected_keywords[i], emoji.keywords[i]);
    }

    try std.testing.expectEqual(5, emoji.skin_tones.len);
    const expected_skin_tones = [_][]const u8{"🧑🏻", "🧑🏼", "🧑🏽", "🧑🏾", "🧑🏿"};
    for (0..5) |i| {
        try std.testing.expectEqual(@as(usize, 1), emoji.skin_tones[i].items.len);
        try std.testing.expectEqualStrings(expected_skin_tones[i], emoji.skin_tones[i].items[0]);
    }
}

test "Emoji format function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var keywords = [_][]const u8{ "happy", "smile" };

    const emoji = Emoji{
        .character = "😀",
        .group = "Smileys & Emotion",
        .subgroup = "face-smiling",
        .name = "grinning face",
        .keywords = &keywords,
        .skin_tones = [_]ArrayList([]const u8){ArrayList([]const u8).init(std.testing.allocator)} ** 5,
    };

    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    try std.fmt.format(buffer.writer(), "{}", .{emoji});

    const expected = "😀\tSmileys & Emotion\tface-smiling\tgrinning face\thappy,smile\t";
    try std.testing.expectEqualStrings(expected, buffer.items);
}
