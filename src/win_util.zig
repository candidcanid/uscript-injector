const std = @import("std");
const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;

const ChildProcess = std.ChildProcess;

pub const RobocopyOptions = struct {
    file_glob: ?[]const u8 = null,
    copy_kind: enum {
        mirror,
        recursive,
    } = .recursive,
};

pub fn robocopy(allocator: mem.Allocator, src_dir: []const u8, dst_dir: []const u8, comptime options: RobocopyOptions) !void {
    var args = std.BoundedArray([]const u8, 20).init(0) catch unreachable;
    args.appendSlice(&.{"robocopy", src_dir, dst_dir}) catch unreachable;
    if(options.file_glob) |g| args.append(g) catch unreachable;
    switch(options.copy_kind) {
        .mirror => args.append("/mir") catch unreachable,
        .recursive => args.append("/e") catch unreachable,
    }

    std.log.debug("robocopy: {s} -> {s}", .{src_dir, dst_dir});
    var proc = ChildProcess.init(args.constSlice(), allocator);

    proc.stderr_behavior = .Ignore;
    proc.stdin_behavior = .Ignore;
    proc.stdout_behavior = .Ignore;

    switch(try proc.spawnAndWait()) {
        .Exited => |code| if(code == 8) 
            return error.FailedRobocopy, // 'several files did not copy'
        else => return error.FailedRobocopy,
    }
}

