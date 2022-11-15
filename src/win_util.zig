const std = @import("std");

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