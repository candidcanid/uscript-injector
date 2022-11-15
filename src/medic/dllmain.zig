const std = @import("std");
const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const io = std.io;
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;
const meta = std.meta;
const heap = std.heap;
const debug = std.debug;
const testing = std.testing;

const win = os.windows;
const user32 = win.user32;
const psapi = std.os.win.psapi;

const Ue3 = @import("Ue3.zig");
const XComEW = @import("XComEW.zig");
const XCom2WotC = @import("XCom2WotC.zig");

const Ue3Targets = @import("Ue3Targets");
const Flavour = Ue3Targets.Flavour;
const ue3_flavour = Flavour.fromBuildString(@import("build_details").ue3_flavour_tagstr);

const Thread = std.Thread;
const ResetEvent = Thread.ResetEvent;

// XXX: this is to get around an annoying cross-compilation build failure in zig-master ATM
comptime {
    if (builtin.target.cpu.arch == .x86) {
        asm (
            \\ .global _tls_index
            \\ _tls_index = 0x2C
        );
    }
}

fn wrappedZigExceptionHandler(comptime func: fn() anyerror!void) type {
    return struct {
        fn wrapped() void {
            func() catch |err| {
                std.debug.panic("uncaught exception '{s}' in wrapped function", .{@errorName(err)});
            };
        }
    };
}

