const std = @import("std");

const adjacency_bonus = 15;
const separator_bonus = 30;
const first_letter_bonus = 15;

const leading_letter_penalty: i16 = -5;
const max_leading_letter_penalty: i16 = -15;

const unmatched_letter_penalty: i16 = -1;

const initial_score: i16 = 100;

const no_match_score: i16 = -1000;

pub fn fuzzy_search(pattern: []const u8, str: []const u8) i16 {
    if (pattern.len == 0) {
        return initial_score; // empty pattern matches everything
    }

    if (pattern.len > str.len) {
        return no_match_score; // pattern longer than string cannot match
    }

    const score = initial_score + @as(i16, @intCast(str.len - pattern.len)) * unmatched_letter_penalty;

    // Start the recursive matching with the first character
    return recursive_match(pattern, str, null, score, true);
}

fn recursive_match(pattern: []const u8, str: []const u8, before_str: ?u8, score: i16, is_first_char: bool) i16 {
    if (pattern.len == 0) {
        return score;
    }

    var best_score: i16 = no_match_score;

    for (str, 0..) |c, i| {
        if (c == pattern[0]) {
            const new_score = compute_score(@intCast(i), is_first_char, c, if (i > 0) str[i - 1] else before_str);
            const next_score = recursive_match(pattern[1..], str[i + 1 ..], str[i], new_score, false);
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
        pattern: []const u8,
        str: []const u8,
        expected_score: i16,
    };

    const cases = [_]TestCase{
        .{
            // empty pattern matches anything
            .pattern = "",
            .str = "hello",
            .expected_score = initial_score,
        },
        .{
            // no match found
            .pattern = "x",
            .str = "hello",
            .expected_score = no_match_score,
        },
        .{
            // single character match at start
            .pattern = "h",
            .str = "hello",
            .expected_score = initial_score + 4 * unmatched_letter_penalty + first_letter_bonus,
        },
        .{
            // single character match with jump
            .pattern = "e",
            .str = "hello",
            .expected_score = initial_score + 4 * unmatched_letter_penalty + leading_letter_penalty,
        },
        .{
            // multiple character pattern
            .pattern = "he",
            .str = "hello",
            .expected_score = initial_score + 3 * unmatched_letter_penalty + first_letter_bonus + adjacency_bonus,
        },
        .{
            // multiple character split
            .pattern = "hl",
            .str = "hello",
            .expected_score = initial_score + 3 * unmatched_letter_penalty + first_letter_bonus,
        },
    };

    for (cases) |test_case| {
        const score = fuzzy_search(test_case.pattern, test_case.str);
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
