// This file has fuzzy_search function to score how much the "match" is
// The implementation is heavily inspired by https://github.com/philj56/fuzzy-match

const std = @import("std");
const Allocator = std.mem.Allocator;

const adjacency_bonus: i16 = 20;
const separator_bonus: i16 = 10;
const first_letter_bonus: i16 = 30;

const leading_letter_penalty: i16 = -5;
const max_leading_letter_penalty: i16 = -15;

const unmatched_letter_penalty: i16 = -1;

const initial_score: i16 = 100;

const no_match_score: i16 = -1000;

pub fn fuzzy_search(query: []const u8, str: []const u8) !i16 {
    var buf: [2048]u8 = undefined;

    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    const query_lower = try allocator.alloc(u8, query.len);

    lowerCaseString(query, query_lower);

    const str_lower = try allocator.alloc(u8, str.len);

    lowerCaseString(str, str_lower);

    if (query.len == 0) {
        return initial_score; // empty query matches everything
    }

    if (query.len > str.len) {
        return no_match_score; // query longer than string cannot match
    }

    const score = initial_score + @as(i16, @intCast(str.len - query.len)) * unmatched_letter_penalty;

    // Start the recursive matching with the first character
    return recursive_match(query_lower, str_lower, null, score, true);
}

fn lowerCaseString(str: []const u8, out: []u8) void {
    if (str.len != out.len) @panic("length of str and out should be the same.");

    for (str, 0..) |c, i| {
        out[i] = std.ascii.toLower(c);
    }
}

fn recursive_match(query: []const u8, str: []const u8, before_str: ?u8, score: i16, is_first_char: bool) i16 {
    if (query.len == 0) {
        return score;
    }

    var best_score: i16 = no_match_score;

    for (str, 0..) |c, i| {
        if (c == query[0]) {
            const new_score = compute_score(@intCast(i), is_first_char, c, if (i > 0) str[i - 1] else before_str);
            const next_score = recursive_match(query[1..], str[i + 1 ..], str[i], new_score, false);
            best_score = @max(best_score, next_score);
        }
    }

    if (best_score == no_match_score) {
        return no_match_score;
    } else {
        return score + best_score;
    }
}

fn compute_score(jump: u8, is_first_char: bool, match: u8, before_match: ?u8) i16 {
    var score: i16 = 0;

    // consecutive match gets bonus
    if (!is_first_char and jump == 0) {
        score += adjacency_bonus;
    }

    // bonus for getting a match after a separator
    if (!is_first_char or jump > 0) {
        if (before_match == null) {
            std.debug.panic("before_match should not be null when not first char or jump > 0", .{});
        }
        if (std.ascii.isAlphanumeric(match) and !std.ascii.isAlphanumeric(before_match.?)) {
            score += separator_bonus;
        }
    }

    // bonus for first letter match
    if (is_first_char and jump == 0) {
        score += first_letter_bonus;
    }

    if (is_first_char and jump > 0) {
        // penalty for leading letters
        const penalty = @max(leading_letter_penalty * jump, max_leading_letter_penalty);
        score += penalty;
    }

    return score;
}

test "recursive_match returns correct score" {
    const TestCase = struct {
        query: []const u8,
        str: []const u8,
        expected_score: i16,
    };

    const cases = [_]TestCase{
        .{
            // empty query matches anything
            .query = "",
            .str = "hello",
            .expected_score = initial_score,
        },
        .{
            // no match found
            .query = "x",
            .str = "hello",
            .expected_score = no_match_score,
        },
        .{
            // single character match at start
            .query = "h",
            .str = "hello",
            .expected_score = initial_score + 4 * unmatched_letter_penalty + first_letter_bonus,
        },
        .{
            // single character match with jump
            .query = "e",
            .str = "hello",
            .expected_score = initial_score + 4 * unmatched_letter_penalty + leading_letter_penalty,
        },
        .{
            // multiple character query
            .query = "he",
            .str = "hello",
            .expected_score = initial_score + 3 * unmatched_letter_penalty + first_letter_bonus + adjacency_bonus,
        },
        .{
            // multiple character split
            .query = "hl",
            .str = "hello",
            .expected_score = initial_score + 3 * unmatched_letter_penalty + first_letter_bonus,
        },
    };

    for (cases) |test_case| {
        const score = try fuzzy_search(test_case.query, test_case.str);
        try std.testing.expectEqual(test_case.expected_score, score);
    }
}

test "compute_score returns correct score" {
    const TestCase = struct {
        jump: u8,
        is_first_char: bool,
        match: u8,
        before_match: ?u8,
        expected_score: i16,
    };

    const cases = [_]TestCase{
        .{
            // first letter bonus
            .jump = 0,
            .is_first_char = true,
            .match = 'a',
            .before_match = null,
            .expected_score = first_letter_bonus,
        },
        .{
            // adjacency bonus
            .jump = 0,
            .is_first_char = false,
            .match = 'a',
            .before_match = 'b',
            .expected_score = adjacency_bonus,
        },
        .{
            // separator bonus
            .jump = 1,
            .is_first_char = false,
            .match = 'a',
            .before_match = ' ',
            .expected_score = separator_bonus,
        },
        .{
            // leading penalty
            .jump = 2,
            .is_first_char = true,
            .match = 'a',
            .before_match = 'c',
            .expected_score = leading_letter_penalty * 2,
        },
        .{
            // max leading penalty
            .jump = 5,
            .is_first_char = true,
            .match = 'a',
            .before_match = 'c',
            .expected_score = max_leading_letter_penalty,
        },
    };

    for (cases) |test_case| {
        const score = compute_score(test_case.jump, test_case.is_first_char, test_case.match, test_case.before_match);
        try std.testing.expectEqual(test_case.expected_score, score);
    }
}
