const std = @import("std");

pub fn main() !void {
    var server = std.http.Server.init(std.heap.page_allocator, .{ .reuse_address = true });
    defer server.deinit();

    try server.listen(try std.net.Address.parseIp("127.0.0.1", 8080));

    while (true) {
        const acceptOptions = .{ .allocator = std.heap.page_allocator, .header_strategy = .{ .dynamic = 8192 } };
        var res = try server.accept(acceptOptions);
        var res_ptr: *std.http.Server.Response = &res;

        const thread = try std.Thread.spawn(.{}, handler, .{res_ptr});
        thread.detach();
    }
}

fn handler(res: *std.http.Server.Response) !void {
    defer _ = res.reset();

    try res.wait();
    const res_body = "Hello, Zig!\n";
    res.transfer_encoding = .{ .content_length = res_body.len };
    try res.do();
    _ = try res.write(res_body);
}