pub const WindowsInjectAPI = struct {
    const windows = std.os.windows;
    const winapi = windows.winapi;

    const ProcessAccess = enum(u32) {
        Terminate = 0x00000001,
        CreateThread = 0x00000002,
        VMOperation = 0x00000008,
        VMRead = 0x00000010,
        VMWrite = 0x00000020,
        DupHandle = 0x00000040,
        SetInformation = 0x00000200,
        QueryInformation = 0x00000400,
        SuspendResume = 0x00000800,
        Synchronize = 0x00100000,
        All = 0x001F0FFF
    };
    
    const WINAPI: std.builtin.CallingConvention = if (native_arch == .x86) .Stdcall else .C;
    
    extern "kernel32" fn ResumeThread(hThread: windows.HANDLE) callconv(WINAPI) windows.DWORD;
    extern "kernel32" fn WaitForSingleObjectEx(hHandle: windows.HANDLE, dwMilliseconds: windows.DWORD, bAlertable: windows.BOOL) callconv(WINAPI) windows.DWORD;
    
    extern "kernel32" fn VirtualAllocEx(
        hProcess: windows.HANDLE, 
        lpAddress: ?windows.LPVOID, 
        dwSize: windows.SIZE_T, 
        dwAllocationType: windows.DWORD,
        flProtect: windows.DWORD,
    ) callconv(WINAPI) ?windows.LPVOID;

    const PAGE_READWRITE = 0x4;

    extern "kernel32" fn WriteProcessMemory(
        hProcess: windows.HANDLE, 
        lpBaseAddress: windows.LPVOID, 
        lpBuffer: windows.LPCVOID, 
        nSize: windows.SIZE_T, 
        lpNumberOfBytesWritten: *windows.SIZE_T,
    ) callconv(WINAPI) windows.BOOL;

    extern "kernel32" fn CreateRemoteThreadEx(
        hProcess: windows.HANDLE,
        lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
        dwStackSize: windows.SIZE_T,
        lpStartAddress: windows.LPVOID,
        lpParameter: ?windows.LPVOID,
        dwCreationFlags: windows.DWORD,
        lpAttributeList: ?*anyopaque,
        lpThreadId: ?*windows.DWORD,
    ) callconv(WINAPI) ?windows.HANDLE;

    extern "kernel32" fn GetLastError() callconv(WINAPI) windows.BOOL;
    extern "kernel32" fn GetModuleHandleA(lpModuleName: windows.LPCSTR) callconv(WINAPI) ?windows.HANDLE;
    extern "kernel32" fn GetProcAddress(hModule: windows.HANDLE, lpProcName: windows.LPCSTR) callconv(WINAPI) ?windows.FARPROC;
    extern "kernel32" fn CloseHandle(hObject: windows.HANDLE) callconv(WINAPI) windows.BOOL;
    extern "kernel32" fn TerminateProcess(hProcess: windows.HANDLE, uExitCode: windows.UINT) callconv(WINAPI) windows.BOOL;

    const PROCESS_INFORMATION = extern struct {
        hProcess: windows.HANDLE,
        hThread: windows.HANDLE,
        dwProcesId: windows.DWORD,
        dwThreadId: windows.DWORD,

        pub fn injectDLL(self: PROCESS_INFORMATION, allocator: mem.Allocator, dllpath: []const u8) !void {
            const tmp_appdata_path = try std.fs.getAppDataDir(allocator, "Temp");
            defer allocator.free(tmp_appdata_path);

            {
                var proc = ChildProcess.init(
                    &.{
                        "robocopy", fs.path.dirname(dllpath).?, tmp_appdata_path, fs.path.basename(dllpath), "/e",
                    }, 
                    allocator,
                );

                const term = try proc.spawnAndWait();
                // TODO - do smthing with this
                _ = term;
            }

            const dllpath_bytes = try fs.path.joinZ(allocator, &.{tmp_appdata_path, fs.path.basename(dllpath)});

            const remote_ptr = VirtualAllocEx(self.hProcess, null, dllpath_bytes.len, 0x00003000, PAGE_READWRITE) orelse {
                std.log.info("wincall failure - {d}", .{GetLastError()});
                return error.FailedInjectAlloc;
            };

            {
                var nwritten: windows.SIZE_T = 0;
                switch(WriteProcessMemory(self.hProcess, remote_ptr, @ptrCast(windows.LPCVOID, dllpath_bytes), dllpath_bytes.len, &nwritten)) {
                    0 => {
                        std.log.err("wincall failure - {d}", .{GetLastError()});
                        return error.FailedInjectWrite;
                    },
                    else => {},
                }
                if(nwritten != dllpath_bytes.len) {
                    std.log.err("WriteProcessMemory - nwritten: {d} != {d}", .{nwritten, dllpath_bytes.len});
                    return error.FailedInjectWrite;
                }
            }

            const loadlibrary_a: windows.LPVOID = b: {
                const hmodule = GetModuleHandleA("kernel32") orelse {
                    std.log.err("wincall failure - {d}", .{GetLastError()});
                    return error.FailedGetProcAddr;
                };

                break :b GetProcAddress(hmodule, "LoadLibraryA") orelse {
                    std.log.err("wincall failure - {d}", .{GetLastError()});
                    return error.FailedGetProcAddr;  
                };
            };

            std.log.debug("loadlibrary_a: 0x{x}", .{@ptrToInt(loadlibrary_a)});
            const rt_handle = CreateRemoteThreadEx(self.hProcess, null, 0, loadlibrary_a, remote_ptr, 0, null, null) orelse {
                std.log.err("wincall failure - {d}", .{GetLastError()});
                return error.FailedCreateRemoteThread;  
            };
            defer switch(CloseHandle(rt_handle)) {
                0 => {
                    std.log.err("wincall failure - {d}", .{GetLastError()});
                    unreachable;
                },
                else => {},
            };

            switch(WaitForSingleObjectEx(rt_handle, 0xFFFFFFFF, @boolToInt(false))) {
                WAIT_OBJECT_0 => {},
                WAIT_FAILED => return error.WAIT_FAILED,
                WAIT_TIMEOUT, WAIT_IO_COMPLETION, WAIT_ABANDONED => return error.UnhandledWaitCondition,
                else => unreachable,
            }
        }

        pub fn resumeProc(self: PROCESS_INFORMATION) !void {
            {
                const winret = ResumeThread(self.hThread);
                if(winret == -1) return error.FailedToResumeProcess;
            }
        }

        pub fn closeProc(self: PROCESS_INFORMATION) void {
            _ = CloseHandle(self.hProcess);
            _ = CloseHandle(self.hThread);
        }

        const WAIT_FAILED = 0xFFFFFFFF;
        const WAIT_TIMEOUT = 0x00000102;
        const WAIT_OBJECT_0 = 0x00000000;
        const WAIT_ABANDONED = 0x00000080;
        const WAIT_IO_COMPLETION = 0x000000C0;

        const INFINITE = 0xFFFFFFFF;
        pub fn waitProc(self: PROCESS_INFORMATION) !void {
            switch(WaitForSingleObjectEx(self.hProcess, 0xFFFFFFFF, @boolToInt(false))) {
                WAIT_OBJECT_0 => {},
                WAIT_FAILED => return error.WAIT_FAILED,
                WAIT_TIMEOUT, WAIT_IO_COMPLETION, WAIT_ABANDONED => return error.UnhandledWaitCondition,
                else => unreachable,
            }
        }
    };

    const STARTUPINFO = extern struct {
        cb: windows.DWORD,
        lpReserved: windows.LPSTR,
        lpDesktop: windows.LPSTR,
        lpTitle: windows.LPSTR,
        dwX: windows.DWORD,
        dwY: windows.DWORD,
        dwXSize: windows.DWORD,
        dwYSize: windows.DWORD,
        dwXCountChars: windows.DWORD,
        dwYCountChars: windows.DWORD,
        dwFillAttribute: windows.DWORD,
        dwFlags: windows.DWORD,
        wShowWindow: windows.WORD,
        cbReserved2: windows.WORD,
        lpReserved2: ?*windows.BYTE,
        hStdInput: windows.HANDLE,
        hStdOutput: windows.HANDLE,
        hStdError: windows.HANDLE,
    };

    const SECURITY_ATTRIBUTES = extern struct {
        nLength: windows.DWORD,
        lpSecurityDescriptor: windows.LPVOID,
        bInheritHandle: windows.BOOL,
    };

    const LaunchProcessOptions = struct {
        start_suspended: bool = false,
    };

    const STD_INPUT_HANDLE = @bitCast(windows.DWORD, @as(i32, -10));
    const STD_OUTPUT_HANDLE = @bitCast(windows.DWORD, @as(i32, -11));
    const STD_ERROR_HANDLE = @bitCast(windows.DWORD, @as(i32, -12));

    const STARTF_USESTDHANDLES = 0x00000101;

    const CREATE_UNICODE_ENVIRONMENT = 0x00000400;
    const CREATE_SUSPENDED = 0x00000004;

    extern "kernel32" fn GetStdHandle(nStdHandle: windows.DWORD) callconv(WINAPI) windows.HANDLE;
    
    extern "kernel32" fn CreateProcessA(
        lpApplicationName: ?windows.LPSTR, 
        lpCommandLine: ?windows.LPSTR,
        lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
        lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
        bInheritHandles: windows.BOOL,
        dwCreationFlags: windows.DWORD,
        lpEnvironment: ?windows.LPVOID,
        lpCurrentDirectory: ?windows.LPSTR,
        lpStartupInfo: ?*STARTUPINFO,
        lpProcessInformation: ?*PROCESS_INFORMATION,
    ) callconv(WINAPI) windows.BOOL;

    pub fn launchProcess(allocator: mem.Allocator, exe: []const u8, args: []const u8, comptime options: LaunchProcessOptions) !PROCESS_INFORMATION {
        var startup_info: STARTUPINFO = undefined;
        for(mem.asBytes(&startup_info)) |*b| b.* = 0;

        startup_info.cb = @sizeOf(STARTUPINFO);
        startup_info.dwFlags = STARTF_USESTDHANDLES;
        
        startup_info.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
        startup_info.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
        startup_info.hStdError = GetStdHandle(STD_ERROR_HANDLE);

        var proc_info: PROCESS_INFORMATION = undefined;
        for(mem.asBytes(&proc_info)) |*b| b.* = 0;

        var sec_attr: SECURITY_ATTRIBUTES = undefined;
        for(mem.asBytes(&sec_attr)) |*b| b.* = 0;

        sec_attr.nLength = @sizeOf(SECURITY_ATTRIBUTES);
        sec_attr.bInheritHandle = @boolToInt(true);

        const wincall_exe = try allocator.dupeZ(u8, exe);
        defer allocator.free(wincall_exe);
        const wincall_args = try fmt.allocPrintZ(allocator, "\"{s}\" {s}", .{exe, args});
        defer allocator.free(wincall_args);
        const wincall_cwd = try allocator.dupeZ(u8, fs.path.dirname(exe).?);
        defer allocator.free(wincall_cwd);

        const cflags = if(options.start_suspended) 
                CREATE_UNICODE_ENVIRONMENT | CREATE_SUSPENDED
            else
                CREATE_UNICODE_ENVIRONMENT; 

        const winret = CreateProcessA(wincall_exe.ptr, wincall_args.ptr, &sec_attr, &sec_attr, @boolToInt(true), cflags, null, wincall_cwd.ptr, &startup_info, &proc_info);
        if(winret == 0) return error.WindowsLaunchProcessFailed;

        return proc_info;
    }
};