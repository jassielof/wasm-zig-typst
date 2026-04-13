//! Tiny helpers for Typst WASM plugins that use the minimal protocol.

const std = @import("std");

/// Alias for `str`.
///
/// This exists for short, old-style call sites.
pub const ok = str;

/// Send a message to the WebAssembly host.
///
/// Returns `0`.
pub fn str(msg: []const u8) i32 {
    return send(msg, 0);
}

/// Send a formatted message to the WebAssembly host.
///
/// Returns `0` on success.
///
/// If formatting fails, an error message is sent instead and `1` is returned.
pub fn strf(comptime format: []const u8, args: anytype) i32 {
    const msg = allocPrint(format, args) catch {
        return err("strf: failed fmt");
    };
    defer hpa.free(msg);

    return send(msg, 0);
}

/// Send an error message to the WebAssembly host.
///
/// Returns `1`.
pub fn err(msg: []const u8) i32 {
    return send(msg, 1);
}

/// Send a formatted error message to the WebAssembly host.
///
/// Returns `1`.
pub fn errf(comptime format: []const u8, args: anytype) i32 {
    const msg = allocPrint(format, args) catch {
        return err("errf: failed fmt");
    };
    defer hpa.free(msg);

    return send(msg, 1);
}

/// Parse arguments into an array of `[C]T`.
///
/// The host writes the raw argument bytes into a temporary buffer and this
/// function splits that buffer according to `ns` before parsing each segment.
///
/// Supported types are any integer or floating-point type.
pub fn parse(comptime C: usize, T: type, ns: [C]usize) ![C]T {
    var n: usize = 0;

    for (ns) |u| {
        n = std.math.add(usize, n, u) catch return error.LengthMismatch;
    }

    const args = try alloc(u8, n);
    defer free(args);

    write(args.ptr);

    return parseFromBytes(C, T, args, ns);
}

/// Parse already-fetched argument bytes using the segment lengths in `ns`.
///
/// This is the pure helper behind `parse`, and it is convenient for unit tests
/// and host-side preprocessing.
pub fn parseFromBytes(comptime C: usize, T: type, args: []const u8, ns: [C]usize) ![C]T {
    if (C == 0) return .{};

    var result: [C]T = undefined;
    var start: usize = 0;

    inline for (0..C) |index| {
        const end = std.math.add(usize, start, ns[index]) catch return error.LengthMismatch;
        if (end > args.len) return error.LengthMismatch;

        result[index] = try parseValue(T, args[start..end]);
        start = end;
    }

    if (start != args.len) return error.LengthMismatch;

    return result;
}

/// Send the provided message to the WebAssembly host.
///
/// Returns `exit_code` after sending `msg`.
pub fn send(msg: []const u8, exit_code: i32) i32 {
    wasm_minimal_protocol_send_result_to_host(msg.ptr, msg.len);

    return exit_code;
}

/// Write input arguments into the buffer pointed to by `ptr`.
pub fn write(ptr: [*]u8) void {
    wasm_minimal_protocol_write_args_to_buffer(ptr);
}

// ===
// Heap page allocator

const hpa = std.heap.page_allocator;

/// Allocate using a `std.heap.page_allocator`.
///
/// Call `free` with the result to release the memory.
pub fn alloc(comptime T: type, n: usize) ![]T {
    return hpa.alloc(T, n);
}

/// Allocate and format a string with `std.fmt.allocPrint`
/// using a `std.heap.page_allocator`.
///
/// You likely want to use `strf` or `errf` instead.
pub fn allocPrint(comptime format: []const u8, args: anytype) ![]u8 {
    const msg = try std.fmt.allocPrint(hpa, format, args);

    return msg;
}

/// Free a slice allocated with `alloc`.
pub fn free(memory: anytype) void {
    hpa.free(memory);
}

// ===
// Functions for the protocol

pub extern "typst_env" fn wasm_minimal_protocol_send_result_to_host(ptr: [*]const u8, len: usize) void;
pub extern "typst_env" fn wasm_minimal_protocol_write_args_to_buffer(ptr: [*]u8) void;

fn parseValue(comptime T: type, bytes: []const u8) !T {
    return switch (@typeInfo(T)) {
        .int => try std.fmt.parseInt(T, bytes, 10),
        .float => try std.fmt.parseFloat(T, bytes),
        else => @compileError("Cannot parse this type: " ++ @typeName(T)),
    };
}

test "parseFromBytes parses integers of any arity" {
    const values = try parseFromBytes(3, u32, "102030", .{ 2, 2, 2 });

    try std.testing.expectEqual([3]u32{ 10, 20, 30 }, values);
}

test "parseFromBytes parses floats" {
    const values = try parseFromBytes(2, f32, "1.52.5", .{ 3, 3 });

    try std.testing.expectApproxEqAbs(@as(f32, 1.5), values[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), values[1], 0.0001);
}

test "allocPrint formats strings" {
    const message = try allocPrint("value: {}", .{ 42 });
    defer free(message);

    try std.testing.expectEqualStrings("value: 42", message);
}
