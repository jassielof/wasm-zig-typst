const twmp = @import("twmp");

export fn hello() i32 {
    const msg = "*Hello* from `hello.wasm` written in Zig!";

    return twmp.str(msg);
}

export fn echo(len: usize) i32 {
    var res = twmp.alloc(u8, len * 2) catch return twmp.err("alloc echo");
    defer twmp.free(res);

    twmp.write(res.ptr);

    for (0..len) |i| {
        res[i + len] = res[i];
    }

    return twmp.ok(res);
}

/// Adds two decimal integers passed as separate plugin arguments (see `twmp.parse`).
export fn sum_two(a_len: usize, b_len: usize) i32 {
    const v = twmp.parse(2, i64, .{ a_len, b_len }) catch return twmp.err("parse");

    return twmp.strf("{}", .{v[0] + v[1]});
}

export fn concatenate(arg1_len: usize, arg2_len: usize) i32 {
    const args = twmp.alloc(u8, arg1_len + arg2_len) catch return twmp.err("alloc args");
    defer twmp.free(args);
    twmp.write(args.ptr);

    const out = twmp.alloc(u8, arg1_len + arg2_len + 1) catch return twmp.err("alloc out");
    defer twmp.free(out);

    @memcpy(out[0..arg1_len], args[0..arg1_len]);
    out[arg1_len] = '*';
    @memcpy(out[arg1_len + 1 ..][0..arg2_len], args[arg1_len..][0..arg2_len]);

    return twmp.ok(out);
}

export fn shuffle(arg1_len: usize, arg2_len: usize, arg3_len: usize) i32 {
    const args_len = arg1_len + arg2_len + arg3_len;
    var args = twmp.alloc(u8, args_len) catch return twmp.err("alloc shuffle args");
    defer twmp.free(args);
    twmp.write(args.ptr);

    const arg1 = args[0..arg1_len];
    const arg2 = args[arg1_len..][0..arg2_len];
    const arg3 = args[arg1_len + arg2_len ..];

    const out = twmp.alloc(u8, arg1_len + arg2_len + arg3_len + 2) catch return twmp.err("alloc shuffle out");
    defer twmp.free(out);

    @memcpy(out[0..arg3.len], arg3);
    out[arg3.len] = '-';
    @memcpy(out[arg3.len + 1 ..][0..arg1.len], arg1);
    out[arg3.len + arg1.len + 1] = '-';
    @memcpy(out[arg3.len + arg1.len + 2 ..][0..arg2.len], arg2);

    return twmp.ok(out);
}

export fn returns_ok() i32 {
    return twmp.str("This is an `Ok`");
}

export fn returns_err() i32 {
    return twmp.err("This is an `Err`");
}
