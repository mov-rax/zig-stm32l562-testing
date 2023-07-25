const std = @import("std");
const microzig = @import("deps/microzig/build.zig");
const Cpu = microzig.Cpu;
const Chip = microzig.Chip;

fn root_dir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

pub const cortex_m33 = Cpu{
    .name = "ARM Cortex-M33",
    .source = .{
        .path = std.fmt.comptimePrint("{s}/cortex-m33.zig", .{root_dir()}),
    },
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .none,
    },
};
