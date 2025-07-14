const std = @import("std");
const Emoji = @import("emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const fuzzy_search = @import("fuzzy_search.zig").fuzzy_search;

const name_bonus = 10;

pub const SearchResult = struct {
    emoji: Emoji,
    score: i16,
};

pub fn search(query: []const u8, limit: u8, emojis: []const Emoji, allocator: Allocator) ![]SearchResult {
    var results = std.ArrayList(SearchResult).init(allocator);
    errdefer results.deinit();

    for (emojis) |emoji| {
        const score = getEmojiScore(emoji, query);
        if (score > 0) {
            try results.append(SearchResult{
                .emoji = emoji,
                .score = score,
            });
        }
    }

    std.mem.sort(SearchResult, results.items, {}, searchResultLessThan);

    // Resize to limit before converting to owned slice
    results.shrinkRetainingCapacity(@min(results.items.len, limit));

    return try results.toOwnedSlice();
}

fn getEmojiScore(emoji: Emoji, query: []const u8) i16 {
    const name_score: i16 = fuzzy_search(query, emoji.name) catch 0;

    var best_score: i16 = if (name_score > 0) name_score + name_bonus else 0;

    for (emoji.keywords) |keyword| {
        const keyword_score = fuzzy_search(query, keyword) catch 0;

        best_score = @max(best_score, keyword_score);
    }

    return best_score;
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

    try std.testing.expectEqualSlices(u8, "😀", results[0].emoji.character);

    try std.testing.expectEqualSlices(u8, "😃", results[1].emoji.character);

    try std.testing.expectEqualSlices(u8, "😄", results[2].emoji.character);
}

test "search with limit" {
    const allocator = std.testing.allocator;

    const emojis = getTestEmojisSearch();

    const query = "grinning";

    const results = try search(query, 1, emojis, allocator);
    defer allocator.free(results);

    try std.testing.expectEqual(1, results.len);

    try std.testing.expectEqualSlices(u8, "😀", results[0].emoji.character);
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
    try std.testing.expectEqualSlices(u8, "😀", results[0].emoji.character);

    try std.testing.expectEqualSlices(u8, "😄", results[1].emoji.character);

    try std.testing.expectEqualSlices(u8, "😃", results[2].emoji.character);
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

