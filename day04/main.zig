const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const example = @embedFile("example.txt");

const max_occupied_positions = 4;

const RowCol = struct {
    row: usize,
    col: usize,
};

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day04/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    // var read_buf: [4096]u8 = undefined;
    var read_buf: [20000]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buf);
    const answer_p1 = try forklift(136, &reader.interface, false);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    // const answer_p2 = try forklift(136, &reader.interface, true);
    // try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn forklift(comptime max_width: u16, reader: *Reader, comptime remove: bool) !usize {
    if (max_width < 3) @compileError("incorrect max_width");

    var counter: usize = 0;
    // write buffer needs to fit 3 lines
    var buf: [max_width * 3]u8 = undefined;
    var writer: Writer = .fixed(&buf);

    // read the first line into write buffer and determine the grid's width
    const width = try reader.streamDelimiterLimit(&writer, '\n', .limited(150));
    reader.toss(1); // discard newline

    // deltas to the different tile regions of the grid
    const w: isize = @bitCast(width);
    const top_edge_adjacents = [_]isize{ -1, 1, w - 1, w, w + 1 };
    const left_edge_adjacents = [_]isize{ -w, -w + 1, 1, w, w + 1 };
    const right_edge_adjacents = [_]isize{ -w - 1, -w, -1, w - 1, w };
    const mid_adjacents = [_]isize{ -w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1 };
    const bottom_edge_adjacents = [_]isize{ -w - 1, -w, -w + 1, -1, 1 };

    // used to keep the list of rolls to remove after each line
    var clear_buf: [max_width << 1]RowCol = undefined;
    var clear_list: std.ArrayList(RowCol) = .initBuffer(&clear_buf);

    // read the second line as well assuming the grid width
    _ = try reader.streamExact(&writer, width);
    reader.toss(1); // discard newline
    // print("{s}\n", .{buf[0..writer.end]});

    // assume simd support!!!
    const chunk_size = @min(max_width - 2, std.simd.suggestVectorLength(u8).?);
    const total_chunks = (width - 2) / chunk_size;
    // print("optimal chunk size: {d}\n", .{chunk_size});

    // ************************************
    // * First row                        *
    // ************************************

    // print("==================\n", .{});
    // print("==> {s}\n", .{buf[0..width]});
    // print("    {s}\n", .{buf[width..writer.end]});
    // print("==================\n", .{});

    var offset: usize = undefined;

    // SPECIAL CASE:
    // if the first or last tiles contains a roll of paper, then it must be accessible
    if (buf[0] == '@') {
        counter += 1;
        if (remove) clear_list.appendAssumeCapacity(.{ .row = 0, .col = 0 });
    }
    if (buf[width - 1] == '@') {
        counter += 1;
        if (remove) clear_list.appendAssumeCapacity(.{
            .row = 0,
            .col = width - 1,
        });
    }

    // search for rolls of paper in each chunk of the FIRST line
    offset = 1;
    for (0..total_chunks) |_| {
        var bitmask = findPaperRolls(chunk_size, &buf, offset);
        // print("         {s}\n", .{buf[offset .. offset + block_size]});
        // print("bitmask: {b:0>8}\n", .{bitmask});

        while (bitmask > 0) {
            // count trailing zeros
            const pos = @ctz(bitmask);
            const accessible = isAccessible(&buf, offset + pos, &top_edge_adjacents, 5);
            if (accessible) {
                counter += 1;
                if (remove) clear_list.appendAssumeCapacity(.{
                    .row = 0,
                    .col = offset + pos,
                });
            }
            // print("@={d} is accessible? {any}\n", .{ offset + pos, accessible });
            // clear the lowest set bit
            bitmask &= bitmask - 1;
        }
        offset += chunk_size;
    }

    // Now we need to process the remaining items which we couldn't handle with simd
    // #[----][----][----]**#
    for (offset..width - 1) |pos| {
        print("pos remaining: {d}\n", .{pos});
        if (buf[pos] != '@') continue;
        const accessible = isAccessible(&buf, pos, &top_edge_adjacents, 5);
        if (accessible) {
            counter += 1;
            if (remove) {
                clear_list.appendAssumeCapacity(.{
                    .row = 0,
                    .col = pos,
                });
            }
        }
    }

    // panic("counter after first row: {d} (width={d})\n", .{ counter, width });

    // ************************************
    // * Middle rows                      *
    // ************************************

    // search for rolls of paper in each chunk in the REMAINING lines, but the last
    var row: usize = 0;
    while (reader.streamExact(&writer, width) catch null) |_| : (reader.toss(1)) {
        // don't forget to consume the previous line advancing the writer buffer
        defer _ = writer.consume(width);
        row += 1;

        // there must be 3 lines in the buffer, no more, no less
        assert(writer.end == width * 3);

        // print("==================\n", .{});
        // print("    {s}\n", .{buf[0..width]});
        // print("==> {s}\n", .{buf[width .. width << 1]});
        // print("    {s}\n", .{buf[width << 1 .. writer.end]});
        // print("==================\n", .{});

        // reset the offset to the begining of the middle row
        // that is, as we are moving through the grid with a sliding window of 3 rows
        // we are always processing a tile in the middle row...
        offset = width;

        // SPECIAL CASE:
        // the left edge has only 5 neighbours, so it needs to be treated differently
        if (buf[offset] == '@') {
            const accessible = isAccessible(&buf, offset, &left_edge_adjacents, 5);
            if (accessible) {
                counter += 1;
                if (remove) clear_list.appendAssumeCapacity(.{
                    .row = row,
                    .col = offset,
                });
            }
        }

        offset += 1;
        for (0..total_chunks) |_| {
            var bitmask = findPaperRolls(chunk_size, &buf, offset);
            // print("         {s}\n", .{buf[offset .. offset + block_size]});
            // print("bitmask: {b:0>8}\n", .{bitmask});

            while (bitmask > 0) {
                // count trailing zeros
                const pos = @ctz(bitmask);
                const accessible = isAccessible(&buf, offset + pos, &mid_adjacents, 8);
                if (accessible) {
                    counter += 1;
                    if (remove) clear_list.appendAssumeCapacity(.{
                        .row = row,
                        .col = offset + pos,
                    });
                }
                // print("@={d} is accessible? {any}\n", .{ offset + pos, accessible });
                // clear the lowest set bit
                bitmask &= bitmask - 1;
            }
            offset += chunk_size;
        }

        // Now we need to process the remaining items which we couldn't handle with simd
        // #[----][----][----]**#
        while (offset < (width << 1) - 1) : (offset += 1) {
            print("pos remaining: {d}\n", .{offset});
            if (buf[offset] != '@') continue;
            const accessible = isAccessible(&buf, offset, &mid_adjacents, 8);
            if (accessible) {
                counter += 1;
                if (remove) clear_list.appendAssumeCapacity(.{
                    .row = row,
                    .col = offset,
                });
            }
        }

        // SPECIAL CASE:
        // the right edge has only 5 neighbours, so it needs to be treated differently
        if (buf[offset] == '@') {
            const accessible = isAccessible(&buf, offset, &right_edge_adjacents, 5);
            if (accessible) {
                counter += 1;
                if (remove) clear_list.appendAssumeCapacity(.{
                    .row = row,
                    .col = offset,
                });
            }
        }
        // panic("counter after second row: {d}\n", .{counter});
    }

    // ************************************
    // * Last row                         *
    // ************************************
    // there must be 3 lines in the buffer and an extra newline due to using streamExact past the EOF
    // in the previous loop
    assert(writer.end == width * 2 + 1);

    // print("==================\n", .{});
    // print("    {s}\n", .{buf[0..width]});
    // print("==> {s}\n", .{buf[width .. writer.end - 1]});
    // print("==================\n", .{});

    // reset the offset to the begining of the last row
    // when we reached this point, only the two last rows are in the writer buffer
    offset = width;
    row += 1;

    // SPECIAL CASE:
    // if the first or last tiles contains a roll of paper, then it must be accessible
    if (buf[offset] == '@') {
        counter += 1;
        if (remove) clear_list.appendAssumeCapacity(.{
            .row = row,
            .col = offset,
        });
    }
    if (buf[(width << 1) - 1] == '@') {
        counter += 1;
        if (remove) clear_list.appendAssumeCapacity(.{
            .row = row,
            .col = (width << 1) - 1,
        });
    }

    // search for rolls of paper in each chunk of the LAST line
    offset += 1;
    for (0..total_chunks) |_| {
        var bitmask = findPaperRolls(chunk_size, &buf, offset);
        // print("         {s}\n", .{buf[offset .. offset + block_size]});
        // print("bitmask: {b:0>8}\n", .{bitmask});

        while (bitmask > 0) {
            // count trailing zeros
            const pos = @ctz(bitmask);
            const accessible = isAccessible(&buf, offset + pos, &bottom_edge_adjacents, 5);
            if (accessible) {
                counter += 1;
                if (remove) clear_list.appendAssumeCapacity(.{
                    .row = row,
                    .col = offset + pos,
                });
            }
            // print("@={d} is accessible? {any}\n", .{ offset + pos, accessible });
            // clear the lowest set bit
            bitmask &= bitmask - 1;
        }
        offset += chunk_size;
    }

    // Now we need to process the remaining items which we couldn't handle with simd
    // #[----][----][----]**#
    while (offset < (width << 1) - 1) : (offset += 1) {
        // print("pos remaining: {d}\n", .{offset});
        if (buf[offset] != '@') continue;
        const accessible = isAccessible(&buf, offset, &bottom_edge_adjacents, 5);
        if (accessible) {
            counter += 1;
            if (remove) clear_list.appendAssumeCapacity(.{
                .row = 0,
                .col = offset,
            });
        }
    }

    // clear the accessible paper rolls from the last line
    // for (clear_list.items) |pos| buf[pos] = '.';
    // clear_list.clearRetainingCapacity();

    // print("END:\n{s}\n", .{buf[0..writer.end]});

    // recursively keep removing paper rolls until none can be removed
    // if (remove and counter > 0) {
    //     reader.seek = 0;
    //     return counter + forklift(max_width, &reader, true);
    // }

    return counter;
}

