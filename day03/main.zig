const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Reader = std.Io.Reader;
const example = @embedFile("example.txt");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day03/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var buf: [4096]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &buf);
    const answer_p1 = try totalOutput(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try reader.seekTo(0);
    const answer_p2 = try totalOutputN(12, &reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn totalOutputN(comptime n: u8, reader: *Reader) !u64 {
    if (n == 0) return 0;
    if (n == 2) return try totalOutput(reader);
    var sum: u64 = 0;
    while (reader.takeDelimiterExclusive('\n')) |line| : (reader.toss(1)) {
        if (line.len == 0) break;
        if (n == 1) {
            sum += std.mem.max(u8, line) - '0';
            continue;
        }
        var buf: [n]u8 = undefined;
        var begin: usize = 0;
        var end = line.len - n;
        for (0..n) |i| {
            // stop early if we the know search space left matches
            // the amount of digits expected to fill
            if (n - i == line.len - begin) {
                // print("{s}\n", .{line});
                // print("begin: {d} i: {d} curr: {s} left: {s}\n", .{ begin, i, buf[0..i], line[line.len - begin ..] });
                std.mem.copyForwards(u8, buf[i..], line[begin..]);
                break;
            }
            // find the highest digit in the possible search space
            const hi = begin + std.mem.indexOfMax(u8, line[begin .. end + 1]);
            buf[i] = line[hi];
            begin, end = .{ hi + 1, end + 1 };
        }
        sum += try std.fmt.parseUnsigned(u64, &buf, 10);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return sum;
}

fn totalOutput(reader: *Reader) !u32 {
    var sum: u32 = 0;
    var bat_a: u8, var bat_b: u8 = .{ '0', '0' };
    while (reader.takeByte()) |ch| {
        switch (if (bat_a == '9' and bat_b == '9') '\n' else ch) {
            '\n' => {
                assert(bat_a >= '0' and bat_a <= '9');
                assert(bat_b >= '0' and bat_b <= '9');
                // print("{c}{c}\n", .{ bat_a, bat_b });
                sum += (bat_a - '0') * 10 + (bat_b - '0');
                bat_a, bat_b = .{ '0', '0' };
                // we are allowed to skip to the next newline character
                // if we found a bank with output joltage of 99
                if (ch != '\n') {
                    _ = try reader.discardDelimiterInclusive('\n');
                }
            },
            else => {
                if (ch > bat_a) {
                    const next = reader.peekByte() catch '\n';
                    if (next != '\n') {
                        bat_a = ch;
                        bat_b = next;
                        continue;
                    }
                }
                if (ch > bat_b) bat_b = ch;
            },
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return sum;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try totalOutput(&reader);
    try expectEqual(357, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = try totalOutputN(12, &reader);
    try expectEqual(3121910778619, answer);

    // extra tests just for completion :)
    reader.seek = 0;
    try expectEqual(0, totalOutputN(0, &reader));

    reader.seek = 0;
    try expectEqual(9 * 3 + 8, totalOutputN(1, &reader));

    reader.seek = 0;
    try expectEqual(357, totalOutputN(2, &reader));
}
