const std = @import("std");
const meta = std.meta;

const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;

const CrossTarget = std.zig.CrossTarget;

// caller responsible for freeing u8 slice
pub fn getCompiledDllDir(allocator: mem.Allocator) ![]u8 {
    return try fs.getAppDataDir(allocator, "UScriptDllInjector");
}       

pub fn uscriptFriendlyPath(allocator: mem.Allocator, fpath: []const u8) ![]u8 {
    var out = try allocator.alloc(u8, fpath.len * 2);
    errdefer allocator.free(out);
    var fbs = std.io.fixedBufferStream(out);

    for(fpath) |c| switch(c) {
        '/' => try fbs.writer().writeAll("\\"),
        else => try fbs.writer().writeByte(c),
    };

    return fbs.getWritten();
}

pub const Flavour = enum {
    udk32,
    udk64,
    XCom_EW,
    XCom2_WotC,

    pub fn fromBuildString(comptime mb_flav: []const u8) Flavour {
        return std.meta.stringToEnum(Flavour, mb_flav) orelse @compileError(comptime std.fmt.comptimePrint("'{s}' is not a valid flavour", .{mb_flav}));
    }

    pub fn archOSAbi(self: Flavour) []const u8 {
        return switch(self) {
            .udk32 => "x86-windows",
            .udk64 => "x86_64-windows",
            .XCom_EW => "x86-windows",
            .XCom2_WotC => "x86_64-windows",
        };
    }

    pub fn crossTargetDetails(self: Flavour) CrossTarget {
        comptime {
            @setEvalBranchQuota(100000);
            for(meta.fields(Flavour)) |field| {
                const f: Flavour = @intToEnum(Flavour, field.value);
                const obi = f.archOSAbi();

                const tgt = std.zig.CrossTarget.parse(.{.arch_os_abi = obi}) catch {
                    @compileError(std.fmt.comptimePrint("Flavour '{s}' has invalid archOSAbi '{s}", .{field.name, obi}));
                };
                _ = tgt;
            }
        }
        return std.zig.CrossTarget.parse(.{.arch_os_abi = self.archOSAbi()}) catch unreachable;
    }

    pub fn rawPointerType(comptime flav: Flavour) type {
        return switch(flav.cpuArch()) {
            .x86 => u32,
            .x86_64 => u64,
            else => unreachable,
        };
    }

    pub fn cpuArch(self: Flavour) std.Target.Cpu.Arch {
        return self.crossTargetDetails().cpu_arch orelse unreachable;
    }

    fn LookupRetType(flav: Flavour, comptime kind: ImageDetails.Kind) type {
        return switch(kind) {
            .pointer => flav.rawPointerType(),
            .offset => u32
        };
    }

    pub fn constSlice() []const Flavour {
        comptime {
            var f: [meta.fields(Flavour).len]Flavour = undefined;
            for(meta.fields(Flavour)) |field, idx| {
                f[idx] = @intToEnum(Flavour, field.value);
            }
            return &f;
        }
    }

    pub fn lookup(comptime self: Flavour, comptime cast_type: type, comptime name: []const u8) cast_type {
        if(cast_type != u32 and cast_type != u64) @compileError(
            comptime std.fmt.comptimePrint("cast_type restricted to [u32, u64], got {s}", .{@typeName(cast_type)}));

        inline for(comptime ImageDetails.listing()) |item| {
            if(comptime std.mem.eql(u8, item.name, name)) {
                inline for(item.entries) |entry| {
                    if(entry.tag == self) return @intCast(cast_type, entry.value);
                } else {
                    @compileError(comptime std.fmt.comptimePrint("'{s}' lacks listing entry for flavour {s}", .{name, @tagName(self)}));         
                }
            }
        }

        @compileError(comptime std.fmt.comptimePrint("failed to find any listing for '{s}'", .{name}));       
    }

    pub const CustomINI = struct {
        const Override = struct {
            original_entry: []const u8,
            new_entry: []const u8,
        };

        const CustomNamespace = struct {
            name: []const u8,
            operations: struct {
                append: []const []const u8 = &.{},
                override: []const Override = &.{},
            },
        };

        src_ini: []const u8,
        dst_ini: []const u8,
        items: []const CustomNamespace = &.{},
    };

    pub const BuildContext = struct {
        udk_arch: []const u8,
        udk_bin: []const u8,
        udk_install: []const u8,
        game_name: []const u8,
        
        src_dir: []const u8,
        mod_dir: []const u8,
        out_dir: []const u8,

        mods: []const []const u8,
        custom_ini: CustomINI,
    };

    pub fn buildContext(flav: Flavour) BuildContext {
        return switch(flav) {
            .udk32 => BuildContext{
                .udk_arch = "Win32",
                .udk_bin = "UDK.exe",
                .udk_install = "C:\\Modding\\UDKInstall",
                .game_name = "UDKGame",
                .src_dir = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-2011-09",
                .mod_dir = "win\\CustomUDKSources\\UScriptSource",
                .out_dir = "win\\CustomUDKSources\\UScriptSource\\Output",
                .mods = &.{
                    "UScriptDllInjector",
                    "SimpleCustomGame",
                },
                .custom_ini = .{
                    .src_ini = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-2011-09\\DefaultEngine_Original.ini", 
                    .dst_ini = "C:\\Modding\\UDKInstall\\UDKGame\\Config\\DefaultEngine.ini", 
                    .items = &.{
                        .{.name = "[UnrealEd.EditorEngine]", .operations = .{
                            .append = &.{
                                "+EditPackages=UScriptDllInjector",
                                "+EditPackages=SimpleCustomGame"
                            }   
                        }
                    }
                }}
            },
            .udk64 => BuildContext{
                .udk_arch = "Win64",
                .udk_bin = "UDK.exe",
                .udk_install = "C:\\Modding\\UDKInstall",
                .game_name = "UDKGame",
                .src_dir = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-2011-09",
                .mod_dir = "win\\CustomUDKSources\\UScriptSource",
                .out_dir = "win\\CustomUDKSources\\UScriptSource\\Output",
                .mods = &.{
                    "UScriptDllInjector",
                    "SimpleCustomGame",
                },
                .custom_ini = .{
                    .src_ini = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-2011-09\\DefaultEngine_Original.ini", 
                    .dst_ini = "C:\\Modding\\UDKInstall\\UDKGame\\Config\\DefaultEngine.ini", 
                    .items = &.{
                        .{.name = "[UnrealEd.EditorEngine]", .operations = .{
                            .append = &.{
                                "+EditPackages=UScriptDllInjector",
                                "+EditPackages=SimpleCustomGame"
                            }   
                        }
                    }
                }}
            },
            .XCom_EW => BuildContext{
                .udk_arch = "Win32",
                .udk_bin = "UDK.exe",
                .udk_install = "C:\\Modding\\UDKInstall",
                .game_name = "UDKGame",
                .src_dir = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-XComEW-2011-09",
                .mod_dir = "win\\CustomUDKSources\\UScriptSource",
                .out_dir = "win\\CustomUDKSources\\UScriptSource\\Output",
                .mods = &.{
                    "UScriptDllInjector",
                    "XComDevHooks",
                },
                .custom_ini = .{
                    .src_ini = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-2011-09\\DefaultEngine_Original.ini", 
                    .dst_ini = "C:\\Modding\\UDKInstall\\UDKGame\\Config\\DefaultEngine.ini", 
                    .items = &.{
                        .{.name = "[UnrealEd.EditorEngine]", .operations = .{
                            .append = &.{
                                "+EditPackages=UScriptDllInjector",
                                "+EditPackages=XComDevHooks"
                            }   
                        }
                    }
                }}
            },
            .XCom2_WotC => BuildContext{
                .udk_arch = "Win64",
                .udk_bin = "XComGame.com",
                .udk_install = "C:\\Steam\\steamapps\\common\\XCOM 2 War of the Chosen SDK",
                .game_name = "XComGame",
                .src_dir = "win\\CustomUDKSources\\UDK_Sources\\XCom2-WOTC-SDK",
                .mod_dir = "win\\CustomUDKSources\\UScriptSource",
                .out_dir = "win\\CustomUDKSources\\UScriptSource\\Output",
                .mods = &.{
                    "UScriptDllInjector",
                    "XComDevHooks",
                },
                .custom_ini = .{
                    .src_ini = "win\\CustomUDKSources\\UDK_Sources\\XCom2-WOTC-SDK\\XComEngine_Original.ini", 
                    .dst_ini = "C:\\Steam\\steamapps\\common\\XCOM 2 War of the Chosen SDK\\XComGame\\Config\\XComEngine.ini", 
                    .items = &.{
                        .{.name = "[UnrealEd.EditorEngine]", .operations = .{
                            .append = &.{
                                "EditPackages=UScriptDllInjector",
                                "EditPackages=XComDevHooks"
                            }   
                        }
                    }
                }}
            },
        };
    }

    pub const RunContext = struct {
        exe: []const u8,
        arguments: []const u8 = "",
        src_scriptdir: []const u8,
        dst_scriptdir: []const u8,
        custom_ini: CustomINI,
        inject_dll: ?[]const u8 = null,
    };

    pub fn runContext(flav: Flavour) RunContext {
        return switch(flav) {
            .udk32 => RunContext{
                .exe = "C:\\Modding\\UDKInstall\\Binaries\\Win32\\UDK.exe",
                .arguments = "server Entry.udk?game=SimpleCustomGame.SimpleFramework?listen=true?bIsLanMatch=true -unattended",
                .src_scriptdir = "win\\CustomUDKSources\\UScriptSource\\Output", 
                .dst_scriptdir = "C:\\Modding\\UDKInstall\\UDKGame\\Script", 
                .custom_ini = .{
                    .src_ini = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-2011-09\\DefaultEngine_Original.ini", 
                    .dst_ini = "C:\\Modding\\UDKInstall\\UDKGame\\Config\\DefaultEngine.ini", 
                    .items = &.{
                        .{.name = "[Engine.ScriptPackages]", .operations = .{
                            .append = &.{
                                "+NonNativePackages=UScriptDllInjector",
                                "+NonNativePackages=SimpleCustomGame"
                            }   
                        }}
                    }
                },
                .inject_dll = "zig-out\\lib\\medic.dll",
            },
            .udk64 => RunContext{
                .exe = "C:\\Modding\\UDKInstall\\Binaries\\Win64\\UDK.exe",
                .arguments = "server Entry.udk?game=SimpleCustomGame.SimpleFramework?listen=true?bIsLanMatch=true -unattended",
                .src_scriptdir = "win\\CustomUDKSources\\UScriptSource\\Output", 
                .dst_scriptdir = "C:\\Modding\\UDKInstall\\UDKGame\\Script", 
                .custom_ini = .{
                    .src_ini = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-2011-09\\DefaultEngine_Original.ini", 
                    .dst_ini = "C:\\Modding\\UDKInstall\\UDKGame\\Config\\DefaultEngine.ini", 
                    .items = &.{
                        .{.name = "[Engine.ScriptPackages]", .operations = .{
                            .append = &.{
                                "+NonNativePackages=UScriptDllInjector",
                                "+NonNativePackages=SimpleCustomGame"
                            }   
                        }}
                    }
                },
                .inject_dll = "zig-out\\lib\\medic.dll",
            },
            .XCom_EW => RunContext{
                .exe = "C:\\Modding\\XCOM Enemy Unknown\\XEW\\Binaries\\Win32\\XComEW.exe",
                .arguments = "-FROMLAUNCHER",
                .src_scriptdir = "win\\CustomUDKSources\\UDK_Sources\\UScriptSource\\Output", 
                .dst_scriptdir = "C:\\Modding\\UDKInstall\\UDKGame\\Script", 
                .custom_ini = .{
                    .src_ini = "win\\CustomUDKSources\\UDK_Sources\\UDKInstall-XComEW-2011-09\\XComEW_DefaultEngine_Original.ini", 
                    .dst_ini = "C:\\Modding\\XCOM Enemy Unknown\\XEW\\XComGame\\Config\\DefaultEngine.ini", 
                    .items = &.{
                        .{.name = "[Engine.ScriptPackages]", .operations = .{
                            .append = &.{
                                "+NonNativePackages=UScriptDllInjector",
                                "+NonNativePackages=XComDevHooks"
                            },
                            .override = &.{
                                CustomINI.Override{ .original_entry = "GameEngine=XComGame.XComEngine", .new_entry = "GameEngine=XComDevHooks.DevHookXComEngine" },
                            }, 
                        }}
                    }
                },
                .inject_dll = "zig-out\\lib\\medic.dll",
            },
            .XCom2_WotC => RunContext{
                .exe = "C:\\Steam\\steamapps\\common\\XCOM 2\\XCom2-WarOfTheChosen\\Binaries\\Win64\\XCom2.exe",
                .arguments = "-FROMLAUNCHER -NOSTARTUPMOVIES -WINDOWED -unattended",
                .src_scriptdir = "win\\CustomUDKSources\\UScriptSource\\Output", 
                .dst_scriptdir = "C:\\Modding\\UDKInstall\\UDKGame\\Script", 
                .custom_ini = .{
                    .src_ini = "win\\CustomUDKSources\\UDK_Sources\\XCom2-WOTC-SDK\\XComEngine_Original.ini", 
                    .dst_ini = "C:\\Steam\\steamapps\\common\\XCOM 2\\XCom2-WarOfTheChosen\\XComGame\\Config\\XComEngine.ini", 
                    .items = &.{
                        .{.name = "[Engine.ScriptPackages]", .operations = .{
                            .append = &.{
                                "+NonNativePackages=UScriptDllInjector",
                                "+NonNativePackages=XComDevHooks"
                            },   
                            .override = &.{
                                CustomINI.Override{ .original_entry = "GameEngine=XComGame.XComEngine", .new_entry = "GameEngine=XComDevHooks.DevHookXComEngine" },
                            },
                        }}
                    }
                },
                .inject_dll = "zig-out\\lib\\medic.dll",
            },
        };
    }

}; 

