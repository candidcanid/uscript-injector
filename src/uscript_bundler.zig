const std = @import("std");
const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const io = std.io;
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const heap = std.heap;

const ChildProcess = std.ChildProcess;

const win_util = @import("win_util.zig");

const Ue3Targets = @import("Ue3Targets");
const Flavour = Ue3Targets.Flavour;
const ue3_flavour = Flavour.fromBuildString(@import("build_details").ue3_flavour_tagstr);

comptime {
    if (builtin.target.cpu.arch == .x86) {
        asm (
            \\ .global _tls_index
            \\ _tls_index = 0x2C
        );
    }
}

const INIConfig = struct {
    const Namespace = struct {
        allocator: mem.Allocator,
        name: []const u8,
        entries: std.ArrayList([]const u8),

        pub fn init(allocator: mem.Allocator, name: []const u8) !Namespace {
            return Namespace{
                .name = try allocator.dupe(u8, name),
                .allocator = allocator,
                .entries = std.ArrayList([]const u8).init(allocator),
            };
        }

        pub fn addEntry(self: *Namespace, entry: []const u8) !void {
            try self.entries.append(try self.allocator.dupe(u8, entry));
        }

        pub fn overrideEntry(self: *Namespace, old: []const u8, new: []const u8) !void {
            var replacement = try self.allocator.dupe(u8, new);
            errdefer self.allocator.free(replacement);

            for(self.entries.items) |*v| {
                if(mem.eql(u8, old, v.*)) {
                    self.allocator.free(v.*);
                    v.* = replacement;
                }
            } else {
                std.log.err("[{s}] cannot find '{s}' to replace with '{s}'", .{self.name, old, new});
            }
        }

        pub fn deinit(self: Namespace) void {
            for(self.entries.items) |s| {
                self.allocator.free(s);
            }
            self.entries.deinit();
            self.allocator.free(self.name);
        }
    };

    allocator: mem.Allocator,
    namespaces: std.ArrayList(*Namespace),

    pub fn init(allocator: mem.Allocator) INIConfig {
        return INIConfig{
            .allocator = allocator,
            .namespaces = std.ArrayList(*Namespace).init(allocator),
        };
    }

    pub fn addNamespace(self: *INIConfig, name: []const u8) !*Namespace {
        try self.namespaces.ensureUnusedCapacity(1);
        var ns = try self.allocator.create(Namespace);
        errdefer self.allocator.destroy(ns);

        ns.* = try Namespace.init(self.allocator, name);
        errdefer ns.deinit();

        try self.namespaces.append(ns);
        return ns;
    }

    pub fn get(self: *INIConfig, name: []const u8) !*Namespace {
        for(self.namespaces.items) |ns| {
            if(mem.eql(u8, ns.name, name)) return ns; 
        } else {
            std.log.err("namespace {s} does not exist in .ini", .{name});
            return error.MissingNamespace;
        }
    }

    pub fn initFromFile(allocator: mem.Allocator, dir: fs.Dir, path: []const u8) !INIConfig {
        var config = INIConfig.init(allocator);
        errdefer config.deinit();

        var buf = try allocator.alloc(u8, 0x1000);
        defer allocator.free(buf);

        var file = try dir.openFile(path, .{});
        defer file.close();

        var buf_reader = io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var current_ns: ?*Namespace = null;
        while(try in_stream.readUntilDelimiterOrEof(buf, '\n')) |line| {
            const stripped = if(line[line.len - 1] == '\r') line[0..line.len - 1] else line; 
            if(stripped.len <= 1) continue;

            // [SomeField]
            if(stripped[0] == '[' and stripped[stripped.len - 1] == ']') {
                current_ns = try config.addNamespace(stripped);
            }

            // some_key=some_value
            if(mem.indexOf(u8, stripped, "=") != null) {
                if(current_ns) |ns| {
                    try ns.addEntry(stripped);
                } else {
                    std.log.err("key=value entry encountered before any namespace", .{});
                    return error.InvalidINIConfig;
                }
            }
        }

        return config;
    }

    pub fn saveToFile(self: INIConfig, dir: fs.Dir, path: []const u8) !void {
        var file = try dir.createFile(path, .{.truncate = true});
        defer file.close();

        var buf_writer = io.bufferedWriter(file.writer());
        defer buf_writer.flush() catch unreachable;
        
        var writer = buf_writer.writer();

        for(self.namespaces.items) |ns| {
            try fmt.format(writer, "{s}\r\n", .{ns.name});
            for(ns.entries.items) |entry| {
                try fmt.format(writer, "{s}\r\n", .{entry});
            }

            try fmt.format(writer, "\r\n", .{});
        }

        try fmt.format(writer, "\r\n", .{});
    }

    pub fn deinit(self: INIConfig) void {
        for(self.namespaces.items) |ns| {
            ns.deinit();
            self.allocator.destroy(ns);
        }

        self.namespaces.deinit();
    }
};


