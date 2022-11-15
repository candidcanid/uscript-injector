const std = @import("std");
const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const os = std.os;
const fmt = std.fmt;
const mem = std.mem;
const meta = std.meta;
const heap = std.heap;
const debug = std.debug;
const testing = std.testing;

const windows = os.windows;
const user32 = windows.user32;
const psapi = std.os.windows.psapi;

const Thread = std.Thread;
const ResetEvent = Thread.ResetEvent;

const build_details = @import("build_details");

const DLL_PROCESS_DETACH = 0;
const DLL_PROCESS_ATTACH = 1;
const DLL_THREAD_ATTACH = 2;
const DLL_THREAD_DETACH = 3;

comptime {
    if (native_arch == .x86) {
        asm (
            \\ .global _tls_index
            \\ _tls_index = 0x2C
        );
    }
}

// const appRequestExit = @intToPtr(
//     fn (a1: u32) callconv(.C) u32,
//     0x00CCB1B0,
// );

pub export fn DllMain(_: windows.HANDLE, reason: windows.DWORD, _: windows.LPVOID) callconv(windows.WINAPI) windows.BOOL {
    switch (reason) {
        DLL_PROCESS_ATTACH => {
            std.log.info("DllMain in unreal_injected.dll is being called - w00t!", .{});
            // std.os.exit(1);
            // if(build_details.target_kind == .xcomEW) {
            //     _ = appRequestExit(2121);    
            // }
        },
        else => {},
    }

    return windows.TRUE;
}
