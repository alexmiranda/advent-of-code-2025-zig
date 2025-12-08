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

    var input_file = std.fs.cwd().openFile("day06/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    var read_buf: [4096]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buf);
    const answer_p1 = try solve(ally, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn solve(ally: Allocator, reader: *Reader) !u64 {
    var operands: std.ArrayList(u64) = .empty;
    defer operands.deinit(ally);

    // read the first line to figure out how many problems are there in the homework
    var count: usize = 0;
    if (reader.takeDelimiterExclusive('\n') catch null) |line| {
        reader.toss(1);
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |tok| {
            const value = try std.fmt.parseUnsigned(u64, tok, 10);
            try operands.append(ally, value);
            count += 1;
        }
    }

    var sum: u64 = 0;
    while (reader.takeDelimiterExclusive('\n') catch null) |line| : (reader.toss(1)) {
        if (line.len == 0) break;
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const first_tok = it.peek().?;
        if (std.mem.indexOfAny(u8, "+*", first_tok)) |_| {
            for (0..count) |i| {
                const tok = it.next().?;
                const operator = tok[0];
                var slide = i;
                sum += switch (operator) {
                    '+' => blk: {
                        var result: u64 = 0;
                        while (slide < operands.items.len) : (slide += count) {
                            result += operands.items[slide];
                        }
                        break :blk result;
                    },
                    '*' => blk: {
                        var result: u64 = 1;
                        while (slide < operands.items.len) : (slide += count) {
                            result *= operands.items[slide];
                            if (result == 0) break :blk 0;
                        }
                        break :blk result;
                    },
                    else => unreachable,
                };
            }
        } else {
            try operands.ensureUnusedCapacity(ally, count);
            while (it.next()) |tok| {
                const value = try std.fmt.parseUnsigned(u64, tok, 10);
                operands.appendAssumeCapacity(value);
            }
        }
    }

    return sum;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try solve(testing.allocator, &reader);
    try expectEqual(4277556, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
