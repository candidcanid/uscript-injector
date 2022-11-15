const std = @import("std");
const meta = std.meta;

const Flavour = @import("Ue3Targets.zig").Flavour;

const Self = @This();

game_engine_dir: []const u8,
game_exe: []const u8,

sdk_root_dir: []const u8,
sdk_engine_dir: []const u8,
sdk_exe: []const u8,

pub fn forFlavour(comptime flav: Flavour) Self {
	return switch(flav) {
		.udk32 => .{
			.game_engine_dir = "C:\\Modding\\UDKInstall\\UDKGame",
			.game_exe = "C:\\Modding\\UDKInstall\\Binaries\\Win32\\UDK.exe",

			.sdk_root_dir = "C:\\Modding\\UDKInstall",
			.sdk_engine_dir = "C:\\Modding\\UDKInstall\\UDKGame",
			.sdk_exe = "C:\\Modding\\UDKInstall\\Binaries\\Win32\\UDK.exe",
		},
		.udk64 => .{
			.game_engine_dir = "C:\\Modding\\UDKInstall\\UDKGame",
			.game_exe = "C:\\Modding\\UDKInstall\\Binaries\\Win64\\UDK.exe",

			.sdk_root_dir = "C:\\Modding\\UDKInstall",
			.sdk_engine_dir = "C:\\Modding\\UDKInstall\\UDKGame",
			.sdk_exe = "C:\\Modding\\UDKInstall\\Binaries\\Win64\\UDK.exe",
		},
		.XCom_EW => .{
			.game_engine_dir = "C:\\Modding\\XCOM Enemy Unknown\\XEW\\",
			.game_exe = "C:\\Modding\\XCOM Enemy Unknown\\XEW\\Binaries\\Win32\\XComEW.exe",

			.sdk_root_dir = "C:\\Modding\\UDKInstall",
			.sdk_engine_dir = "C:\\Modding\\UDKInstall\\UDKGame",
			.sdk_exe = "C:\\Modding\\UDKInstall\\Binaries\\Win32\\UDK.exe",
		},
		.XCom2_WotC => .{
			.game_engine_dir = "C:\\Steam\\steamapps\\common\\XCOM 2\\XCom2-WarOfTheChosen\\XComGame",
			.game_exe = "C:\\Steam\\steamapps\\common\\XCOM 2\\XCom2-WarOfTheChosen\\Binaries\\Win64\\XCom2.exe",

			.sdk_root_dir = "C:\\Steam\\steamapps\\common\\XCOM 2 War of the Chosen SDK",
			.sdk_engine_dir = "C:\\Steam\\steamapps\\common\\XCOM 2 War of the Chosen SDK\\XComGame",
			.sdk_exe = "C:\\Steam\\steamapps\\common\\XCOM 2 War of the Chosen SDK\\Binaries\\Win64\\XComGame.com",
		},
	};
	}