fn isAccessible(buf: []const u8, pos: usize, adjacents: []const isize, comptime len: usize) bool {
    if (len > 8) @compileError("way too many adjacent tiles");
    const vec_a: @Vector(8, usize) = @splat(pos);
    const vec_b: @Vector(8, isize) = blk: {
        if (len == 8) break :blk std.mem.bytesAsValue([len]isize, adjacents[0..len]).*;
        var tmp: [8]isize = .{ 0, 0, 0, 0, 0, 0, 0, 0 };
        @memcpy(tmp[0..len], adjacents[0..len]);
        break :blk tmp;
    };
    const actual_coordinates = addVectors(8, vec_a, vec_b);
    inline for (0..8) |i| assert(actual_coordinates[i] >= 0 and actual_coordinates[i] <= 404);

    // print("++++++++++++++++++++++++\n", .{});
    // print("A={any}\n", .{vec_a});
    // print("B={any}\n", .{vec_b});
    // print("C={any}\n", .{actual_coordinates});
    // print("++++++++++++++++++++++++\n", .{});

    // print("pos={d} tile={c}\n", .{ pos, buf[pos] });
    var counter: usize = 0;
    inline for (0..len) |i| {
        // print("==> pos={d} tile={c}\n", .{ actual_coordinates[i], buf[actual_coordinates[i]] });
        if (buf[actual_coordinates[i]] == '@') {
            counter += 1;
            if (counter >= max_occupied_positions) return false;
        }
    }
    return true;
}