const Overrides = struct {
    // each struct here = 'UClass' namespace
    //  where every decl = 'UFunction' to override

    // static final function bool MedicDll_AssertCorrect_CopyUtf8StringToIntArray(const array<int> Dest, const string InStr)
    pub fn @"UScriptDllInjector.Api.MedicDll_IsActive"(_: *Ue3.UObject, stack: *Ue3.FFrame, result: [*c]u32) callconv(Ue3.Apicall) void {
        _ = stack.parseUScriptCallArgs(struct {}) catch |err| {
            std.debug.panic("failed getting arguments from stack:FFrame! err = {s}", .{@errorName(err)});
        };

        result[0] = 1;
    }

    pub fn @"UScriptDllInjector.Api.MedicDll_HookGMalloc"(_: *Ue3.UObject, stack: *Ue3.FFrame, _: *anyopaque) callconv(Ue3.Apicall) void {
        if(comptime ue3_flavour != .udk32) return;

        _ = stack.parseUScriptCallArgs(struct {}) catch |err| {
            std.debug.panic("failed getting arguments from stack:FFrame! err = {s}", .{@errorName(err)});
        };

        const FreeSig = fn(this: *anyopaque, InPtr: ?*anyopaque) callconv(Ue3.Apicall) void;
        const MallocSig = fn(this: *anyopaque, Size: i32, Alignment: i32) callconv(Ue3.Apicall) ?*anyopaque;
        const ReallocSig = fn(this: *anyopaque, InPtr: ?*anyopaque, NewSize: i32, Alignment: i32) callconv(Ue3.Apicall) ?*anyopaque;

        const GMallocInMemory = extern struct {
            const Vtable = extern struct {
                @"vft[unknown_func1]": *anyopaque,
                @"vft[unknown_func2]": *anyopaque,
                @"vft[maybe::FMallocThreadSafeProxy::Malloc]": *MallocSig,
                @"vft[maybe::FMallocThreadSafeProxy::Realloc]": *ReallocSig,
                @"vft[maybe::FMallocThreadSafeProxy::Free]": *FreeSig,
                // ... some other funcs
            };

            vtable: *Vtable,
        };

        const GMallocHooks = struct {
            var @"maybe::FMallocThreadSafeProxy::Malloc": ?*const MallocSig = null;
            var @"maybe::FMallocThreadSafeProxy::Realloc": ?*const ReallocSig = null;
            var @"maybe::FMallocThreadSafeProxy::Free": ?*const FreeSig = null;

            fn HookedFree(this: *anyopaque, InPtr: ?*anyopaque) callconv(Ue3.Apicall) void {
                std.log.info("> appFree({x})", .{@ptrToInt(InPtr)});
                @"maybe::FMallocThreadSafeProxy::Free".?(this, InPtr);        
            }
        };

        const gmalloc = Ue3.ActiveRuntime.Context.imageCast(**GMallocInMemory, ue3_flavour.lookup(Ue3.native_ptr_u, "GMalloc")).*;

        // const slide = Ue3.ActiveRuntime.Context.aslrSlide();
        // const base = ImageOffsets.TargetImage.__HEADER_BASE;

        // for(gmalloc.vtable.items) |*entry, idx| {
        //     _ = idx;
        //     std.log.info("vtable({x}): {x}", .{@ptrToInt(entry) - slide + base, @ptrToInt(entry.*) - slide + base});
        // }
        // std.log.info("vtable = {x}", .{@ptrToInt(vtable) - Ue3.ActiveRuntime.Context.aslrSlide() + ImageOffsets.TargetImage.__HEADER_BASE});

        GMallocHooks.@"maybe::FMallocThreadSafeProxy::Malloc" = gmalloc.vtable.@"vft[maybe::FMallocThreadSafeProxy::Malloc]";
        GMallocHooks.@"maybe::FMallocThreadSafeProxy::Realloc" = gmalloc.vtable.@"vft[maybe::FMallocThreadSafeProxy::Realloc]";
        GMallocHooks.@"maybe::FMallocThreadSafeProxy::Free" = gmalloc.vtable.@"vft[maybe::FMallocThreadSafeProxy::Free]";

        Ue3.ActiveRuntime.patchMemoryAtAddress(
            Ue3.native_ptr_u, @ptrCast(*Ue3.native_ptr_u, @alignCast(@alignOf(*const FreeSig), &gmalloc.vtable.@"vft[maybe::FMallocThreadSafeProxy::Free]")), @ptrToInt(&GMallocHooks.HookedFree)) catch unreachable;

        // gmalloc.vtable.@"vft[maybe::FMallocThreadSafeProxy::Free]" = &GMallocHooks.HookedFree;
    }

    pub fn @"UScriptDllInjector.Api.MedicDll_AssertCorrect_CopyUtf8StringToIntArray"(_: *Ue3.UObject, stack: *Ue3.FFrame, _: *anyopaque) callconv(Ue3.Apicall) void {
        var args = stack.parseUScriptCallArgs(struct {
            Dest: Ue3.TArray(i32),
            InStr: Ue3.FString,
        }) catch |err| {
            std.debug.panic("failed getting arguments from stack:FFrame! err = {s}", .{@errorName(err)});
        };

        var allocator = heap.c_allocator;
        
        {
            const sdata = args.InStr.utf8SliceAlloc(allocator) catch unreachable;
            defer allocator.free(sdata);


            std.log.info("len {d}:{s}", .{args.Dest.slice().len, @ptrCast([*:0]u8, args.Dest.slice().ptr)});

            // std.log.info("Dest = {}", .{args.Dest});
            std.log.info("'{any}' = '{s}'", .{args.Dest.slice(), sdata});
        }

        std.debug.panic("implement me! MedicDll_AssertCorrect_CopyUtf8StringToIntArray", .{});
        stack.*.Code = @intToPtr([*c]align(1) u8, @ptrToInt(stack.Code) + 1);
    }

    pub fn @"UScriptDllInjector.CorruptedObject.Native_InternalObjectTesting"(this: *Ue3.UObject, stack: *Ue3.FFrame, result: [*c]u64) callconv(Ue3.Apicall) void {
        _ = stack.parseUScriptCallArgs(struct {}) catch |err| {
            std.debug.panic("failed getting arguments from stack:FFrame! err = {s}", .{@errorName(err)});
        };

        const hmodule_kernel32 = Ue3.ActiveRuntime.GetModuleHandleA("KERNEL32.dll") orelse unreachable;
        std.log.info("kernel32.dll in memory = {x}", .{@ptrToInt(hmodule_kernel32)});

        // const addrof_GetProcessId = RuntimeCtx.imageCast(**anyopaque, 0x00000001421E3348).*;
        // std.log.info("GetProcessId - '{x}'", .{@ptrToInt(addrof_GetProcessId)});

        // const addr = HeapAlloc(heap_handle, 0x0, 0x100) orelse unreachable;

        // mem.copy(u8, @ptrCast([*]u8, @alignCast(@alignOf([*]u8), addr))[0..100], &[_]u8{0x90, 0x90, 0x90, 0xc3});
        // std.log.info("try calling injected snippet..", .{});
        // @ptrCast(fn() callconv(.C) void, addr)();
        // std.log.info("called injected snippet!", .{});

        const sym_addr = Ue3.ActiveRuntime.manualLoadLibraryA(hmodule_kernel32, "VirtualAlloc") catch |err| {
            std.debug.panic("manualLoadLibraryA - error '{s}'", .{@errorName(err)});
        };

        std.log.info("VirtualAlloc = {x}", .{@ptrToInt(sym_addr)});

        _ = this;
        // result[0] = @ptrToInt(justTest);
        result[0] = @ptrToInt(sym_addr);
        // std.log.info("valloc-result = {x}", .{@ptrToInt(VirtualAlloc(this, 0x1000, 0x00001000, 0x40))});
    }
};

