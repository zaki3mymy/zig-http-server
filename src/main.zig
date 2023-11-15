const std = @import("std");
const http = std.http;
const log = std.log;

const datetime = @import("./util/datetime.zig");
const logging = @import("./util/logger.zig").logging;
const files = @import("./files.zig");

pub fn main() !void {
    var server = http.Server.init(std.heap.page_allocator, .{ .reuse_address = true });
    defer server.deinit();

    try server.listen(try std.net.Address.parseIp("127.0.0.1", 8080));

    var out_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const absPath = try std.fs.realpath("./html", &out_buffer);
    log.info("createFileSet...", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const fileSet = try files.createFileSet(absPath, allocator);
    _ = fileSet;
    log.info("createFileSet has done.", .{});

    while (true) {
        const acceptOptions = .{ .allocator = std.heap.page_allocator, .header_strategy = .{ .dynamic = 8192 } };
        var res = try server.accept(acceptOptions);
        var res_ptr: *http.Server.Response = &res;

        const thread = try std.Thread.spawn(.{}, handler, .{res_ptr});
        thread.detach();
    }
}

fn handler(res: *http.Server.Response) !void {
    defer _ = res.reset();

    var req: http.Server.Request = res.request;
    _ = req;
    // try res.wait() catch |err| {
    //     if (err == http.Server.Request.ParseError.UnknownHttpMethod) {
    //         res.status = http.Status.method_not_allowed;
    //         std.debug.print("Unknown HTTP Method: {}.\n", .{req.method});
    //         return;
    //     }
    // };
    log.info("request from {}", .{res.address});

    if (res.wait()) {
        // logging(req.target);
    } else |err| switch (err) {
        http.Server.Request.ParseError.UnknownHttpMethod => {
            res.status = http.Status.method_not_allowed;
            res.transfer_encoding = .{ .content_length = 0 };
            try res.do();
            _ = try res.write("");
            return;
        },
        else => unreachable,
    }
    const res_body = "Hello, Zig!\n";
    res.transfer_encoding = .{ .content_length = res_body.len };
    try res.do();
    _ = try res.write(res_body);
}
