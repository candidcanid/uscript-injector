const std = @import("std");
const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const io = std.io;
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;
const heap = std.heap;
const meta = std.meta;
const debug = std.debug;
const unicode = std.unicode;

const win = os.windows;
const user32 = win.user32;
const psapi = std.os.win.psapi;
const kernel32 = win.kernel32;

const build_details = @import("build_details");

const Ue3Targets = @import("Ue3Targets");
const Flavour = Ue3Targets.Flavour;
const ue3_flavour = Flavour.fromBuildString(@import("build_details").ue3_flavour_tagstr);


pub const native_ptr_u = std.meta.Int(.unsigned, @bitSizeOf(*anyopaque));
pub const native_ptr_i = std.meta.Int(.signed, @bitSizeOf(*anyopaque));

const __HEADER_BASE = ue3_flavour.lookup(native_ptr_u, "__HEADER_BASE");

pub const Apicall: std.builtin.CallingConvention = if(native_arch == .x86)
    .Thiscall
else .Win64;

pub const ActiveRuntime = struct {
    pub var @"&FName::Names": ?native_ptr_u = null;

    pub extern "kernel32" fn VirtualAlloc(lpAddress: ?win.LPVOID, dwSize: win.SIZE_T, flAllocationType: win.DWORD, flProtect: win.DWORD) ?*win.LPVOID;
    pub extern "kernel32" fn GetModuleHandleA(?win.LPCSTR) callconv(win.WINAPI) ?win.HMODULE;
    pub extern "kernel32" fn GetProcAddress(hModule: win.HMODULE, lpProcName: win.LPCSTR) callconv(win.WINAPI) ?win.LPVOID;

    pub extern "kernel32" fn SleepEx(dwMilliseconds: i32, bAlertable: u32) callconv(win.WINAPI) i32;

    // Disables all access to the committed region of pages. An attempt to read from, write to, or execute the committed region results in an access violation.
    pub const PAGE_NOACCESS = 0x01;

    // Enables read-only access to the committed region of pages. 
    //  An attempt to write to the committed region results in an access violation. 
    //  If Data Execution Prevention is enabled, an attempt to execute code in the committed region results in an access violation.
    pub const PAGE_READONLY = 0x02;

    // Enables read-only or read/write access to the committed region of pages. 
    //  If Data Execution Prevention is enabled, attempting to execute code in the committed region results in an access violation.
    pub const PAGE_READWRITE = 0x04;

    // Enables execute access to the committed region of pages. An attempt to write to the committed region results in an access violation.
    pub const PAGE_EXECUTE = 0x10;

    // Enables execute or read-only access to the committed region of pages. An attempt to write to the committed region results in an access violation.
    pub const PAGE_EXECUTE_READ = 0x20;

    // Enables execute, read-only, or read/write access to the committed region of pages.
    pub const PAGE_EXECUTE_READWRITE = 0x40;

    pub extern "kernel32" fn VirtualProtectEx(hProcess: win.HANDLE, lpAddress: win.LPVOID, dwSize: win.SIZE_T, flNewProtect: win.DWORD, lpflOldProtect: ?*win.DWORD) callconv(win.WINAPI) win.BOOL;

    pub const Context = struct {
        var aslr_slide: ?native_ptr_u = null;

        pub fn aslrSlide() native_ptr_u {
            return aslr_slide orelse {
                var hmodule = GetModuleHandleA(null) orelse unreachable;
                std.log.debug("hmodule: {x}", .{@ptrToInt(hmodule)});
                aslr_slide = @ptrToInt(hmodule);
                 // - ImageOffsets.TargetImage.__HEADER_BASE;
                // aslr_slide = @ptrToInt(hmodule) - ImageOffsets.TargetImage.__HEADER_BASE;
                std.log.debug("aslr_slide: {x}", .{aslr_slide.?});

                return aslr_slide.?;
            };
        }

        pub fn imageCast(comptime T: type, addr: native_ptr_u) T {
            return @intToPtr(T, (addr - __HEADER_BASE) + aslrSlide());
        }
    };


    pub const MemoryStream = struct {
        base: *anyopaque,
        pos: u64 = 0,

        pub const SeekableStream = io.SeekableStream(
            *Self,
            SeekError,
            GetSeekPosError,
            seekTo,
            seekBy,
            getPos,
            getEndPos,
        );

        const Self = @This();

        pub const ReadError = error{};
        pub const SeekError = error{};
        pub const GetSeekPosError = error{};

        pub const Reader = io.Reader(*Self, ReadError, read);

        pub fn init(base: *anyopaque) MemoryStream {
            return MemoryStream{.base = base};
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn seekableStream(self: *Self) SeekableStream {
            return .{ .context = self };
        }

        pub fn read(self: *Self, dest: []u8) ReadError!usize {
            const size = std.math.min(dest.len, (self.getEndPos() catch unreachable) - self.pos);
            const end = self.pos + size;

            mem.copy(u8, dest, @ptrCast([*]u8, @alignCast(8, self.base))[@intCast(usize, self.pos)..@intCast(usize, end)]);
            self.pos = end;

            return size;
        }

        pub fn seekTo(self: *Self, pos: u64) SeekError!void {
            self.pos = pos;
        }

        pub fn seekBy(self: *Self, amt: i64) SeekError!void {
            if (amt < 0) {
                const abs_amt = std.math.absCast(amt);
                const abs_amt_usize = std.math.cast(usize, abs_amt) orelse std.math.maxInt(usize);
                if (abs_amt_usize > self.pos) {
                    self.pos = 0;
                } else {
                    self.pos -= abs_amt_usize;
                }
            } else {
                const amt_usize = std.math.cast(usize, amt) orelse std.math.maxInt(usize);
                const new_pos = std.math.add(usize, @intCast(usize, self.pos), amt_usize) catch std.math.maxInt(usize);
                self.pos = std.math.min(self.getEndPos() catch unreachable, new_pos);
            }
        }

        pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
            _ = self;
            return std.math.maxInt(u64);
        }

        pub fn getPos(self: *Self) GetSeekPosError!u64 {
            return self.pos;
        }

        // pub fn getWritten(self: Self) Buffer {
        //     return self.buffer[0..self.pos];
        // }

        pub fn reset(self: *Self) void {
            self.pos = 0;
        }
    };

    const _IMAGE_OPTIONAL_HEADER64 = extern struct {
        const IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;

        Magic: u16,
        MajorLinkerVersion: u8,
        MinorLinkerVersion: u8,
        SizeOfCode: u32,
        SizeOfInitializedData: u32,
        SizeOfUninitializedData: u32,
        AddressOfEntryPoint: u32,
        BaseOfCode: u32,
        ImageBase: u64,
        SectionAlignment: u32,
        FileAlignment: u32,
        MajorOperatingSystemVersion: u16,
        MinorOperatingSystemVersion: u16,
        MajorImageVersion: u16,
        MinorImageVersion: u16,
        MajorSubsystemVersion: u16,
        MinorSubsystemVersion: u16,
        Win32VersionValue: u32,
        SizeOfImage: u32,
        SizeOfHeaders: u32,
        CheckSum: u32,
        Subsystem: u16,
        DllCharacteristics: u16,
        SizeOfStackReserve: u64,
        SizeOfStackCommit: u64,
        SizeOfHeapReserve: u64,
        SizeOfHeapCommit: u64,
        LoaderFlags: u32,
        NumberOfRvaAndSizes: u32,
        IMAGE_DATA_DIRECTORY: [IMAGE_NUMBEROF_DIRECTORY_ENTRIES]_IMAGE_DATA_DIRECTORY,
    };

    const _IMAGE_EXPORT_DIRECTORY = extern struct {
        Characteristics: u32,
        TimeDateStamp: u32,
        MajorVersion: u16,
        MinorVersion: u16,
        Name: u32,
        Base: u32,
        NumberOfFunctions: u32,
        NumberOfNames: u32,
        AddressOfFunctions: u32,
        AddressOfNames: u32,
        AddressOfNameOrdinals: u32,
    };

    const _IMAGE_DATA_DIRECTORY = extern struct {
        VirtualAddress: u32,
        Size: u32,
    };

    pub fn manualLoadLibraryA(hmodule: win.HMODULE, sym: []const u8) !win.LPVOID {
        var stream = MemoryStream.init(@ptrCast(*anyopaque, hmodule));

        const DOS_HEADER = extern struct {
            e_magic: u16,
            _padding: u16,
            _ignore: [14]u32,
            e_lfanew: u32,
        };
        comptime debug.assert(@offsetOf(DOS_HEADER, "e_lfanew") == 0x40 - 0x4);

        const PEFileHeader = extern struct {
            signature: u32,
            machine: u16,
            number_of_sections: u16,
            _ignore: [3]u32,
            size_of_optional_header: u16,
            characteristics: u16,
        };

        const dos_header = try stream.reader().readStruct(DOS_HEADER);
        if(dos_header.e_magic != mem.bytesToValue(u16, "MZ")) return error.InvalidDOSMagic;

        try stream.seekableStream().seekTo(dos_header.e_lfanew);

        const pefile_header = try stream.reader().readStruct(PEFileHeader);
        // std.log.info("{s}", .{pefile_header.signature});
        // std.log.info("{x}", .{pefile_header.signature});

        // if(!mem.eql(u8, pefile_header.signature[0..], "PE\x00\x00")) return error.InvalidPEMagic;
        if(pefile_header.signature != mem.bytesToValue(u32, "PE\x00\x00")) return error.InvalidPEMagic;

        const optional = try stream.reader().readStruct(_IMAGE_OPTIONAL_HEADER64);

        // for(optional.IMAGE_DATA_DIRECTORY) |datadir, idx| {
        //     std.log.info("({d}) {x},{x}", .{idx, datadir.VirtualAddress, datadir.Size});    
        // }

        try stream.seekableStream().seekTo(optional.IMAGE_DATA_DIRECTORY[0].VirtualAddress);

        const export_dir = try stream.reader().readStruct(_IMAGE_EXPORT_DIRECTORY);

        {
            
            var c: usize = 0;
            // var off: usize = 0;
            // try stream.seekableStream().seekTo(export_dir.Name);
            // var scratch: [512]u8 = undefined;
            // var total = try stream.reader().readUntilDelimiter(scratch[0..], 0);
            // // debug.assert(total.len != 0);
            // std.log.info("export.Name = {s}", .{total}); 

            while(c < export_dir.NumberOfNames) : (c += 1) {
                try stream.seekableStream().seekTo(export_dir.AddressOfNames + (c * @sizeOf(u32)));
                const name_ptr = try stream.reader().readIntLittle(u32);

                try stream.seekableStream().seekTo(name_ptr);
                var scratch: [512]u8 = undefined;
                var total = try stream.reader().readUntilDelimiter(scratch[0..], 0);
                // std.log.info("export.Name[{d}] = {x}:{s}", .{c, name_ptr, total}); 

                if(mem.eql(u8, total, sym)) {
                    try stream.seekableStream().seekTo(export_dir.AddressOfNameOrdinals + (c * @sizeOf(u16)));
                    const ordinal = try stream.reader().readIntLittle(u16);
                    std.log.debug("symbol identified - {s}({d}) - ordinal = {d}", .{sym, c, ordinal});
                    
                    try stream.seekableStream().seekTo(export_dir.AddressOfFunctions + (ordinal * @sizeOf(u32)));
                    const func_rva = try stream.reader().readIntLittle(u32);
                    return @intToPtr(*anyopaque, @ptrToInt(hmodule) + func_rva);
                }

            } else return error.FailedToFindExportedSymbol;
        }
    }

    const MallableMemoryView = struct {
        handle: win.HANDLE, 
        old_protections: u32,
        
        addr: *anyopaque, 
        size: usize, 

        pub fn init(addr: *anyopaque, size: usize) anyerror!MallableMemoryView {
            var handle = kernel32.GetCurrentProcess();
            std.log.debug("handle: {}", .{handle});

            var old_protections: u32 = undefined;
            const winret = ActiveRuntime.VirtualProtectEx(handle, addr, size, ActiveRuntime.PAGE_EXECUTE_READWRITE, &old_protections);
            if(winret == 0) {
                std.log.err("failed to protect memory region {x}, err = {d}", .{@ptrToInt(addr), winret});
                return error.WINAPI_FailedVirtualProtectEx;
            }
                
            return MallableMemoryView{
                .handle = handle,
                .old_protections = old_protections,
                .addr = addr,
                .size = size,
            };
        }

        pub fn deinit(self: MallableMemoryView) void {
            var _protections: u32 = undefined;
            const winret = ActiveRuntime.VirtualProtectEx(self.handle, self.addr, self.size, self.old_protections, &_protections);
            if(winret == 0) {
                std.debug.panic("failed to reprotect memory region {x}, err = {d}", .{@ptrToInt(self.addr), winret});
            }
        }
    };

    pub fn patchMemoryAtAddress(comptime T: type, address: *T, val: T) !void {
        const mask: std.meta.Int(.unsigned, @bitSizeOf(*anyopaque)) = (1 << 12) - 1;
        comptime {
            const test_addr = 0x01C1506C;
            debug.assert(test_addr & mask == 0x6c);
            debug.assert(test_addr & ~mask == 0x01C15000);
            // @compileError(std.fmt.comptimePrint("{x},{x},{x}", .{addr, ~mask, mask}));
        }

        var base_addr: usize = @ptrToInt(address) & ~mask;
        std.log.info("addr: {x}/{x}", .{@ptrToInt(address), base_addr});
        var mallable_memsize: usize = mem.page_size;

        var memview = try MallableMemoryView.init(@intToPtr(*anyopaque, base_addr), mallable_memsize);
        defer memview.deinit();
        address.* = val;
    }

    pub fn patchUsingImageAddr(patch_addr: native_ptr_u, patch_val: anytype) !void {
        var ptr = Context.imageCast(*@TypeOf(patch_val), patch_addr);
        try patchMemoryAtAddress(@TypeOf(patch_val), ptr, patch_val);
    }

    // if(mem.eql(u8, "stub_internalObjectTesting", mem.span(this.Name.entry().utf8Bytes()))) {
    //     std.log.info("Bind - '{s}'", .{this.Name.entry().utf8Bytes()});
    //     @intToPtr(**anyopaque, @ptrToInt(this) + 0xF8).* = @intToPtr(*anyopaque, @ptrToInt(internalObjectTesting));
    //     @intToPtr(*u32, @ptrToInt(this) + 0xD0).* = @intToPtr(*u32, @ptrToInt(this) + 0xD0).* | 0x400;
    //     @intToPtr(*u32, @ptrToInt(this) + 0x124).* = @intToPtr(*u32, @ptrToInt(this) + 0x124).* | 0x4000;
    // }

    var has_registered_overrides: bool = false;

    pub fn registerUScriptOverrides(ufunction_patchaddr: native_ptr_u, comptime OverrideNamespace: type) !void {
        if(has_registered_overrides) return error.CannotRegisterMoreThanOneOverrideStruct;
        has_registered_overrides = true;

        const CallSig = *const fn(this: *UObject) callconv(Apicall) *anyopaque;

        const Octx = struct {
            var original_bind_addr: ?CallSig = null;

            fn BindUsingOverrides(this: *UObject) callconv(Apicall) *anyopaque {
                // call native UFunction::Bind before patching
                const retval = original_bind_addr.?(this);

                var stack_scratch: [512]u8 = undefined;
                var fba = heap.FixedBufferAllocator.init(stack_scratch[0..]);
            
                var ufunc_path = this.fullpathAsSliceAlloc(fba.allocator()) catch |err| {
                    std.debug.panic("BindUsingOverrides({x}) - failed to get UObject fullpath! err = {s}", .{@ptrToInt(this), @errorName(err)});
                };

                inline for(@typeInfo(OverrideNamespace).Struct.decls) |decl| {
                    if(mem.eql(u8, ufunc_path, decl.name)) {      
                        std.log.info("Binding - '{s}'", .{ufunc_path});


                        @intToPtr(**anyopaque, @ptrToInt(this) + ue3_flavour.lookup(u32, "off_UFunction.Func")).* = @intToPtr(*anyopaque, @ptrToInt(&@field(OverrideNamespace, decl.name)));
                        @intToPtr(*u32, @ptrToInt(this) + ue3_flavour.lookup(u32, "off_UFunction.LowFlags")).* = @intToPtr(*u32, @ptrToInt(this) + ue3_flavour.lookup(u32, "off_UFunction.LowFlags")).* | 0x400;
                        @intToPtr(*u32, @ptrToInt(this) + ue3_flavour.lookup(u32, "off_UFunction.HighFlags")).* = @intToPtr(*u32, @ptrToInt(this) + ue3_flavour.lookup(u32, "off_UFunction.HighFlags")).* | 0x4000;
                        break;
                    }
                }

                return retval;
            }
        };

        Octx.original_bind_addr = Context.imageCast(*CallSig, ufunction_patchaddr).*;
        try patchUsingImageAddr(ufunction_patchaddr, &Octx.BindUsingOverrides);
    }
};