const WindowsInjectAPI = struct {
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

const UScriptBuilder = struct {
    const Self = @This();

    arena: std.heap.ArenaAllocator, 

    pub fn init(allocator: mem.Allocator) Self {
        return Self {
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }


    fn cleanDir(_: *Self, path: []const u8, comptime suffixes: []const []const u8) !void {
        var iter_dir = try fs.cwd().openIterableDir(path, .{});
        defer iter_dir.close();

        var it = iter_dir.iterate();
        while(try it.next()) |v| {
            inline for(suffixes) |s| {
                if(mem.endsWith(u8, v.name, s)) {
                    std.log.debug("rm {s}", .{v.name});        
                    try iter_dir.dir.deleteFile(v.name);
                }
            }
        }
    }

    fn robocopy(self: *Self, src_dir: []const u8, dst_dir: []const u8, comptime options: win_util.RobocopyOptions) !void {
        return win_util.robocopy(self.arena.allocator(), src_dir, dst_dir, options);
    }

    fn joinPath(self: *Self, paths: []const []const u8) ![]u8 {
        return try fs.path.join(self.arena.allocator(), paths);
    }
};

fn compileUScript(b: *UScriptBuilder, ctx: Flavour.BuildContext) !void {
    inline for(.{ctx.src_dir, ctx.mod_dir, ctx.out_dir}) |d| {
        if(fs.path.isAbsolute(d)) {
            std.log.err("'{s}' must be relative to root build.zig, and not an absolute path", .{d});
            return error.InvalidBuildDir;
        }

        _ = fs.cwd().openDir(d, .{}) catch |err| {
            std.log.err("invalid directory '{s}' error:{s}", .{d, @errorName(err)});
            return err;
        };
    }

    std.log.info("clean out old build .u, .ini files", .{});
    try b.cleanDir(ctx.out_dir, &.{".ini", ".u",  ".txt"});
    try b.cleanDir(ctx.sdk_script_dir, &.{".ini", ".u",});

    std.log.info("mirror '{s}' to '{s}'", .{ctx.srcorig_dir, ctx.sdk_src_dir});
    try b.robocopy(ctx.srcorig_dir, ctx.sdk_src_dir, .{.copy_kind = .mirror});

    std.log.info("compile core uscript packages", .{});
    {
        var proc = ChildProcess.init(&.{ctx.sdk_exe, "MAKE", "-NOPAUSE", "-UNATTENDED"}, b.arena.allocator());
        switch(try proc.spawnAndWait()) {
            .Exited => |code| if(code != 0) return error.FailedUScriptCompile,
            else => return error.MysteryProcessSpawnError,
        }
    }
    
    std.log.info("alter .ini and copy in mods", .{});
    for(ctx.mods) |mod| {
        try b.robocopy(
            try b.joinPath(&.{ctx.mod_dir, mod}),
            try b.joinPath(&.{ctx.sdk_src_dir, mod}),
        .{.copy_kind = .recursive});
    }
    
    std.log.info("compile mod script packages", .{});
    const outdir = try fs.cwd().openDir(try fs.path.join(b.arena.allocator(), &.{ctx.out_dir}), .{});

    {
        var engine_ini = try INIConfig.initFromFile(b.arena.allocator(), std.fs.cwd(), ctx.custom_ini.src_ini);
        defer engine_ini.deinit();
       
        for(ctx.custom_ini.items) |custom_ns| {
            var ns = try engine_ini.get(custom_ns.name);
            for(custom_ns.operations.append) |v| {
                try ns.addEntry(v);
            }

            for(custom_ns.operations.override) |v| {
                try ns.overrideEntry(v.original_entry, v.new_entry);
            }
        }

        try engine_ini.saveToFile(std.fs.cwd(), ctx.custom_ini.dst_ini);
        try engine_ini.saveToFile(outdir, std.fs.path.basename(ctx.custom_ini.dst_ini));
    }

    {
        var proc = ChildProcess.init(&.{ctx.sdk_exe, "MAKE", "-NOPAUSE", "-UNATTENDED"}, b.arena.allocator());
        switch(try proc.spawnAndWait()) {
            .Exited => |code| if(code != 0) return error.FailedUScriptCompile,
            else => return error.MysteryProcessSpawnError,
        }
    }

    for(ctx.mods) |mod| {
        const out_loc = try fs.path.join(b.arena.allocator(), &.{ctx.out_dir});
        const mname = try fmt.allocPrint(b.arena.allocator(), "{s}.u", .{mod});

        std.log.debug("copying {s}: {s} -> {s}", .{mname, ctx.sdk_script_dir, out_loc});

        {
            var proc = ChildProcess.init(&.{"robocopy", ctx.sdk_script_dir, out_loc, mname}, b.arena.allocator());
            const term = try proc.spawnAndWait();
            // TODO - do smthing with this
            _ = term;
        }
    }
}

fn runUScript(b: *UScriptBuilder, ctx: Flavour.RunContext) !void {
    try b.robocopy(ctx.src_scriptdir, ctx.dst_scriptdir, .{
        .file_glob = "*.u", .copy_kind = .recursive,
    });

    {
        var engine_ini = try INIConfig.initFromFile(b.arena.allocator(), std.fs.cwd(), ctx.custom_ini.src_ini);
        defer engine_ini.deinit();
       
        for(ctx.custom_ini.items) |custom_ns| {
            var ns = try engine_ini.get(custom_ns.name);
            for(custom_ns.operations.append) |v| {
                try ns.addEntry(v);
            }

            for(custom_ns.operations.override) |v| {
                try ns.overrideEntry(v.original_entry, v.new_entry);
            }
        }

        try engine_ini.saveToFile(std.fs.cwd(), ctx.custom_ini.dst_ini);
    }

    const exe_proc = try WindowsInjectAPI.launchProcess(b.arena.allocator(), ctx.exe, ctx.arguments, .{
        .start_suspended = true,
    });
    defer exe_proc.closeProc();

    if(ctx.inject_dll) |dllpath| {
        try exe_proc.injectDLL(b.arena.allocator(), dllpath);
    }

    try exe_proc.resumeProc();

    const term = try exe_proc.waitProc();
    // TODO - do smthing with this
    _ = term;
}

pub fn main() anyerror!void {
    var b = UScriptBuilder.init(std.heap.c_allocator);
    defer b.deinit();

    try compileUScript(&b, ue3_flavour.buildContext());

    {
        const ctx = ue3_flavour.runContext();
        try runUScript(&b, ctx);    
    }
}
