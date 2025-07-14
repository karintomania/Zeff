const std = @import("std");
const Emoji = @import("emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("emojis.zig").Emojis;
const search = @import("search.zig").search;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var query: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-q")) {
            if (i + 1 < args.len) {
                query = args[i + 1];
                i += 1; // skip the next argument since we consumed it
            } else {
                std.debug.print("Error: -q option requires a query argument\n", .{});
                return;
            }
        }
    }

    if (query == null) {
        std.debug.print("Usage: {s} -q 'query'\n", .{args[0]});
        return;
    }

    const emojis = Emojis.init(allocator) catch |err| {
        std.debug.print("Error initializing Emojis: {}\n", .{err});
        return err;
    };
    defer emojis.deinit();

    const limit = 10;

    const results = try search(query.?, limit, emojis.emojis, allocator);

    const out = std.io.getStdOut().writer();

    for (results) |result| {
        try out.print("{s}:\t{s}\t[{d}]\n", .{ result.emoji.character, result.emoji.name, result.score });
    }
}