pub const ImageDetails = struct {
    pub const Kind = enum {pointer, offset};
    pub const Entry = struct {
        const Item = struct {
            tag: Flavour,
            value: u64,
        };

        kind: Kind,
        name: []const u8, uscript_name: []const u8,
        entries: []Item,
    };

    const EntryTuple = meta.Tuple(&[_]type{Flavour, u64});
    fn E(comptime kind: Kind, comptime name: []const u8, comptime uscript_name: []const u8, comptime in_entries: []const EntryTuple) Entry {
        comptime var _entries: [in_entries.len]Entry.Item = undefined;
        inline for(in_entries) |en, idx| {
            // do some checking on entry values
            switch(kind) {
                .pointer => {
                    const raw_ptr_type = en[0].rawPointerType();
                    if(en[1] > std.math.maxInt(raw_ptr_type)) @compileError(comptime std.fmt.comptimePrint(
                        "E(.{s}, \"{s}\", \"{s}\"): {s} - offset '0x{x}' does not fit into {s}", 
                            .{@tagName(kind), name, uscript_name, @tagName(en[0]), en[1], @typeName(raw_ptr_type)}
                    ));
                },
                .offset => {
                    if(en[1] > std.math.maxInt(u32)) @compileError(comptime std.fmt.comptimePrint(
                        "E(.{s}, \"{s}\", \"{s}\"): {s} - offset '0x{x}' doesn't fit into u32", 
                            .{@tagName(kind), name, uscript_name, @tagName(en[0]), en[1]}
                    ));
                },
            }

            _entries[idx] = .{.tag = en[0], .value = en[1]};
        }

        return .{.kind = kind, .name = name, .uscript_name = uscript_name, .entries = &_entries};
    }

    pub const AsmSnippet = struct {
        name: []const u8,
        uscript_name: []const u8,
        supported: []const Flavour,
        text: []const u8,
    };

    fn A(supported: []const Flavour, comptime name: []const u8, comptime uscript_name: []const u8, text: [:0]const u8) AsmSnippet {
        return AsmSnippet{.name = name, .uscript_name = uscript_name, .supported = supported, .text = text};
    }

    pub fn asmSnippets() []const AsmSnippet {
        return &[_]AsmSnippet{
            A(&.{.udk64, .XCom2_WotC}, "__asm_CheckRWX", "CheckRWX",
                \\__asm_CheckRWX__DATA:
                \\ .long 0x11111111
                \\ .long 0x11111111
                \\ .long 0x22222222
                \\ .long 0x22222222
                \\ .long 0x33333333
                \\ .long 0x33333333
                \\__asm_CheckRWX__ENTRY:
                \\ leaq 0xabcd, %rax
                \\ movq %rax, __asm_CheckRWX__DATA(%rip)
                \\ ret
            ),
            A(&.{.udk64, .XCom2_WotC}, "__asm_SimpleCallFuncPtr", "SimpleCallFuncPtr",
                \\__asm_SimpleCallFuncPtr__DATA:
                \\ .long 0x11111111
                \\ .long 0x11111111
                \\ .long 0x22222222
                \\ .long 0x22222222
                \\ .long 0x33333333
                \\ .long 0x33333333
                \\ __asm_SimpleCallFuncPtr__ENTRY:
                \\ push %r8
                \\ push %rcx
                \\ movq __asm_SimpleCallFuncPtr__DATA(%rip), %r8
                \\ movq (__asm_SimpleCallFuncPtr__DATA + 0x8)(%rip), %rcx
                \\ callq *%r8
                \\ movq %rax, __asm_SimpleCallFuncPtr__DATA(%rip)
                \\ pop %rcx
                \\ pop %r8
                \\ ret
                \\ nop
            )
        };
    }

    pub fn listing() []const Entry {
        return &[_]Entry{
            E(.pointer, "__HEADER_BASE", "Ptr__HEADER_BASE", &.{
                .{.udk64, 0x140000000},
                .{.udk32, 0x400000},
                .{.XCom2_WotC, 0x140000000},
                .{.XCom_EW, 0x400000},
            }),
            E(.pointer, "vtfentry[GLog::Log]", "Ptr_VftEntry_GLog_Log", &.{
                .{.udk64, 0x142297ac8},
                .{.udk32, 0x21A5EB8},
                .{.XCom2_WotC, 0x1413B1E00},
                .{.XCom_EW, 0x18A245C},
            }),
            E(.pointer, "vtfentry[UFunction::Bind]", "Ptr_VftEntry_UFunction_Bind", &.{
                .{.udk64, 0x14227cca8},
                .{.udk32, 0x2193B7C},
                .{.XCom2_WotC, 0x141388EE8},
                .{.XCom_EW, 0x188F858},
            }),
            E(.pointer, "&FName::Names", "Ptr_FName_Names", &.{
                .{.udk64, 0x143068E60},
                .{.udk32, 0x2925F00},
                .{.XCom2_WotC, 0x141DAF450},
                .{.XCom_EW, 0x1CFEF90},
            }),
            E(.pointer, "GNatives", "Ptr_GNatives", &.{
                .{.udk64, 0x142FD7F90},
                .{.XCom_EW, 0x1C6FD70},
                .{.udk32, 0x28D9050},
                .{.XCom2_WotC, 0x141C9DC40},
            }),
            E(.pointer, "GPropAddr", "Ptr_GPropAddr", &.{
                .{.udk64, 0x142FB3160},
                .{.XCom_EW, 0x1C49D5C},
                .{.udk32, 0x28B5078},
            }),
            E(.pointer, "GPropObject", "Ptr_GPropObject", &.{
                .{.udk64, 0x142FB3168},
                .{.XCom_EW, 0x1C49D60},
                .{.udk32, 0x28B507C},
            }),
            E(.pointer, "GProperty", "Ptr_GProperty", &.{
                .{.udk64, 0x142FB3130},
                .{.XCom_EW, 0x1C49D44},
                .{.udk32, 0x28B5060},
            }),
            E(.pointer, "plt[LoadLibraryA]", "Ptr_Plt_LoadLibraryA", &.{
                .{.udk64, 0x1421E3548},
                .{.XCom_EW, 0x13951E4},
                .{.udk32, 0x213D2D8},
                .{.XCom2_WotC, 0x141364710},
            }),
            E(.pointer, "plt[LoadLibraryW]", "Ptr_Plt_LoadLibraryW", &.{
                .{.udk64, 0x1421E3638},
                .{.udk32, 0x213D238},
                .{.XCom_EW, 0x1395380},
                .{.XCom2_WotC, 0x141364628},
            }),
            E(.pointer, "plt[VirtualAlloc]", "Ptr_Plt_VirtualAlloc", &.{
                .{.XCom2_WotC, 0x1413646F8},
                .{.udk64, 0x22dddddddd},
            }),
            E(.pointer, "GMalloc", "Ptr_GMalloc", &.{
                .{.udk32, 0x28B504C},
                .{.XCom_EW, 0x1C49D30},
            }),
            E(.offset, "off_UFunction_FuncMap_Data", "off_UFunction_FuncMap_Data", &.{
                .{.udk64, 0xdC},
                .{.udk32, 0x90},
                .{.XCom_EW, 0x90},
                .{.XCom2_WotC, 0xdC},
            }),
            E(.offset, "off_UFunction_FuncMap_Length", "off_UFUnction_FuncMap_Length", &.{
                .{.udk64, 0xe4},
                .{.udk32, 0x94},
                .{.XCom_EW, 0x94},
                .{.XCom2_WotC, 0xe4},
            }),
            E(.offset, "off_UFunction.LowFlags", "off_UFunction_LowFlags", &.{
                .{.udk64, 0xd0},
                .{.udk32, 0x84},
                .{.XCom_EW, 0x84},
                .{.XCom2_WotC, 0xd0},
            }),
            E(.offset, "off_UFunction.HighFlags", "off_UFunction_HighFlags", &.{
                .{.udk64, 0x124},
                .{.udk32, 0xcc},
                .{.XCom_EW, 0xcc},
                .{.XCom2_WotC, 0x124},
            }),
            E(.offset, "off_UFunction.Func", "off_UFunction_Func", &.{
                .{.udk64, 0xf8},
                .{.udk32, 0xa4},
                .{.XCom_EW, 0xa0},
                .{.XCom2_WotC, 0xf0},
            }),
            E(.pointer, "vft[UObject]", "Ptr_Vft_UObject", &.{
                .{.udk64, 0x14228fbd0},
                .{.udk32, 0x21A1A48},
                .{.XCom_EW, 0x189DFF0},
                .{.XCom2_WotC, 0x1413A7580},
            }),
            E(.pointer, "UMaterialInstance::execSetFontParameterValue", "Ptr_UMaterialInstance_execSetFontParameterValue", &.{
                .{.udk64, 0x1405BA510},
                .{.XCom2_WotC, 0x140489910},
            }),
            E(.pointer, "UMaterialInstanceTimeVarying::execSetDuration", "Ptr_UMaterialInstanceTimeVarying_execSetDuration", &.{
                .{.udk32, 0x916E40},
                .{.XCom_EW, 0x48B6E0},
            }),
        };
    }
};