fn stdoutLogFunc(this: *anyopaque, src: [*:0]u16, some_int: u32) callconv(Ue3.Apicall) void {
    _ = this;
    _ = some_int;

    {
        std.debug.getStderrMutex().lock();
        defer std.debug.getStderrMutex().unlock();
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print("uscript>", .{}) catch unreachable;

        var it = std.unicode.Utf16LeIterator.init(src[0..std.mem.indexOfSentinel(u16, 0, src)]);
        while (it.nextCodepoint() catch null) |codepoint| {
            var buf: [4]u8 = [_]u8{undefined} ** 4;
            const len = std.unicode.utf8Encode(codepoint, &buf) catch {
                nosuspend stderr.print("_", .{}) catch unreachable;
                continue;
            };
            nosuspend stderr.writeAll(buf[0..len]) catch unreachable;
        }

        nosuspend stderr.print("\n", .{}) catch unreachable;
    }
}

fn helperMain() !void {
    std.log.debug("helperMain entry", .{});
    std.log.info("aslr_slide: {x}", .{Ue3.ActiveRuntime.Context.aslrSlide()});
    Ue3.ActiveRuntime.@"&FName::Names" = ue3_flavour.lookup(Ue3.native_ptr_u, "&FName::Names");

    if(comptime ue3_flavour != .XCom2_WotC) {
        try Ue3.FFrame.link(
            ue3_flavour.lookup(Ue3.native_ptr_u, "GNatives"),
            ue3_flavour.lookup(Ue3.native_ptr_u, "GPropAddr"),
            ue3_flavour.lookup(Ue3.native_ptr_u, "GPropObject"),
            ue3_flavour.lookup(Ue3.native_ptr_u, "GProperty"),
        );
    }

    _ = try Ue3.ActiveRuntime.patchUsingImageAddr(ue3_flavour.lookup(Ue3.native_ptr_u, "vtfentry[GLog::Log]"), &stdoutLogFunc);
    try Ue3.ActiveRuntime.registerUScriptOverrides(ue3_flavour.lookup(Ue3.native_ptr_u, "vtfentry[UFunction::Bind]"), Overrides);
}

const DLL_PROCESS_DETACH = 0;
const DLL_PROCESS_ATTACH = 1;
const DLL_THREAD_ATTACH = 2;
const DLL_THREAD_DETACH = 3;

pub export fn DllMain(_: win.HANDLE, reason: win.DWORD, _: win.LPVOID) callconv(win.WINAPI) win.BOOL {
    // 

    switch (reason) {
        DLL_PROCESS_ATTACH => {
            helperMain() catch |err| {
                std.debug.panic("helperMain had uncaught exception: {s}!", .{@errorName(err)});
            };
        },
        else => {},
    }

    return win.TRUE;
}
