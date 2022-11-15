const std = @import("std");

const Ue3Targets = @import("Ue3Targets");

test "basic" {
	_ = Ue3Targets.ImageDetails.listing();


	// std.testing.refAllDecls(@import("payload_generator.zig"));
}