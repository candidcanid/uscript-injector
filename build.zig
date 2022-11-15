const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;

const Ue3Targets = @import("Ue3Targets.zig");
const Flavour = Ue3Targets.Flavour;

const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *std.build.Builder) !void {
    var build_details = b.addOptions();

    const ue3_flavour = b.option(Flavour, "ue3_flavour", "flavour (32bit, 64bit) of DllInjector to compile, as well as target to test against") orelse .udk32;

    build_details.addOption([]const u8, "ue3_flavour_tagstr", @tagName(ue3_flavour));

    const mode = b.standardReleaseOptions();

    const medic = b.addSharedLibrary("medic", "src/medic/dllmain.zig", .{.versioned = .{ .major = 0, .minor = 1 }});
    {
        medic.addPackage(.{
            .name = "Ue3Targets",
            .source = .{.path = "Ue3Targets.zig"},
        });
        medic.addOptions("build_details", build_details);
        medic.setTarget(ue3_flavour.crossTargetDetails());
        medic.setBuildMode(mode);
        // medic.use_stage1 = true;
        medic.use_llvm = true;

        medic.linkLibC();
        // medic.linkLibCpp();
        // medic.linkSystemLibrary("c");
        medic.linkSystemLibrary("gdi32");
        medic.linkSystemLibrary("user32");
        medic.linkSystemLibrary("psapi"); 
        medic.linkSystemLibrary("kernel32");
        // medic.linkSystemLibrary("dbghelp");
        
        medic.install();
    }

    const testdll = b.addSharedLibrary("testdll_payload", "src/testdll_main.zig", .{.versioned = .{ .major = 0, .minor = 1 }});
    {
        testdll.addPackage(.{
            .name = "Ue3Targets",
            .source = .{.path = "Ue3Targets.zig"},
        });
        testdll.addOptions("build_details", build_details);
        testdll.setTarget(ue3_flavour.crossTargetDetails());
        testdll.setBuildMode(mode);
        // testdll.use_stage1 = true;
        testdll.use_llvm = true;

        testdll.linkLibC();
        testdll.linkSystemLibrary("c");
        testdll.linkSystemLibrary("gdi32");
        testdll.linkSystemLibrary("user32");
        testdll.linkSystemLibrary("psapi"); 
        testdll.linkSystemLibrary("kernel32");
        
        testdll.install();
    }

    const payload_generator_exe = b.addExecutable("payload_generator", "src/payload_generator.zig");
    {
        payload_generator_exe.addPackage(.{
            .name = "Ue3Targets",
            .source = .{.path = "Ue3Targets.zig"},
        });
        payload_generator_exe.addOptions("build_details", build_details);
        payload_generator_exe.setTarget(.{
             .cpu_arch = .x86_64,
            .os_tag = .windows,    
        });
        payload_generator_exe.setBuildMode(mode);

        payload_generator_exe.linkLibC();
        payload_generator_exe.linkLibCpp();
        payload_generator_exe.install();
    }

    const uscript_bundler_exe = b.addExecutable("uscript_bundler", "src/uscript_bundler.zig");
    {
        uscript_bundler_exe.addPackage(.{
            .name = "Ue3Targets",
            .source = .{.path = "Ue3Targets.zig"},
        });
        uscript_bundler_exe.addOptions("build_details", build_details);
        uscript_bundler_exe.setTarget(ue3_flavour.crossTargetDetails());
        uscript_bundler_exe.setBuildMode(mode);
        // uscript_bundler_exe.use_stage1 = true;
        uscript_bundler_exe.use_llvm = true;

        uscript_bundler_exe.linkLibC();
        // uscript_bundler_exe.linkLibCpp();
        // uscript_bundler_exe.linkSystemLibrary("c");
        uscript_bundler_exe.linkSystemLibrary("gdi32");
        uscript_bundler_exe.linkSystemLibrary("user32");
        uscript_bundler_exe.linkSystemLibrary("psapi"); 
        uscript_bundler_exe.linkSystemLibrary("kernel32");
        // uscript_bundler_exe.linkSystemLibrary("dbghelp");
        uscript_bundler_exe.install();
    }

    switch(native_os) {
        .windows => {
            const generate = payload_generator_exe.run();
            generate.cwd = b.build_root;
            generate.step.dependOn(b.getInstallStep());

            const run_bundler = uscript_bundler_exe.run();
            run_bundler.step.dependOn(&generate.step);
            run_bundler.cwd = b.build_root;

            b.default_step = &run_bundler.step;        
        },
        .macos => {
            const parallels_vmid = b.option([]const u8, "parallels_vmid", "Parallels VM name for connection") orelse return error.MissingParallelsVMIdent;
            const parallels_share_root = b.option([]const u8, "parallels_shareroot", "full shared-directory path to this build.zig") orelse return error.MissingParallelsShareRoot;

            const run_bundler = b.addSystemCommand(&.{
                "prlctl", "exec", parallels_vmid, "-r", "--current-user", 
                "powershell", "-NonInteractive", "-NoProfile", "-File", b.fmt("{s}\\win\\Deploy.ps1", .{parallels_share_root}), parallels_share_root
            });
            run_bundler.expected_exit_code = null;
            run_bundler.step.dependOn(b.getInstallStep());

            std.log.info("Parallels({s}, {s})", .{parallels_vmid, parallels_share_root});
            b.default_step = &run_bundler.step;
        },  
        else => unreachable,
    }
}
