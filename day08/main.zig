const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const example = @embedFile("example.txt");

const Box = packed struct {
    x: f32,
    y: f32,
    z: f32,
    _: f32 = 0.0,

    pub fn format(self: Box, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("({d:.0},{d:.0},{d:.0})", .{ self.x, self.y, self.z });
    }
};

const Pair = struct { u16, u16 };

pub fn main() !void {
    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day08/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    var read_buf: [17658]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buf);
    const boxes = try parseInput(ally, &reader.interface);
    defer ally.free(boxes);

    const answer_p1 = try connect(ally, boxes, 1000);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

fn parseInput(ally: Allocator, reader: *Reader) ![]Box {
    var list: std.ArrayList(Box) = .empty;
    defer list.deinit(ally);

    while (try reader.peekByte() != '\n') {
        const sx = try reader.takeDelimiter(',') orelse "";
        const sy = try reader.takeDelimiter(',') orelse "";
        const sz = try reader.takeDelimiter('\n') orelse "";
        // print("{s},{s},{s}\n", .{ sx, sy, sz });
        const x = try std.fmt.parseFloat(f32, sx);
        const y = try std.fmt.parseFloat(f32, sy);
        const z = try std.fmt.parseFloat(f32, sz);
        try list.append(ally, .{ .x = x, .y = y, .z = z });
    }
    return list.toOwnedSlice(ally);
}

fn connect(ally: Allocator, boxes: []Box, n: usize) !u32 {
    var heap: std.PriorityQueue(Pair, []Box, compare) = .init(ally, boxes);
    defer heap.deinit();

    // sort all the box pairs by distance
    try heap.ensureTotalCapacity(boxes.len * (boxes.len - 1) / 2);
    for (0..boxes.len - 1) |i| {
        for (i + 1..boxes.len) |j| {
            try heap.add(.{ @intCast(i), @intCast(j) });
        }
    }

    // we start with every junction box being its own circuit
    const circuits = try initCircuits(ally, boxes.len);
    defer ally.free(circuits);

    // sizes will be used to keep track of the sizes of each circuit
    const sizes = blk: {
        var ones = try ally.alloc(u16, boxes.len);
        for (0..boxes.len) |i| ones[i] = 1;
        break :blk ones;
    };
    defer ally.free(sizes);

    // we pop off the first pair and make the first circuit
    if (heap.removeOrNull()) |first_pair| {
        const a, const b = first_pair;
        circuits[b] = a;
        sizes[a] = 2;
        // print("{f} connects with {f}\n", .{ boxes[a], boxes[b] });
    }

    // now we do this a few more times until we have reached the n amount of connections
    for (1..n) |_| {
        const a, const b = heap.removeOrNull() orelse break;
        const root_of_a = findCircuitOf(circuits, a);
        const root_of_b = findCircuitOf(circuits, b);
        if (root_of_a != root_of_b) {
            // print("{f} connects with {f}\n", .{ boxes[a], boxes[b] });
            if (sizes[root_of_a] >= sizes[root_of_b]) {
                circuits[root_of_b] = root_of_a;
                sizes[root_of_a] += sizes[root_of_b];
            } else {
                circuits[root_of_a] = root_of_b;
                sizes[root_of_b] += sizes[root_of_a];
            }
        } else {
            // print("{f} DOES NOT connect with {f}\n", .{ boxes[a], boxes[b] });
        }
    }

    var largest: @Vector(4, u32) = @splat(1);
    inline for (0..3) |i| {
        largest[i] = blk: {
            const index = std.mem.indexOfMax(u16, sizes);
            const val = sizes[index];
            sizes[index] = 0;
            break :blk val;
        };
    }
    // print("largest: {any}\n", .{largest});
    return @reduce(.Mul, largest);
}

fn sameCircuit(circuits: []u16, a: u16, b: u16) bool {
    return findCircuitOf(circuits, a) == findCircuitOf(circuits, b);
}

fn findCircuitOf(circuits: []u16, box: u16) u16 {
    var x = box;
    while (circuits[x] != x) {
        x, circuits[x] = .{ circuits[x], circuits[circuits[x]] };
    }
    return x;
}

fn initCircuits(ally: Allocator, len: usize) ![]u16 {
    var circuits = try ally.alloc(u16, len);
    errdefer ally.free(circuits);

    var slide: u16 = 0;
    if (std.simd.suggestVectorLength(u16)) |vector_width| {
        var indexes: @Vector(vector_width, u16) = std.simd.iota(usize, vector_width);
        const increment: @Vector(vector_width, u16) = @splat(vector_width);
        while (slide + vector_width < len) : (slide += vector_width) {
            @memcpy(circuits[slide .. slide + vector_width], &@as([vector_width]u16, indexes));
            indexes = indexes + increment;
        }
    }

    while (slide < len) : (slide += 1) {
        circuits[slide] = slide;
    }

    return circuits;
}

fn compare(boxes: []Box, lhs: Pair, rhs: Pair) std.math.Order {
    const dx = distance(boxes[lhs.@"0"], boxes[lhs.@"1"]);
    const dy = distance(boxes[rhs.@"0"], boxes[rhs.@"1"]);
    return std.math.order(dx, dy);
}

fn distance(a: Box, b: Box) f32 {
    const va: @Vector(4, f32) = @bitCast(a);
    const vb: @Vector(4, f32) = @bitCast(b);
    const diff = @abs(va - vb);
    const prod = diff * diff;
    const sum = @reduce(.Add, prod);
    return std.math.sqrt(sum);
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const boxes = try parseInput(testing.allocator, &reader);
    defer testing.allocator.free(boxes);
    const answer = try connect(testing.allocator, boxes, 10);
    try expectEqual(40, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
