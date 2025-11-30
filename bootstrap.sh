#!/usr/bin/env bash

for path in $(seq -f 'day%02g' 1 12); do
  mkdir -p "${path}"
  [ ! -f "${path}/main.zig" ] && cat <<-EOF > "${path}/main.zig"
const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("$path/input.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => @panic("Input file is missing"),
        else => panic("{any}", .{err}),
    };
    defer input_file.close();

    try stdout.print("All your {s} are belong to us.\n", .{"codebase"});
    try stdout.flush();
}

test "part 1" {
    return error.SkipZigTest;
}

test "part 2" {
    return error.SkipZigTest;
}
EOF
  zig fmt "$path/main.zig"

  echo 'pub const '"$path"' = @import("'"$path"'/main.zig");' >> main.zig
done

cat <<-EOF >> main.zig

test {
    @import("std").testing.refAllDecls(@This());
}
EOF
zig fmt main.zig
