const std = @import("std");
const http = std.http;
const log = std.log;

const datetime = @import("./util/datetime.zig");
const files = @import("./files.zig");

pub fn main() !void {
    var server = http.Server.init(std.heap.page_allocator, .{ .reuse_address = true });
    defer server.deinit();

    try server.listen(try std.net.Address.parseIp("127.0.0.1", 8080));

    var out_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const absPath = try std.fs.realpath("./html", &out_buffer);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var fileMap = try files.createFileMap(absPath, allocator);
    defer fileMap.deinit();

    log.info("server start.", .{});
    while (true) {
        const acceptOptions = .{ .allocator = std.heap.page_allocator, .header_strategy = .{ .dynamic = 8192 } };
        var res = try server.accept(acceptOptions);

        if (res.wait()) {
            const thread = try std.Thread.spawn(.{}, handler, .{ &res, &fileMap });
            thread.detach();
        } else |err| switch (err) {
            http.Server.Request.ParseError.UnknownHttpMethod => {
                res.status = http.Status.method_not_allowed;
                res.transfer_encoding = .{ .content_length = 0 };
                try res.do();
                _ = try res.write("");
                continue;
            },
            else => continue,
        }
    }
}

fn handler(res: *http.Server.Response, fileMap: *std.BufMap) !void {
    defer _ = res.reset();

    var req: http.Server.Request = res.request;
    log.info("{s} {} {s} {s} {s}", .{
        datetime.now().toString(), //
        res.address, //
        @tagName(req.method), //
        req.target, //
        @tagName(req.version),
    });

    if (std.mem.eql(u8, req.target, "/")) {
        req.target = "/index.html";
    }

    if (fileMap.get(req.target)) |contents| {
        res.transfer_encoding = .{ .content_length = contents.len };
        try res.do();
        _ = try res.write(contents);
    } else {
        res.status = http.Status.not_found;
        const res_body = "Not Found.\n";
        res.transfer_encoding = .{ .content_length = res_body.len };
        try res.do();
        _ = try res.write(res_body);
    }
}
