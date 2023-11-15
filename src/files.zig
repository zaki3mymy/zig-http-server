const std = @import("std");

pub const Kind = std.fs.File.Kind;

pub fn createFileSet(absPath: []const u8, allocator: std.mem.Allocator) !std.BufSet {
    var fileSet = std.BufSet.init(allocator);

    const dir = try std.fs.openIterableDirAbsolute(absPath, .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const walkAllocator = gpa.allocator();
    var walker = try dir.walk(walkAllocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            Kind.directory => {},
            Kind.file => {
                // The URL path starts with '/', so add '/' to the beginning of the path.
                const concatAllocator = gpa.allocator();
                const length = 1 + entry.path.len;
                const path = try concatAllocator.alloc(u8, length);
                path[0] = '/';
                std.mem.copy(u8, path[1..length], entry.path);
                try fileSet.insert(path);
                concatAllocator.free(path);
            },
            else => unreachable,
        }
    }

    return fileSet;
}

test "createFileSet" {
    // prepare
    const cwd = std.fs.cwd();
    // ut-test/
    //   + js/
    //   |  + foo.js
    //   + css/
    //   |  + bar.css
    //   + index.html
    var testDir = "ut-test";
    try cwd.makeDir(testDir);
    try cwd.makeDir(testDir ++ "/js");
    try cwd.makeDir(testDir ++ "/css");
    _ = try cwd.createFile(testDir ++ "/index.html", .{});
    _ = try cwd.createFile(testDir ++ "/js/foo.js", .{});
    _ = try cwd.createFile(testDir ++ "/css/bar.css", .{});
    defer cwd.deleteTree(testDir) catch undefined;

    // execute
    var out_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const absPath = try std.fs.realpath(testDir, &out_buffer);
    std.debug.print("{s}\n", .{absPath});
    var fileSet = try createFileSet(absPath, std.testing.allocator);
    defer fileSet.deinit();

    // verify
    try std.testing.expect(fileSet.contains("/index.html"));
    try std.testing.expect(fileSet.contains("/js/foo.js"));
    try std.testing.expect(fileSet.contains("/css/bar.css"));
    try std.testing.expect(fileSet.count() == 3);
}
