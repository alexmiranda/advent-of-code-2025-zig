const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const example = @embedFile("example.txt");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day09/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var read_buf: [8192]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buf);

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    const answer_p1 = try largestArea(ally, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn largestArea(ally: Allocator, reader: *Reader) !u64 {
    const Loc = struct { x: u64, y: u64 };
    var red_tiles: std.ArrayList(Loc) = .empty;
    defer red_tiles.deinit(ally);

    var largest_rect: u64 = 0;
    while (try reader.takeDelimiter('\n')) |line| {
        if (line.len == 0) break;
        var it = std.mem.splitAny(u8, line, ",\n");
        const x = try std.fmt.parseUnsigned(u64, it.next().?, 10);
        const y = try std.fmt.parseUnsigned(u64, it.next().?, 10);
        // print("{d},{d}\n", .{ x, y });
        for (red_tiles.items) |prev| {
            const dx = 1 + if (x >= prev.x) x - prev.x else prev.x - x;
            const dy = 1 + if (y >= prev.y) y - prev.y else prev.y - y;
            largest_rect = @max(largest_rect, dx * dy);
        }
        try red_tiles.append(ally, .{ .x = x, .y = y });
    }
    return largest_rect;
}

test "part 1" {
    var reader: std.Io.Reader = .fixed(example);
    const answer = largestArea(testing.allocator, &reader);
    try expectEqual(50, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
