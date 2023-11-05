const std = @import("std");
const datetime = @import("./datetime.zig");

pub fn logging(msg: anytype) void {
    std.debug.print("{s}, {}\n", .{ datetime.now().toString(), msg });
}
