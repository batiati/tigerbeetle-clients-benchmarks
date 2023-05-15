const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    var bench = b.addExecutable("bench", "bench.zig");
    bench.setBuildMode(mode);
    bench.setTarget(target);
    add_zig_files(bench, &.{
        "tigerbeetle.zig",
        "constants.zig",
        "storage.zig",
        "io.zig",
        "message_pool.zig",
        "message_bus.zig",
        "state_machine.zig",
        "ring_buffer.zig",
        "vsr.zig",
        "stdx.zig",
    });

    const run_cmd = bench.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const bench_build = b.step("run", "Run the Zig client bench");
    bench_build.dependOn(&run_cmd.step);
}

fn add_zig_files(exe: *std.build.LibExeObjStep, comptime files: []const []const u8) void {
    const options = exe.builder.addOptions();
    const ConfigBase = enum {
        production,
        development,
        test_min,
        default,
    };

    options.addOption(
        ConfigBase,
        "config_base",
        .default,
    );

    const TracerBackend = enum {
        none,
        perfetto,
        tracy,
    };
    options.addOption(TracerBackend, "tracer_backend", .none);

    const aof_record_enable = exe.builder.option(bool, "config-aof-record", "Enable AOF Recording.") orelse false;
    const aof_recovery_enable = exe.builder.option(bool, "config-aof-recovery", "Enable AOF Recovery mode.") orelse false;
    options.addOption(bool, "config_aof_record", aof_record_enable);
    options.addOption(bool, "config_aof_recovery", aof_recovery_enable);

    const HashLogMode = enum {
        none,
        create,
        check,
    };
    options.addOption(HashLogMode, "hash_log_mode", .none);
    const vsr_options = options.getPackage("vsr_options");

    inline for (files) |file| {
        var pkg = std.build.Pkg{
            .name = file,
            .path = .{ .path = "../tigerbeetle/src/" ++ file },
            .dependencies = &.{vsr_options},
        };
        exe.addPackage(pkg);
    }
}
