const std = @import("std");
const micro = @import("microzig");
const stm32 = @import("../deps/stm32l562/stm32l562.zig");
const dev = stm32.devices.STM32L562;

pub const HalStatus = enum(u8) { ok, @"error", busy, timeout };

const AHBPrescTable: []u32 = &.{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 6, 7, 8, 9 };
const msiRangeTable: []u32 = &.{ 100000, 200000, 400000, 800000, 1000000, 2000000, 4000000, 8000000, 16000000, 24000000, 32000000, 48000000, 0, 0, 0, 0 };
var uwTickFreq = 1; // 1kHz
var systemCoreClock: u32 = 4000000;

const SysTick = extern struct { CTRL: u32, LOAD: u32, VAL: u32, CALIB: u32 };

pub fn hal_init() HalStatus {
    var status = HalStatus.ok;
    hal_NVIC_setPriorityGrouping(4);
    return status;
}

pub fn hal_NVIC_setPriorityGrouping(priorityGroup: u32) void {
    // Set the PRIGROUP[10:8] bits according to the PriorityGroup parameter value
    var reg_value: u32 = undefined;
    var priorityGroupTmp = (priorityGroup & 0x07);
    const AIRCR: *volatile u32 = @ptrFromInt(0xE000E000 + 0x0D00);
    reg_value = AIRCR.*;
    reg_value &= @bitReverse((@as(u32, 0xFFFF) << 16) | (@as(u32, 7) << 8));
    reg_value = reg_value | (@as(u32, 0x5FA) << 16) | (priorityGroupTmp << 8);
    AIRCR.* = reg_value;
}

pub fn nvic_setPriority() void {}

pub fn hal_InitTick(tickPriority: u32) HalStatus {
    _ = tickPriority;
    var status = .ok;
    if (uwTickFreq != 0) {}
    return status;
}

pub fn hal_SYSTICK_Config(ticks: u32) u32 {
    if (ticks - 1 > 0xFF_FFFF) {
        return 1; // reload value impossible
    }
    const SYSTICK: *align(4) volatile SysTick = @ptrFromInt(0xE000E000 + 0x0010);
    SYSTICK.*.LOAD = ticks - 1;
}

pub fn systemCoreClockUpdate() void {
    var tmp: u32 = undefined;
    var msirange: u32 = undefined;
    var pllvco: u32 = undefined;
    var pllsource: u32 = undefined;
    _ = pllsource;
    var pllm: u32 = undefined;
    var pllr: u32 = undefined;
    const RCC = dev.peripherals.RCC;
    // get MSI Range frequency
    if (RCC.*.CR.read().MSIRGSEL == 0) {
        msirange = RCC.*.CSR.read().MSISRANGE;
    } else {
        msirange = RCC.*.CR.read().MSIRANGE;
    }
    // MSI Frequency range in Hz
    msirange = msiRangeTable[msirange];

    switch (RCC.*.CFGR.read().SWS) {
        0 => {
            systemCoreClock = msirange;
        },
        1 => {
            systemCoreClock = 16000000;
        },
        2 => {
            systemCoreClock = 16000000;
        },
        3 => {
            pllm = @as(u32, RCC.*.PLLCFGR.read().PLLM) + 1;
            pllvco = switch (RCC.*.PLLCFGR.read().PLLSRC) {
                0x2 => 16000000 / pllm,
                0x3 => 16000000 / pllm,
                else => msirange / pllm,
            };
            pllvco *= (@as(u32, RCC.*.PLLCFGR.read().PLLR) + 1) * 2;
            systemCoreClock = pllvco / pllr;
        },
        else => {
            systemCoreClock = msirange;
        },
    }

    tmp = AHBPrescTable[@as(usize, RCC.*.CFGR.read().HPRE)];
    systemCoreClock >>= tmp;
}

pub fn main() void {
    _ = hal_init();
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // // stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
