const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zig_enum_set", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("tests.zig");
    main_tests.setBuildMode(mode);

    const gen_step = b.step("gen", "Generate test files");
    const gen_cmd_step = b.addSystemCommand(&[_][]const u8{ "julia", "test/generate.jl" });
    gen_step.dependOn(&gen_cmd_step.step);

    const clean_step = b.step("clean", "Remove test files");
    const clean_cmd_step = b.addSystemCommand(&[_][]const u8{ "rm", "test/myflags.zig", "test/my_huge_enum.zig" });
    clean_step.dependOn(&clean_cmd_step.step);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(gen_step);
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(clean_step);
}
