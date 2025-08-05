const std = @import("std");
const Emoji = @import("../emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
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

    const emojis = try getTestEmojisSearch(allocator);
    defer {
        for (emojis) |emoji| {
            emoji.deinit(allocator);
        }
        allocator.free(emojis);
    }

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

    const emojis = try getTestEmojisSearch(allocator);
    defer {
        for (emojis) |emoji| {
            emoji.deinit(allocator);
        }
        allocator.free(emojis);
    }

    const query = "grinning";

    const results = try search(query, 1, emojis, allocator);
    defer allocator.free(results);

    try std.testing.expectEqual(1, results.len);

    try std.testing.expectEqualStrings("😀", results[0].emoji.character);
}

fn getTestEmojisSearch(allocator: Allocator) ![]Emoji {
    const keywords1 = [_][]const u8{ "grin", "smile", "happy" };
    const keywords2 = [_][]const u8{ "grin", "smile", "happy", "joy" };
    const keywords3 = [_][]const u8{ "grin", "smile", "happy", "joy" };
    
    const empty_skin_tones = [_][]const []const u8{
        &[_][]const u8{},
        &[_][]const u8{},
        &[_][]const u8{},
        &[_][]const u8{},
        &[_][]const u8{},
    };

    var emojis = try allocator.alloc(Emoji, 3);
    
    emojis[0] = try Emoji.init(
        "😀",
        "Smileys & Emotion",
        "face-smiling",
        "grinning face",
        &keywords1,
        empty_skin_tones,
        allocator,
    );
    
    emojis[1] = try Emoji.init(
        "😄",
        "Smileys & Emotion",
        "face-smiling",
        "grinning face with smiling eyes",
        &keywords2,
        empty_skin_tones,
        allocator,
    );
    
    emojis[2] = try Emoji.init(
        "😃",
        "Smileys & Emotion",
        "face-smiling",
        "grinning face with big eyes",
        &keywords3,
        empty_skin_tones,
        allocator,
    );
    
    return emojis;
}

test "search keywords" {
    const allocator = std.testing.allocator;

    const emojis = try getTestEmojisKeywords(allocator);
    defer {
        for (emojis) |emoji| {
            emoji.deinit(allocator);
        }
        allocator.free(emojis);
    }

    const query = "smile";

    const results = try search(query, 100, emojis, allocator);
    defer allocator.free(results);

    try std.testing.expectEqual(3, results.len);

    // match with emoji name socres higher
    try std.testing.expectEqualStrings("😀", results[0].emoji.character);
    try std.testing.expectEqualStrings("Smile Emoji", results[0].label);

    try std.testing.expectEqualStrings("😄", results[1].emoji.character);
    try std.testing.expectEqualStrings("smile", results[1].label);

    try std.testing.expectEqualStrings("😃", results[2].emoji.character);
    try std.testing.expectEqualStrings("smile", results[2].label);
}

fn getTestEmojisKeywords(allocator: Allocator) ![]Emoji {
    const keywords1 = [_][]const u8{ "grin", "smile", "happy" };
    const keywords2 = [_][]const u8{ "grin", "smile", "happy", "joy" };
    const keywords3 = [_][]const u8{ "grin", "smile", "happy", "joy" };
    
    const empty_skin_tones = [_][]const []const u8{
        &[_][]const u8{},
        &[_][]const u8{},
        &[_][]const u8{},
        &[_][]const u8{},
        &[_][]const u8{},
    };

    var emojis = try allocator.alloc(Emoji, 3);
    
    emojis[0] = try Emoji.init(
        "😀",
        "Smileys & Emotion",
        "face-smiling",
        "Smile Emoji",
        &keywords1,
        empty_skin_tones,
        allocator,
    );
    
    emojis[1] = try Emoji.init(
        "😄",
        "Smileys & Emotion",
        "face-smiling",
        "Test Emoji 2",
        &keywords2,
        empty_skin_tones,
        allocator,
    );
    
    emojis[2] = try Emoji.init(
        "😃",
        "Smileys & Emotion",
        "face-smiling",
        "Test Emoji 3",
        &keywords3,
        empty_skin_tones,
        allocator,
    );
    
    return emojis;
}
