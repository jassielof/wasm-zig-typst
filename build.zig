const std = @import("std");

pub fn build(b: *std.Build) void {
    const mod_name = "typst_wasm_minimal_protocol";

    const target = b.standardTargetOptions(.{});
    const optimze = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule(
        mod_name,
        .{
            .root_source_file = b.path("src/lib/root.zig"),
            .target = target,
            .optimize = optimze,
        },
    );

    const docs_lib = b.addLibrary(.{
        .name = mod_name,
        .root_module = lib_mod,
    });

    const docs_step = b.step("docs", "Generate the documentation");

    const docs = b.addInstallDirectory(.{
        .source_dir = docs_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    docs_step.dependOn(&docs.step);
}
