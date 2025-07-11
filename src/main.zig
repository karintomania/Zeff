const std = @import("std");
const Emoji = @import("emoji.zig").Emoji;
const Allocator = std.mem.Allocator;
const Emojis = @import("emoji-slice.zig").Emojis;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const emojis = Emojis.init(allocator, "input.tsv") catch |err| {
        std.debug.print("Error initializing Emojis: {}\n", .{err});
        return err;
    };

    for (emojis.emojis) |emoji| {
        std.debug.print("Emoji: {s}\tCategory: {s}\tSubcategory: {s}\tName: {s}\t", 
            .{emoji.character, emoji.category, emoji.subcategory, emoji.name});
        std.debug.print("Keywords: {s}\n", .{try std.mem.join(allocator, ", ", emoji.keywords)});
    }
}

