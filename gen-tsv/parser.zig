const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Emoji = @import("emoji").Emoji;
const emoji_line_handler = @import("emoji_line_handler.zig");
const keywords_processor = @import("keywords_processor.zig");

pub const EmojiParser = struct {
    group: []const u8,
    subgroup: []const u8,
    base_emoji: Emoji, // store the base emoji for skin tones
    arena: std.heap.ArenaAllocator,
    allocator: Allocator,
    map: std.StringArrayHashMap(Emoji),

    pub fn init(allocator: Allocator) EmojiParser {
        const arena = std.heap.ArenaAllocator.init(allocator);

        return EmojiParser{
            .group = "",
            .subgroup = "",
            .base_emoji = undefined,
            .arena = arena,
            .allocator = allocator,
            .map = std.StringArrayHashMap(Emoji).init(allocator),
        };
    }

    pub fn handleEmojiLine(
        self: *EmojiParser,
        line: []const u8,
    ) !void {
        const arena_allocator = self.arena.allocator();
        const lineType = emoji_line_handler.getLineType(line);

        switch (lineType) {
            .emoji => {
                const emoji = try emoji_line_handler.parseEmojiLine(self.group, self.subgroup, line, arena_allocator);
                try self.map.put(emoji.character, emoji);
                self.base_emoji = emoji;
            },
            .emoji_skin => {
                try emoji_line_handler.getSkinToneIndex(&self.base_emoji, line, arena_allocator);
                try self.map.put(self.base_emoji.character, self.base_emoji);
            },
            .group => {
                const group_slice = emoji_line_handler.parseGroupLine(line);
                self.group = try arena_allocator.dupe(u8, group_slice);
            },
            .subgroup => {
                const subgroup_slice = emoji_line_handler.parseGroupLine(line);
                self.subgroup = try arena_allocator.dupe(u8, subgroup_slice);
            },
            else => {},
        }
    }

    pub fn handleKeywordsLine(self: *EmojiParser, line: []const u8) !void {
        const emoji_keywords_pair = try keywords_processor.EmojiKeywordsPair.initFromLine(line, self.arena.allocator());

        var emoji = self.map.get(emoji_keywords_pair.character) orelse @panic("emoji doesn't exist");

        emoji.keywords = emoji_keywords_pair.keywords;

        try self.map.put(emoji.character, emoji);
    }

    pub fn deinit(self: *EmojiParser) void {
        self.map.deinit();
        self.arena.deinit();
    }
};

test "EmojiParser handles lines" {
    const test_cases = [_][]const u8{
        "# group: Smileys & Emotion",
        "# subgroup: face-smiling",
        "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face",
        "1F636 200D 1F32B FE0F                                  ; fully-qualified     # 😶‍🌫️ E13.1 face in clouds",
        "1F636 200D 1F32B                                       ; minimally-qualified # 😶‍🌫 E13.1 face in clouds", // Non-fully fully-qualified Emoji will be skipped
    };

    var parser = EmojiParser.init(testing.allocator);
    defer parser.deinit();

    for (test_cases) |line| {
        try parser.handleEmojiLine(line);
    }

    try testing.expectEqual(2, parser.map.count());
    const grinning = parser.map.get("😀") orelse {
        try testing.expect(false); // Fail if emoji not found
        return;
    };
    try testing.expectEqualStrings("Smileys & Emotion", grinning.group);
    try testing.expectEqualStrings("face-smiling", grinning.subgroup);
    try testing.expectEqualStrings("😀", grinning.character);
    try testing.expectEqualStrings("grinning face", grinning.name);
    try testing.expectEqual(0, grinning.keywords.len);

    const big_eye = parser.map.get("😶‍🌫️") orelse {
        try testing.expect(false); // Fail if emoji not found
        return;
    };
    try testing.expectEqualStrings("Smileys & Emotion", big_eye.group);
    try testing.expectEqualStrings("face-smiling", big_eye.subgroup);
    try testing.expectEqualStrings("😶‍🌫️", big_eye.character);
    try testing.expectEqualStrings("face in clouds", big_eye.name);
    try testing.expectEqual(0, big_eye.keywords.len);
}

test "EmojiParser handles keywords lines" {
    const test_emoji_lines = [_][]const u8{
        "# group: Smileys & Emotion",
        "# subgroup: face-smiling",
        "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face",
    };

    const test_keywords_line = "😀\tgrinning face\tgrinning,smile,happy,joy";

    var parser = EmojiParser.init(testing.allocator);
    defer parser.deinit();

    for (test_emoji_lines) |line| {
        try parser.handleEmojiLine(line);
    }

    try parser.handleKeywordsLine(test_keywords_line);

    const grinning = parser.map.get("😀") orelse {
        try testing.expect(false); // Fail if emoji not found
        return;
    };
    try testing.expectEqualStrings("Smileys & Emotion", grinning.group);
    try testing.expectEqualStrings("face-smiling", grinning.subgroup);
    try testing.expectEqualStrings("😀", grinning.character);
    try testing.expectEqualStrings("grinning face", grinning.name);
    try testing.expectEqual(4, grinning.keywords.len);

}

test "EmojiParser handles skin tones" {
    const test_cases = [_][]const u8{
        "# group: People & Body",
        "# subgroup: person-resting",
        "1F9D8                                                  ; fully-qualified     # 🧘 E5.0 person in lotus position",
        "1F9D8 1F3FB                                            ; fully-qualified     # 🧘🏻 E5.0 person in lotus position: light skin tone",
        "1F9D8 1F3FC                                            ; fully-qualified     # 🧘🏼 E5.0 person in lotus position: medium-light skin tone",
    };

    var parser = EmojiParser.init(testing.allocator);
    defer parser.deinit();

    for (test_cases) |line| {
        try parser.handleEmojiLine(line);
    }

    try testing.expectEqual(1, parser.map.count());
    const base = parser.map.get("🧘") orelse {
        try testing.expect(false); // Fail if emoji not found
        return;
    };
    try testing.expectEqualStrings("People & Body", base.group);
    try testing.expectEqualStrings("person-resting", base.subgroup);
    try testing.expectEqualStrings("🧘", base.character);
    try testing.expectEqualStrings("person in lotus position", base.name);

    const light_skin = base.skin_tones[0];
    try testing.expectEqual(1, light_skin.items.len);
    try testing.expectEqualStrings("🧘🏻", light_skin.items[0]);

    const medium_light_skin = base.skin_tones[1];
    try testing.expectEqual(1, medium_light_skin.items.len);
    try testing.expectEqualStrings("🧘🏼", medium_light_skin.items[0]);
}

