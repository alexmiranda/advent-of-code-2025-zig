const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Reader = std.Io.Reader;
const example = @embedFile("example.txt");

pub fn main() !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day01/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var buf: [4096]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &buf);
    const answer_p1, const answer_p2 = try crackPassword(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn crackPassword(reader: *Reader) !struct { u32, u32 } {
    var part_1: u32 = 0;
    var part_2: u32 = 0;
    var dial: i16 = 50;
    var rot: i8 = undefined;
    var dist: i16 = 0;
    var lasttok: i8 = undefined;
    while (reader.takeByteSigned()) |tok| {
        switch (tok) {
            'L', 'R' => rot = tok,
            '0'...'9' => dist = (dist * 10) + (tok - '0'),
            '\n' => {
                if (lasttok == '\n') break;
                if (rot == 'L') dist *= -1;
                part_2 += clicks(dial, dist);
                dial = @mod(dist + dial, 100);
                if (dial == 0) part_1 += 1;
                dist = 0;
            },
            else => unreachable,
        }
        lasttok = tok;
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    return .{ part_1, part_2 };
}

fn clicks(dial: i16, dist: i16) u32 {
    if (dist == 0) return 0;
    const full_rots: u32 = @abs(dist) / 100;
    const delta: i16 = @intCast(@abs(dist) % 100);
    if (delta == 0 or dial == 0) {
        return full_rots;
    } else if (dist < 0 and delta >= dial) {
        return full_rots + 1;
    } else if (dist > 0 and delta >= 100 - dial) {
        return full_rots + 1;
    }
    return full_rots;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer, _ = try crackPassword(&reader);
    try expectEqual(3, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    _, const answer = try crackPassword(&reader);
    try expectEqual(6, answer);
}