pub fn TArray(comptime T: type) type {
    return extern struct {
        const Self = @This();

        data: [*]T,
        length: u32,
        capacity: u32,

        pub fn slice(self: *Self) []T {
            return self.data[0..self.length];
        }
    };
}

pub const FString = extern struct {
    array: TArray(u16),

    /// caller responsible for freeing returned memory
    pub fn utf8SliceAlloc(self: *FString, allocator: mem.Allocator) ![]u8 {
        return try unicode.utf16leToUtf8Alloc(allocator, self.array.slice());
    }
};

pub const FName = extern struct {
    const Self = @This();

    pub fn Names() *TArray(*FNameEntry) {
        return ActiveRuntime.Context.imageCast(*TArray(*FNameEntry), ActiveRuntime.@"&FName::Names" orelse std.debug.panic("&FName::Names image-offset not defined!", .{}));
    }   

    index: i32,
    suffix: i32,

    pub fn entry(self: Self) *FNameEntry {
        // std.log.info("Names[{x}, {d},{d}]", .{@ptrToInt(Names().data), Names().length, Names().capacity});
        return Names().slice()[@intCast(u32, self.index)];
    }
};

pub const FNameEntry = extern struct {
    const Self = @This();
    const NAME_SIZE = 1024;

    Flags: u64,
    Index: u32 align(4), // holds flag as 1 byte (odd = utf16, even = utf8), * 2 to get index
    HashNext: *anyopaque align(4),
    Data: extern union {
        AnsiName: [NAME_SIZE]u8,
        UniName: [NAME_SIZE]u16,
    },

    pub fn utf8Bytes(self: *const FNameEntry) [*:0]const u8 {
        return @ptrCast([*:0]const u8, &self.Data.AnsiName);
    }
};

