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

    var input_file = std.fs.cwd().openFile("day02/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var buf: [4096]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &buf);
    const answer_p1 = try countInvalids(&reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    // try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn countInvalids(reader: *Reader) !usize {
    var sum: usize = 0;
    while (try reader.takeDelimiter(',')) |tok| {
        const range_str = std.mem.trim(u8, tok, "\n");
        // print("{s}\n", .{range_str});
        var it = std.mem.splitScalar(u8, range_str, '-');
        const start = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const end = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        sum += countInvalidsNaively(start, end);
    }
    return sum;
}

fn countInvalidsNaively(start: usize, end: usize) usize {
    // print("{d}-{d}\n", .{ start, end });
    var sum: usize = 0;
    var buf: [@bitSizeOf(usize)]u8 = undefined;
    for (start..end + 1) |i| {
        const log10 = std.math.log10(i);
        if ((log10 + 1) % 2 == 0) {
            const str = std.fmt.bufPrint(&buf, "{d}", .{i}) catch unreachable;
            const mid = (log10 + 1) / 2;
            const left, const right = .{ str[0..mid], str[mid..] };
            if (std.mem.eql(u8, left, right)) {
                // print("{s} {s}\n", .{ left, right });
                sum += i;
            }
        }
    }
    return sum;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try countInvalids(&reader);
    try expectEqual(1227775554, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
