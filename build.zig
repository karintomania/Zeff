const std = @import("std");
const builtin = @import("builtin");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // Add build option for executable name
    const exe_name = b.option([]const u8, "name", "Name of the executable") orelse "zeff";

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = exe_mod,
    });

    // Add libc
    exe.linkLibC();

    const ztb = b.dependency("zig_termbox2_wrapper", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("ztb", ztb.module("zig_termbox2_wrapper"));

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Run formatting on install step
    const fmt_step = b.step("fmt", "Check formatting");

    const fmt = b.addFmt(.{
        .paths = &.{
            "src/",
            "build.zig",
            "build.zig.zon",
        },
        .check = true,
    });

    fmt_step.dependOn(&fmt.step);
    b.getInstallStep().dependOn(fmt_step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    {
        const gen_tsv_module = b.createModule(.{
            .root_source_file = b.path("gen-tsv/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        // use emoji module
        const emoji_module = b.addModule("emoji", .{ .root_source_file = b.path("src/emoji/emoji.zig") });

        gen_tsv_module.addImport("emoji", emoji_module);

        // generate input.tsv
        const gen_tsv_step = b.step("gen-tsv", "generate input.tsv");

        const build_gen_tsv = b.addExecutable(.{
            .name = "gen-tsv",
            .root_module = gen_tsv_module,
        });

        const run_gen_tsv = b.addRunArtifact(build_gen_tsv);

        gen_tsv_step.dependOn(&build_gen_tsv.step);
        gen_tsv_step.dependOn(&run_gen_tsv.step);

        const gen_tsv_unit_tests = b.addTest(.{
            .root_module = gen_tsv_module,
        });

        const run_gen_tsv_unit_tests = b.addRunArtifact(gen_tsv_unit_tests);

        const gen_tsv_test_step = b.step("gen-tsv-test", "Run gen_tsv tests");
        // test_step.dependOn(&run_lib_unit_tests.step);
        gen_tsv_test_step.dependOn(&run_gen_tsv_unit_tests.step);
    }
}
