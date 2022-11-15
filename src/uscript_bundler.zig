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
const WindowsInjectAPI = win_util.WindowsInjectAPI;

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
                // std.log.debug("{s}: {s}", .{self.name, v.*});
                if(mem.eql(u8, old, v.*)) {
                    self.allocator.free(v.*);
                    v.* = replacement;
                    break;
                }
            } else {
                std.log.err("ini:{s} cannot find '{s}' to replace with '{s}'", .{self.name, old, new});
                return error.MissingEntry;
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

        var file = dir.openFile(path, .{}) catch |err| {
            std.log.err("cannot open .ini file '{s}' got {s}", .{path, @errorName(err)});
            return err;
        };
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
        std.log.info("UDK make (1)", .{});
        var proc = ChildProcess.init(&.{ctx.sdk_exe, "MAKE", "-NOPAUSE", "-UNATTENDED"}, b.arena.allocator());
        switch(try proc.spawnAndWait()) {
            .Exited => |code| if(code != 0) return error.FailedUScriptCompile,
            else => return error.MysteryProcessSpawnError,
        }
    }
    
    std.log.info("copy in mods", .{});
    for(ctx.mods) |mod| {
        try b.robocopy(
            try b.joinPath(&.{ctx.mod_dir, mod}),
            try b.joinPath(&.{ctx.sdk_src_dir, mod}),
        .{.copy_kind = .recursive});
    }
    
    const outdir = fs.cwd().openDir(try fs.path.join(b.arena.allocator(), &.{ctx.out_dir}), .{}) catch |err| {
        std.log.err("openDir({s}): {s}", .{ctx.out_dir, @errorName(err)});
        return err;
    };

    std.log.info("open and tweak .ini file", .{});
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

        std.log.info("saving altered .ini", .{});
        try engine_ini.saveToFile(std.fs.cwd(), ctx.custom_ini.dst_ini);
        try engine_ini.saveToFile(outdir, std.fs.path.basename(ctx.custom_ini.dst_ini));
    }
    
    {
        std.log.info("UDK make (2)", .{});
        var proc = ChildProcess.init(&.{ctx.sdk_exe, "MAKE", "-NOPAUSE", "-UNATTENDED"}, b.arena.allocator());
        switch(try proc.spawnAndWait()) {
            .Exited => |code| if(code != 0) return error.FailedUScriptCompile,
            else => return error.MysteryProcessSpawnError,
        }
    }
    std.log.info("copy out compiled script packages", .{});

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
    // TODO: 'pristine' restore .. clean out any dirty .ini, mods
    var b = UScriptBuilder.init(std.heap.c_allocator);
    defer b.deinit();

    try compileUScript(&b, ue3_flavour.buildContext());

    {
        const ctx = ue3_flavour.runContext();
        try runUScript(&b, ctx);    
    }
}
