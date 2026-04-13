const std = @import("std");
const twmp = @import("twmp");

export fn hello() i32 {
    const msg = "*Hello* from `hello.wasm` written in Zig!";

    return twmp.str(msg);
}

export fn echo(len: usize) i32 {
    var res = twmp.alloc(u8, len * 2) catch return 1;
    defer twmp.free(res);

    twmp.write(res.ptr);

    for (0..len) |i| {
        res[i + len] = res[i];
    }

    return twmp.ok(res);
}
