const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const example = @embedFile("example.txt");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day01/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var buf: [4]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &buf);
    const answer_p1 = try crackPassword(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try stdout.flush();
}

fn crackPassword(reader: *Reader) !u32 {
    var password: u32 = 0;
    var dial: i16 = 50;
    var rot: i16 = undefined;
    var dist: i16 = 0;
    var lasttok: i8 = undefined;
    while (reader.takeByteSigned()) |tok| {
        switch (tok) {
            'L', 'R' => rot = tok,
            '\n' => {
                if (lasttok == '\n') break;
                if (rot == 'L') dist *= -1;
                dial += dist;
                dial = @mod(dial, 100);
                // print("rot: {c} dist: {d} dial: {d}\n", .{ @as(u8, @intCast(rot)), dist, dial });
                if (dial == 0) password += 1;
                dist = 0;
            },
            else => dist = (dist * 10) + (tok - '0'),
        }
        lasttok = tok;
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return password;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    try expectEqual(3, crackPassword(&reader));
}

test "part 2" {
    return error.SkipZigTest;
}