fn findPaperRolls(comptime n: usize, buf: []const u8, offset: usize) std.meta.Int(.unsigned, n) {
    comptime {
        if (n == 0) @compileError("n must be > 0");
        if (@popCount(n) != 1) @compileError("n must be a power of two for efficient simd");
    }

    assert(offset + n <= buf.len);

    // load n bytes directly from the slice (zero-copy)
    const haystack: @Vector(n, u8) = std.mem.bytesAsValue([n]u8, buf[offset .. offset + n]).*;
    const needle: @Vector(n, u8) = @splat('@');
    const mask = haystack == needle;
    // reinterpret the mask vector as an unsigned integer bit mask
    return @bitCast(mask);
}

/// addVectors adds two vectors using simd. The first vector is unsigned and the second is signed. It returns a **signed** vector.
/// this function should never be called with negative numbers that could cause the signed addition to overflow!
fn addVectors(comptime n: usize, a: @Vector(n, usize), b: @Vector(n, isize)) @Vector(n, usize) {
    const as_signed: @Vector(n, isize) = @bitCast(a);
    const result: @Vector(n, isize) = as_signed + b;
    inline for (0..n) |i| assert(result[i] >= 0);
    // reinterpret the signed vector as signed
    // return @as(@Vector(n, usize), result);
    return @bitCast(result);
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try forklift(10, &reader, false);
    try expectEqual(13, answer);
}

test "part 2" {
    if (1 == 1) return error.SkipZigTest;
    var reader: Reader = .fixed(example);
    var answer: usize = 0;
    while (true) {
        reader.seek = 0;
        const count = try forklift(10, &reader, false);
        answer += count;
        if (count == 0) break;
    }
    try expectEqual(43, answer);
}
