const std = @import("std");
const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const fs = std.fs;
const io = std.io;
const os = std.os;
const mem = std.mem;
const fmt = std.fmt;
const heap = std.heap;
const unicode = std.unicode;
const testing = std.testing;

const ArrayList = std.ArrayList;

const win_util = @import("win_util.zig");

const Ue3Targets = @import("Ue3Targets");
const Flavour = Ue3Targets.Flavour;
const ue3_flavour = Flavour.fromBuildString(@import("build_details").ue3_flavour_tagstr);

comptime {
    if (native_arch == .x86) {
        asm (
            \\ .global _tls_index
            \\ _tls_index = 0x2C
        );
    }
}

fn bakedAsmSnippet(comptime ident: []const u8, comptime asmcode: []const u8) type {
    comptime {
        const _start = std.fmt.comptimePrint("START_{s}", .{ident});
        const _end = std.fmt.comptimePrint("END_{s}", .{ident});

        return struct {
            comptime {
                asm (
                    std.fmt.comptimePrint(
                \\.global {s}
                \\{s}:
                \\{s}
                \\.global {s}
                \\{s}:
                    ,.{_start, _start, asmcode, _end, _end})
                );
            }

            fn constSlice() []const u8 {
                const start = @extern(*const u8, .{.name = std.fmt.comptimePrint("START_{s}", .{ident})});
                const end = @extern(*const u8, .{.name = std.fmt.comptimePrint("END_{s}", .{ident})});

                const size: usize = @ptrToInt(end) - @ptrToInt(start);

                return @ptrCast([*]const u8, start)[0..size];
            }
        };
    }
}

pub fn main() anyerror!void {
    var arena = heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const appdata_dir = try Ue3Targets.getAppDataPath(allocator);
    const friendly_dllpath = try Ue3Targets.uscriptFriendlyPath(allocator, try fs.path.join(allocator, &.{appdata_dir, "testdll_payload.dll"}));
    try win_util.robocopy(allocator, "zig-out\\lib", appdata_dir, .{.copy_kind = .mirror});

    inline for(.{
        "win\\CustomUDKSources\\UScriptSource\\UScriptDLLInjector\\Settings.uci",        
        "win\\CustomUDKSources\\UScriptSource\\XComDevHooks\\Settings.uci",        
        "win\\CustomUDKSources\\UScriptSource\\SimpleCustomGame\\Settings.uci",        
    }) |path| {
        try std.fs.cwd().writeFile(path, try fmt.allocPrint(allocator, 
    \\// i386 = 32bit, x86_64 = 64bit
    \\`define Arch_{s}
    \\// see RawPayloads.uc for valid flavours
    \\`define Flavour_{s}
    \\
        , .{@tagName(ue3_flavour.cpuArch()), @tagName(ue3_flavour)}));
    }

    var file = try std.fs.cwd().createFile("win\\CustomUDKSources\\UScriptSource\\UScriptDLLInjector\\Classes\\RawPayloads.uc", .{
        .truncate = true,
    });
    defer file.close();
    var buffered = std.io.bufferedWriter(file.writer());
    defer buffered.flush() catch unreachable;

    var writer = buffered.writer();
    _ = try writer.writeAll("class RawPayloads extends Object dependsOn(DataStructures);\n\n");

    const BakedSnippet = struct {
        snippet: Ue3Targets.ImageDetails.AsmSnippet,
        bytes: []const u8,
    };
    var baked_asm = std.BoundedArray(BakedSnippet, 100).init(0) catch unreachable;
    defer {
        for(baked_asm.slice()) |baked| {
            allocator.free(baked.bytes);
        }
    }

    inline for(comptime Ue3Targets.ImageDetails.asmSnippets()) |snippet| {
        const baked = bakedAsmSnippet(snippet.name, snippet.text);
        const bytes = baked.constSlice(); 

        const rem = @rem(bytes.len, 0x4);
        const num_padding_nops = 0x4 - rem;
        if(rem != 0) {
            std.log.warn("{s} is unaligned! will be adding {d} x86_64 padding NOP bytes", .{snippet.name, num_padding_nops});
        }

        var buffer = try allocator.alloc(u8, bytes.len + num_padding_nops);
        for(buffer[0..bytes.len]) |*b, idx| b.* = bytes[idx];
        for(buffer[bytes.len..]) |*b| b.* = 0x90; // x86_64 'nop'

        baked_asm.append(.{
            .snippet = snippet,
            .bytes = buffer,
        }) catch unreachable;
    }

    inline for(comptime Flavour.constSlice()) |flav| {
        try std.fmt.format(writer, "`if(`isdefined(Flavour_{s}))\n", .{@tagName(flav)});

        try std.fmt.format(writer, "var string InjectedDllPath;\n", .{});     

        for(baked_asm.constSlice()) |baked| {
            for(baked.snippet.supported) |s_flav| {
                if(flav == s_flav) {
                    try std.fmt.format(writer, "var int {s}[{d}];\n", .{baked.snippet.uscript_name, baked.bytes.len / 0x4});     
                }
            }
        }

        inline for(comptime Ue3Targets.ImageDetails.listing()) |item| {
            const s = switch(item.kind) {
                .pointer => "Address",
                .offset => "int"
            };

            inline for(item.entries) |entry| {
                if(comptime entry.tag == flav) {
                    _ = try writer.writeAll(comptime std.fmt.comptimePrint("var {s} {s};\n", .{s, item.uscript_name}));   
                }
            }
        }

        _ = try writer.writeAll("\n");   
        _ = try writer.writeAll("defaultproperties\n{\n");   

        try std.fmt.format(writer, "    InjectedDllPath=\"{s}\";\n", .{friendly_dllpath});     

        inline for(comptime Ue3Targets.ImageDetails.listing()) |item| {
            inline for(item.entries) |entry| {
                if(comptime entry.tag == flav) {
                    switch(item.kind) {
                        .offset => {
                            _ = try writer.writeAll(comptime std.fmt.comptimePrint("    {s}=0x{x};\n", .{item.uscript_name, entry.value}));   
                        },
                        .pointer => {
                            switch(flav.cpuArch()) {
                                .x86 => {
                                    _ = try writer.writeAll(comptime std.fmt.comptimePrint("    {s}=(Low=0x{x});\n", .{item.uscript_name, entry.value}));   
                                },
                                .x86_64 => {
                                    const l = @truncate(u32, entry.value);
                                    const h = entry.value >> 32;
                                    _ = try writer.writeAll(comptime std.fmt.comptimePrint("    {s}=(Low=0x{x},High=0x{x});\n", .{item.uscript_name, l, h}));   
                                },
                                else => unreachable,
                            }
                        }
                    }                    
                }
            }
        }

        for(baked_asm.constSlice()) |baked| {
            for(baked.snippet.supported) |s_flav| {
                if(flav == s_flav) {
                    for(mem.bytesAsSlice(u32, baked.bytes)) |u32val, idx|{
                        try std.fmt.format(writer, "    {s}({d})=0x{x};\n", .{baked.snippet.uscript_name, idx, u32val});
                    }
                }
            }
        }

        _ = try writer.writeAll("}\n");   
        try std.fmt.format(writer, "`endif\n", .{});
    }

    std.log.info("payloads generated ^_^", .{});
}
