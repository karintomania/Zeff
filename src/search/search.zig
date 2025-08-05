const std = @import("std");
const Emoji = @import("../emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const fuzzy_search = @import("fuzzy_search.zig").fuzzy_search;

const name_bonus = 10;

pub const SearchResult = struct {
    emoji: *const Emoji,
    // this stores name or keywords whichever got the highest score.
    label: []const u8,
    score: i16,
};

pub fn search(query: []const u8, limit: u8, emojis: []const Emoji, allocator: Allocator) ![]SearchResult {
    var results = std.ArrayList(SearchResult).init(allocator);
    errdefer results.deinit();

    for (emojis) |*emoji| {
        const best = getEmojiScore(emoji.*, query);
        const score = best.score;
        const label = best.label;

        if (score > 0) {
            try results.append(SearchResult{
                .emoji = emoji,
                .label = label,
                .score = score,
            });
        }
    }

    std.mem.sort(SearchResult, results.items, {}, searchResultLessThan);

    // Resize to limit before converting to owned slice
    results.shrinkRetainingCapacity(@min(results.items.len, limit));

    return try results.toOwnedSlice();
}

fn getEmojiScore(emoji: Emoji, query: []const u8) struct { score: i16, label: []const u8 } {
    var label: []const u8 = emoji.name;
    const name_score: i16 = fuzzy_search(query, emoji.name) catch 0;

    var best_score: i16 = if (name_score > 0) name_score + name_bonus else 0;

    for (emoji.keywords) |keyword| {
        const keyword_score = fuzzy_search(query, keyword) catch 0;

        if (best_score < keyword_score) {
            best_score = keyword_score;
            label = keyword;
        }
    }

    return .{ .score = best_score, .label = label };
}

fn searchResultLessThan(_: void, lhs: SearchResult, rhs: SearchResult) bool {
    return lhs.score > rhs.score; // Sort by score in descending order
}

test "search" {
    const allocator = std.testing.allocator;

    const emojis = getTestEmojisSearch();

    const query = "grinning";

    const results = try search(query, 100, emojis, allocator);
    defer allocator.free(results);

    try std.testing.expectEqual(3, results.len);

    try std.testing.expectEqualStrings("😀", results[0].emoji.character);

    try std.testing.expectEqualStrings("grinning face", results[0].label);

    try std.testing.expectEqualStrings("😃", results[1].emoji.character);

    try std.testing.expectEqualStrings("😄", results[2].emoji.character);
}

test "search with limit" {
    const allocator = std.testing.allocator;

    const emojis = getTestEmojisSearch();

    const query = "grinning";

    const results = try search(query, 1, emojis, allocator);
    defer allocator.free(results);

    try std.testing.expectEqual(1, results.len);

    try std.testing.expectEqualStrings("😀", results[0].emoji.character);
}

fn getTestEmojisSearch() []const Emoji {
    return &[_]Emoji{
        Emoji{
            .character = "😀",
            .category = "Smileys & Emotion",
            .subcategory = "face-smiling",
            .name = "grinning face",
            .keywords = &[_][]const u8{ "grin", "smile", "happy" },
            .skin_tones = &[_][]const u8{},
        },
        Emoji{
            .character = "😄",
            .category = "Smileys & Emotion",
            .subcategory = "face-smiling",
            .name = "grinning face with smiling eyes",
            .keywords = &[_][]const u8{ "grin", "smile", "happy", "joy" },
            .skin_tones = &[_][]const u8{},
        },
        Emoji{
            .character = "😃",
            .category = "Smileys & Emotion",
            .subcategory = "face-smiling",
            .name = "grinning face with big eyes",
            .keywords = &[_][]const u8{ "grin", "smile", "happy", "joy" },
            .skin_tones = &[_][]const u8{},
        },
    };
}

test "search keywords" {
    const allocator = std.testing.allocator;

    const emojis = getTestEmojisKeywords();

    const query = "smile";

    const results = try search(query, 100, emojis, allocator);
    defer allocator.free(results);

    try std.testing.expectEqual(3, results.len);

    // match with emoji name socres higher
    try std.testing.expectEqualStrings("😀", results[0].emoji.character);

    // name as label
    try std.testing.expectEqualStrings("Smile Emoji", results[0].label);

    try std.testing.expectEqualStrings("😄", results[1].emoji.character);

    // keyword as label
    try std.testing.expectEqualStrings("smile", results[1].label);

    try std.testing.expectEqualStrings("😃", results[2].emoji.character);

    // keyword as label
    try std.testing.expectEqualStrings("smile", results[2].label);
}

fn getTestEmojisKeywords() []const Emoji {
    return &[_]Emoji{
        Emoji{
            .character = "😀",
            .category = "Smileys & Emotion",
            .subcategory = "face-smiling",
            .name = "Smile Emoji",
            .keywords = &[_][]const u8{ "grin", "smile", "happy" },
            .skin_tones = &[_][]const u8{},
        },
        Emoji{
            .character = "😄",
            .category = "Smileys & Emotion",
            .subcategory = "face-smiling",
            .name = "Test Emoji 2",
            .keywords = &[_][]const u8{ "grin", "smile", "happy", "joy" },
            .skin_tones = &[_][]const u8{},
        },
        Emoji{
            .character = "😃",
            .category = "Smileys & Emotion",
            .subcategory = "face-smiling",
            .name = "Test Emoji 3",
            .keywords = &[_][]const u8{ "grin", "smile", "happy", "joy" },
            .skin_tones = &[_][]const u8{},
        },
    };
}
