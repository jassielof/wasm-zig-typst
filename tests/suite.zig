const std = @import("std");
const twmp = @import("twmp");

test "integration parseFromBytes: three signed segments" {
    const values = try twmp.parseFromBytes(3, i64, "123456", .{ 1, 2, 3 });

    try std.testing.expectEqual([3]i64{ 1, 23, 456 }, values);
}

test "integration parseFromBytes: two segments like plugin sum_two" {
    const v = try twmp.parseFromBytes(2, i32, "402", .{ 2, 1 });

    try std.testing.expectEqual([2]i32{ 40, 2 }, v);
}

test "integration parseFromBytes: error propagates through module boundary" {
    try std.testing.expectError(error.LengthMismatch, twmp.parseFromBytes(1, i32, "", .{1}));
}

test "integration allocPrint and free" {
    const message = try twmp.allocPrint("hello {s}", .{"zig"});
    defer twmp.free(message);

    try std.testing.expectEqualStrings("hello zig", message);
}
