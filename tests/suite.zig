const std = @import("std");
const twmp = @import("twmp");

test "integration parseFromBytes handles three values" {
    const values = try twmp.parseFromBytes(3, i64, "123456", .{ 1, 2, 3 });

    try std.testing.expectEqual([3]i64{ 1, 23, 456 }, values);
}

test "integration allocPrint works from the public module" {
    const message = try twmp.allocPrint("hello {s}", .{"zig"});
    defer twmp.free(message);

    try std.testing.expectEqualStrings("hello zig", message);
}