pub const UObject = extern struct {
    vtable: *anyopaque, 
    Index: i32,
    EObjectFlags: u64,
    HashNext: ?*UObject,
    HashOuterNext: ?*UObject,
    StateFrame: ?*anyopaque, // *FStateFrame
    _Linker: ?*anyopaque, // *ULinkerLoad
    _LinkerIndex: if(native_arch == .x86) native_ptr_i else extern struct {},
    NetIndex: i32,
    Outer: ?*UObject,
    Name: FName,
    Class: ?*anyopaque, // *UClass
    ObjectArchetype: ?*UObject,

    pub fn fullpathAsSliceAlloc(this: *UObject, allocator: mem.Allocator) ![]u8 {
        var chain = std.BoundedArray(*UObject, 14).init(0) catch unreachable;
        
        var path = std.ArrayList(u8).init(allocator);
        errdefer path.deinit();

        var cur: ?*UObject = this;
        while(cur != null) : (cur = cur.?.Outer) try chain.append(cur.?);

        mem.reverse(*UObject, chain.slice());

        for(chain.slice()) |uobj, idx| {
            try fmt.format(path.writer(), "{s}", .{uobj.Name.entry().utf8Bytes()});
            if(idx != chain.slice().len - 1) {
                _ = try path.writer().write(".");
            }
        }  

        return path.toOwnedSlice();
    }
};

