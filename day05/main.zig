const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const example = @embedFile("example.txt");

const Range = struct {
    start: u64,
    end: u64,

    fn compare(_: void, lhs: Range, rhs: Range) std.math.Order {
        return switch (std.math.order(lhs.start, rhs.start)) {
            .eq => std.math.order(lhs.end, rhs.end),
            else => |cmp| cmp,
        };
    }
};

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day05/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    var read_buf: [4096]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buf);
    const answer_p1 = try countFreshIngredients(ally, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try reader.seekTo(0);
    const answer_p2 = try totalFreshIngredients(ally, &reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn countFreshIngredients(ally: Allocator, reader: *Reader) !usize {
    var ranges: std.ArrayList(Range) = .empty;
    defer ranges.deinit(ally);

    var count: usize = 0;
    while (reader.takeDelimiterExclusive('\n')) |line| : (reader.toss(1)) {
        if (line.len == 0) break;
        var it = std.mem.splitScalar(u8, line, '-');
        const start = try std.fmt.parseUnsigned(u64, it.next().?, 10);
        const end = try std.fmt.parseUnsigned(u64, it.next().?, 10);
        try ranges.append(ally, .{ .start = start, .end = end });
    } else |err| switch (err) {
        error.EndOfStream => return 0,
        else => return err,
    }
    reader.toss(1);

    while (reader.takeDelimiterExclusive('\n')) |line| : (reader.toss(1)) {
        if (line.len == 0) break;
        const ingredient = try std.fmt.parseUnsigned(u64, line, 10);
        for (ranges.items) |range| {
            if (ingredient >= range.start and ingredient <= range.end) {
                count += 1;
                break;
            }
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    return count;
}

fn totalFreshIngredients(ally: Allocator, reader: *Reader) !usize {
    var ranges: std.PriorityQueue(Range, void, Range.compare) = .init(ally, {});
    defer ranges.deinit();

    while (reader.takeDelimiterExclusive('\n')) |line| : (reader.toss(1)) {
        if (line.len == 0) break;
        var it = std.mem.splitScalar(u8, line, '-');
        const start = try std.fmt.parseUnsigned(u64, it.next().?, 10);
        const end = try std.fmt.parseUnsigned(u64, it.next().?, 10);
        try ranges.add(.{ .start = start, .end = end });
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    var count: usize = 0;
    var prev: Range = ranges.remove();
    while (ranges.removeOrNull()) |curr| {
        if (curr.start <= prev.end) {
            prev.end = @max(prev.end, curr.end);
            continue;
        }
        count += prev.end - prev.start + 1;
        prev.start = curr.start;
        prev.end = curr.end;
    }
    count += prev.end - prev.start + 1;
    return count;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try countFreshIngredients(testing.allocator, &reader);
    try expectEqual(3, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = try totalFreshIngredients(testing.allocator, &reader);
    try expectEqual(14, answer);
}
