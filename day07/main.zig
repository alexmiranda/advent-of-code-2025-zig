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

    var input_file = std.fs.cwd().openFile("day07/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    var read_buf: [4096]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buf);
    const answer_p1 = try repairTeleporter(ally, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn repairTeleporter(ally: Allocator, reader: *Reader) !usize {
    var beams: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer beams.deinit(ally);

    // read the first line and determine where the beam is
    const first_line = if (reader.takeDelimiterExclusive('\n')) |line| blk: {
        reader.toss(1);
        break :blk line;
    } else |_| unreachable;
    const beam = std.mem.indexOfScalar(u8, first_line, 'S') orelse unreachable;
    try beams.put(ally, beam, {});

    // read line by line splitting the beam
    var count: usize = 0;
    var next: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer next.deinit(ally);
    while (reader.take(first_line.len)) |line| : (reader.toss(1)) {
        if (line.len == 0) break;
        var keys = beams.keyIterator();
        while (keys.next()) |key| {
            const particle = key.*;
            switch (line[particle]) {
                '.' => {
                    // beam continues in the same place moving downward
                    try next.put(ally, particle, {});
                },
                '^' => {
                    // beam is split
                    if (particle > 0) {
                        try next.put(ally, particle - 1, {});
                    }
                    if (particle < first_line.len) {
                        try next.put(ally, particle + 1, {});
                    }
                    count += 1;
                },
                else => unreachable,
            }
        }
        // swap the current beams with the next ones
        beams.clearRetainingCapacity();
        std.mem.swap(@TypeOf(beams), &beams, &next);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    return count;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try repairTeleporter(testing.allocator, &reader);
    try expectEqual(21, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
