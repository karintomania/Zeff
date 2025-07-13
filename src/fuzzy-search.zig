const std= @import("std");


fn compute_score(jump: u8, is_first_char: bool, match: u8, before_match: ?u8) u8 {
    const adjacency_bonus = 15;
    const separator_bonus = 30;
    const first_letter_bonus = 15;

    const leading_letter_penalty = -5;
    const max_leading_letter_penalty = -1;

    const score: u8 = 0;

    // consecutive match gets bonus
    if (!is_first_char and jump == 0) {
        score += adjacency_bonus;
    }

    // bonus for getting a match after a separator
    if (!is_first_char or jump > 0) {
        if (std.ascii.isAlphanumeric(match) and !std.ascii.isAlphanumeric(before_match)) {
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

test "compute_score returns correct score" {
    const TestCase = struct {
        .jump: u8,
        .is_first_char: bool,
        .match: u8,
        .before_match: ?u8,
        .expected_score: u8,
    };

    const cases = []const TestCase{
        {
            .jump = 0,
            .is_first_char = true,
            .match = 'a',
            .before_match = null,
            .expected_score = 15, // first letter bonus
       },
    };

    for (cases) |test_case| {
        const score = compute_score(test_case.jump, test_case.is_first_char, test_case.match, test_case.before_match);
        std.testing.expectEqual(u8, test_case.expected_score, score);
    }
}
