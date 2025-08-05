const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub const EmojiKeywordsPair = struct {
    character: []const u8,
    keywords: [][]const u8,

    pub fn initFromLine(line: []const u8, allocator: Allocator) !EmojiKeywordsPair {
        var tab_split = std.mem.splitSequence(u8, line, "\t");

        const emoji = tab_split.next() orelse @panic("emoji expected");

        _ = tab_split.next(); // skip the description

        var keywords_list = std.ArrayList([]const u8).init(allocator);

        const keywords_str = tab_split.next() orelse @panic("keywords expected");

        var keywords_split = std.mem.splitSequence(u8, keywords_str, ",");
        // defer keywords_list.deinit();

        while (keywords_split.next()) |keyword| {
            const keyword_allocated = try allocator.dupe(u8, keyword);
            try keywords_list.append(keyword_allocated);
        }

        const emojiKeywords = EmojiKeywordsPair{
            .character = emoji,
            .keywords = try keywords_list.toOwnedSlice(),
        };

        return emojiKeywords;
    }
};

test "process adds keywords to emoji" {
    const line = "😀\tgrinning face\tgrinning,smile,happy,joy";
    const allocator = testing.allocator;

    const result = try EmojiKeywordsPair.initFromLine(line, allocator);

    try testing.expectEqual(4, result.keywords.len);
    try testing.expectEqualStrings("grinning", result.keywords[0]);
    try testing.expectEqualStrings("smile", result.keywords[1]);
    try testing.expectEqualStrings("happy", result.keywords[2]);
    try testing.expectEqualStrings("joy", result.keywords[3]);

    for (result.keywords) |keyword| {
        allocator.free(keyword);
    }
    allocator.free(result.keywords);
}
