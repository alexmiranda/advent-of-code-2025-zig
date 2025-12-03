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
    try stdout.flush();
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
    return error.SkipZigTest;
}
