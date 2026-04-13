//! Helpers for Typst WebAssembly plugins that use the [wasm minimal protocol](https://github.com/typst-community/wasm-minimal-protocol).
//!
//! Typst loads your `.wasm` and calls exported functions. Each call:
//! - passes lengths for every argument slice the Typst side sent, and
//! - lets the plugin read the concatenated argument bytes with [`write`], then
//! - send a result (and exit status) with [`send`] or the [`str`]/[`err`] helpers.
//!
//! The two imports the host provides are declared at the bottom of this file (`wasm_minimal_protocol_*`). They must stay available when linking for `wasm32-freestanding` (or WASI plus stubbing, *see upstream `wasi-stub`*).
//!
//! For native **unit tests**, use [`parseFromBytes`] instead of [`parse`], because [`parse`] calls [`write`], which requires the Typst runtime.

const std = @import("std");

/// Alias for [`str`], kept for short call sites and parity with older examples.
pub const ok = str;

/// Send a UTF-8 payload to the host and return exit code `0` (success).
///
/// The host typically exposes the bytes as the plugin call’s return value on the Typst side (`str(p.my_func(...))`).
pub fn str(msg: []const u8) i32 {
    return send(msg, 0);
}

/// [`allocPrint`] then [`send`] with exit code `0`.
///
/// On allocation or formatting failure, sends a short diagnostic and returns `1`.
pub fn strf(comptime format: []const u8, args: anytype) i32 {
    const msg = allocPrint(format, args) catch {
        return err("strf: failed fmt");
    };
    defer std.heap.page_allocator.free(msg);

    return send(msg, 0);
}

/// Send a UTF-8 message and return exit code `1` (failure).
///
/// Typst surfaces this as a compile-time plugin error.
pub fn err(msg: []const u8) i32 {
    return send(msg, 1);
}

/// Like [`err`], but formats the message first.
pub fn errf(comptime format: []const u8, args: anytype) i32 {
    const msg = allocPrint(format, args) catch {
        return err("errf: failed fmt");
    };
    defer std.heap.page_allocator.free(msg);

    return send(msg, 1);
}

/// Read plugin arguments from the host, split them using `ns`, and parse each segment as `T`.
///
/// `ns[i]` is the byte length of the `i`th argument as passed from Typst. Their sum must match the buffer size the host writes. Supported `T` are integers and floats (`std.fmt.parseInt` / `parseFloat`).
///
/// **Note:** Calls [`write`]; only use this inside real WASM, not in native tests.
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

/// Split `args` into `C` segments with lengths `ns`, then parse each as `T`.
///
/// Use this in tests or whenever you already hold the argument bytes. For live plugins, [`parse`] is usually more convenient.
pub fn parseFromBytes(comptime C: usize, T: type, args: []const u8, ns: [C]usize) ![C]T {
    if (C == 0) {
        if (args.len != 0) return error.LengthMismatch;
        return .{};
    }

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

test parseFromBytes {
    const values = try parseFromBytes(
        3,
        u32,
        "102030",
        .{ 2, 2, 2 },
    );

    try std.testing.expectEqual([3]u32{ 10, 20, 30 }, values);
}

/// Send `msg` to the host, then return `exit_code` (`0` = ok, non-zero = err).
pub fn send(msg: []const u8, exit_code: i32) i32 {
    wasm_minimal_protocol_send_result_to_host(msg.ptr, msg.len);

    return exit_code;
}

/// Fill the buffer starting at `ptr` with the concatenated argument bytes.
pub fn write(ptr: [*]u8) void {
    wasm_minimal_protocol_write_args_to_buffer(ptr);
}

/// Allocate `n` elements of `T` with the page allocator; release with [`free`].
pub fn alloc(comptime T: type, n: usize) ![]T {
    return std.heap.page_allocator.alloc(T, n);
}

/// Format into a newly allocated `[]u8` (page allocator). Prefer [`strf`] / [`errf`] when sending straight to the host.
pub fn allocPrint(comptime format: []const u8, args: anytype) ![]u8 {
    return std.fmt.allocPrint(std.heap.page_allocator, format, args);
}

/// Free memory allocated with [`alloc`] or [`allocPrint`].
pub fn free(memory: anytype) void {
    std.heap.page_allocator.free(memory);
}

// Protocol imports (provided by Typst at load time)

pub extern "typst_env" fn wasm_minimal_protocol_send_result_to_host(ptr: [*]const u8, len: usize) void;
pub extern "typst_env" fn wasm_minimal_protocol_write_args_to_buffer(ptr: [*]u8) void;

fn parseValue(comptime T: type, bytes: []const u8) !T {
    return switch (@typeInfo(T)) {
        .int => try std.fmt.parseInt(T, bytes, 10),
        .float => try std.fmt.parseFloat(T, bytes),
        else => @compileError("Cannot parse this type: " ++ @typeName(T)),
    };
}

test "parseFromBytes: floats" {
    const values = try parseFromBytes(2, f32, "1.52.5", .{ 3, 3 });

    try std.testing.expectApproxEqAbs(@as(f32, 1.5), values[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), values[1], 0.0001);
}

test "parseFromBytes: zero segments rejects leftover bytes" {
    try std.testing.expectError(error.LengthMismatch, parseFromBytes(0, u8, "x", .{}));
    _ = try parseFromBytes(0, u8, "", .{});
}

test "parseFromBytes: LengthMismatch when segment exceeds buffer" {
    try std.testing.expectError(error.LengthMismatch, parseFromBytes(2, u8, "ab", .{ 1, 2 }));
}

test "parseFromBytes: LengthMismatch when sum of segments != buffer len" {
    try std.testing.expectError(error.LengthMismatch, parseFromBytes(2, u8, "abc", .{ 1, 1 }));
}

test "parseFromBytes: invalid integer" {
    try std.testing.expectError(error.InvalidCharacter, parseFromBytes(1, u32, "12a", .{3}));
}

test "allocPrint formats strings" {
    const message = try allocPrint("value: {}", .{42});
    defer free(message);

    try std.testing.expectEqualStrings("value: 42", message);
}
