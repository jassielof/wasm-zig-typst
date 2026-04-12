const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding, // or wasi
        },
    });

    const optimze = b.standardOptimizeOption(.{});

    const twmp_name = "typst_wasm_minimal_protocol";

    const twmp = b.dependency(twmp_name, .{}).module(twmp_name);

    const hello_wasm = b.addExecutable(.{
        .name = "hello",
        .root_module = b.createModule(.{
            .root_source_file = b.path("hello.zig"),
            .target = target,
            .optimize = optimze,
            .imports = &.{
                .{
                    .name = "twmp",
                    .module = twmp,
                },
            },
        }),
    });

    hello_wasm.entry = .disabled;
    hello_wasm.rdynamic = true;

    b.installArtifact(hello_wasm);
}
