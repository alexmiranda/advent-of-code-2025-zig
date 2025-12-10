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

    try reader.seekTo(0);
    const answer_p2 = try repairTeleporterQuantum(ally, &reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
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

fn repairTeleporterQuantum(ally: Allocator, reader: *Reader) !u64 {
    // read the first line and determine where the beam is
    const start, const cols = if (reader.takeDelimiterExclusive('\n')) |line| blk: {
        reader.toss(1);
        break :blk .{
            std.mem.indexOfScalar(u8, line, 'S') orelse unreachable,
            line.len,
        };
    } else |_| unreachable;

    // find the location of all splitters and initialise their timelines count to 0
    const Loc = struct { row: usize, col: usize };
    const rows, var splitters = blk: {
        var map: std.AutoHashMapUnmanaged(Loc, u64) = .empty;
        errdefer map.deinit(ally);

        var row: usize = 1;
        while (reader.takeDelimiterExclusive('\n')) |line| : (reader.toss(1)) {
            var lastpos: usize = 0;
            while (std.mem.indexOfScalarPos(u8, line, lastpos, '^')) |col| : (lastpos = col + 1) {
                try map.put(ally, .{ .row = row, .col = col }, 0);
            }
            row += 1;
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }
        break :blk .{ row, map };
    };
    defer splitters.deinit(ally);

    // create a stack to keep track of visited locations
    const State = struct { Loc, *u64, enum { down, left, right } };
    var stack: std.ArrayList(State) = try .initCapacity(ally, rows - 2);
    defer stack.deinit(ally);

    // we start at the start point where the beam is initially
    var result: u64 = 0;
    stack.appendAssumeCapacity(.{ .{ .row = 0, .col = start }, &result, .down });

    // dfs visit each location until the bottom is reached and compute the timelines for each splitter
    while (stack.items.len > 0) {
        // peek the top item
        const loc, const ptr, const dir = stack.items[stack.items.len - 1];

        // compute the start position
        var current: Loc = .{
            .row = switch (dir) {
                .down => loc.row + 1,
                else => loc.row,
            },
            .col = switch (dir) {
                .down => loc.col,
                .left => loc.col - 1,
                .right => loc.col + 1,
            },
        };

        // either hit a splitter or the bottom
        const entry = while (current.row < rows) : (current.row += 1) {
            if (splitters.getEntry(current)) |next_splitter| break next_splitter;
        } else {
            // hit the bottom
            _ = stack.pop();
            ptr.* += 1;
            continue;
        };

        // if timelines has been computed, then we add it up and continue
        const timelines = entry.value_ptr.*;
        if (timelines > 0) {
            _ = stack.pop();
            ptr.* += timelines;
            continue;
        }

        // we haven't seen that splitter before, so we keep going...
        const splitter = entry.key_ptr.*;
        if (splitter.col > 0) {
            // check if there isn't another splitter to the left of this one...
            const left_tile: Loc = .{ .row = splitter.row, .col = splitter.col - 1 };
            if (!splitters.contains(left_tile)) {
                stack.appendAssumeCapacity(.{ splitter, entry.value_ptr, .left });
            }
        }

        if (splitter.col < cols) {
            // check if there isn't another splitter to the right of this one...
            const right_tile: Loc = .{ .row = splitter.row, .col = splitter.col - 1 };
            if (!splitters.contains(right_tile)) {
                stack.appendAssumeCapacity(.{ splitter, entry.value_ptr, .right });
            }
        }
    }

    return result;
}

test "part 1" {
    var reader: Reader = .fixed(example);
    const answer = try repairTeleporter(testing.allocator, &reader);
    try expectEqual(21, answer);
}

test "part 2" {
    var reader: Reader = .fixed(example);
    const answer = try repairTeleporterQuantum(testing.allocator, &reader);
    try expectEqual(40, answer);
}