pub const FFrame = packed struct {
    const GNativeFuncSig = *const fn(this: ?*UObject, stack: *FFrame, result: *anyopaque) callconv(Apicall) void;

    var uscript_ctx: ?struct {
        GNatives: [*]GNativeFuncSig,
        GPropAddr: *native_ptr_u,
        GPropObject: *?*UObject,
        GProperty: *?*UObject,
    } = null;

    __vtable: *anyopaque,
    bAllowSuppression: u32,
    bSuppressEventTag: u32,
    bAutoEmitLineTerminator: u32,
    Node: ?*UObject,
    Object: ?*UObject,
    Code: [*c]align(1) u8,
    Locals: [*c]align(1) u8,
    PreviousFrame: ?*FFrame,
    OutParms: [*c]align(1) u8,

    pub fn link(nptr_GNatives: native_ptr_u, nptr_GPropAddr: native_ptr_u, nptr_GPropObject: native_ptr_u, nptr_GProperty: native_ptr_u) !void {
        uscript_ctx = .{
            .GNatives = ActiveRuntime.Context.imageCast([*]GNativeFuncSig, nptr_GNatives),
            .GPropAddr = ActiveRuntime.Context.imageCast(*native_ptr_u, nptr_GPropAddr),
            .GPropObject = ActiveRuntime.Context.imageCast(*?*UObject, nptr_GPropObject),
            .GProperty = ActiveRuntime.Context.imageCast(*?*UObject, nptr_GProperty),
        };
    }

    pub fn parseUScriptCallArgs(self: *FFrame, comptime ArgumentsType: type) !ArgumentsType {
        var allocator = heap.c_allocator;

        var ctx = uscript_ctx orelse return error.UScriptContextIsUnlinked;

        var parsed: ArgumentsType = undefined;
        inline for(meta.fields(ArgumentsType)) |item| {
            // TODO: variant that doesn't do any verification of arg-copy
            var with_padding = try allocator.alloc(u8, @sizeOf(item.field_type) + 0x30);
            for(with_padding) |*b| b.* = 0;
            defer allocator.free(with_padding);

            {
                const opcode = self.step();
                std.log.info("GNatives({x})[{x}:{x}]", .{
                    @ptrToInt(ctx.GNatives) - ActiveRuntime.Context.aslrSlide(), opcode, @ptrToInt(ctx.GNatives[opcode]) - ActiveRuntime.Context.aslrSlide(), 
                });

                ctx.GNatives[opcode](self.Object, self, with_padding.ptr);
                ctx.GPropAddr.* = 0x0;

                @field(parsed, item.name) = @ptrCast(*align(1) item.field_type, with_padding).*;
            }
        }

        _ = self.step();

        return parsed;
    }

    pub fn step(self: *FFrame) u8 {
        const opcode = self.Code[0];
        self.*.Code = @intToPtr([*c]align(1) u8, @ptrToInt(self.Code) + 1); 
        return opcode;
    }

    pub fn peek(self: FFrame) u8 {
        return self.Code[0];
    }
};

const Generic = packed struct {
    vtable: *anyopaque,
};
