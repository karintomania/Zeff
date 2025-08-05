const std = @import("std");
const Emoji = @import("emoji/emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("emoji/emojis.zig").Emojis;
const search = @import("search/search.zig").search;
const SearchResult = @import("search/search.zig").SearchResult;
const startUI = @import("UI/ui.zig").startUI;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const emojis = Emojis.init(allocator) catch |err| {
        std.debug.print("Error initializing Emojis: {}\n", .{err});
        return err;
    };

    defer emojis.deinit();

    const selected_emoji = try startUI(&emojis, allocator);

    if (selected_emoji != null) {
        const stdow = std.io.getStdOut().writer();
        try stdow.print("{s}", .{selected_emoji.?.character});
    }
}

test {
     std.testing.refAllDecls(@This());
}
