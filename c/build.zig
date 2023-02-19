const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const options = b.addOptions();
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


    const HashLogMode = enum {
        none,
        create,
        check,
    };   
    options.addOption(HashLogMode, "hash_log_mode", .none);     

    const static_lib = b.addStaticLibrary("tb_client", "../tigerbeetle/src/clients/c/tb_client.zig");
    static_lib.setMainPkgPath("../tigerbeetle/src");    
    static_lib.linkage = .static;
    static_lib.linkLibC();
    static_lib.setBuildMode(mode);
    static_lib.setTarget(target);
    static_lib.pie = true;
    static_lib.bundle_compiler_rt = true;
    static_lib.addOptions("vsr_options", options);
    
    const bench = b.addExecutable("bench", "bench.c");
    bench.setBuildMode(mode);
    bench.linkLibrary(static_lib);
    bench.linkLibC();
    bench.addIncludeDir("../tigerbeetle/src/clients/c/");

    const run_cmd = bench.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const bench_build = b.step("run", "Run the C client bench");
    bench_build.dependOn(&run_cmd.step);
}
