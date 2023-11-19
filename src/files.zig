const std = @import("std");

pub const Kind = std.fs.File.Kind;

pub fn createFileMap(absPath: []const u8, allocator: std.mem.Allocator) !std.BufMap {
    var fileMap = std.BufMap.init(allocator);

    const dir = try std.fs.openIterableDirAbsolute(absPath, .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const walkAllocator = gpa.allocator();
    var walker = try dir.walk(walkAllocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            Kind.directory => {},
            Kind.file => {
                // read file
                const concatAllocator1 = gpa.allocator();
                const length1 = absPath.len + 1 + entry.path.len;
                const path1 = try concatAllocator1.alloc(u8, length1);
                std.mem.copy(u8, path1[0..absPath.len], absPath);
                path1[absPath.len] = '/';
                std.mem.copy(u8, path1[absPath.len + 1 .. length1], entry.path);
                defer concatAllocator1.free(path1);

                const fileAllocator = std.heap.page_allocator;
                const contents = try readFile(path1, fileAllocator);
                defer fileAllocator.free(contents);

                // The URL path starts with '/', so add '/' to the beginning of the path.
                const concatAllocator2 = gpa.allocator();
                const length2 = 1 + entry.path.len;
                const path2 = try concatAllocator2.alloc(u8, length2);
                path2[0] = '/';
                std.mem.copy(u8, path2[1..length2], entry.path);
                defer concatAllocator2.free(path2);

                try fileMap.put(path2, contents);
            },
            else => unreachable,
        }
    }

    return fileMap;
}

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const fileSize = try file.getEndPos();

    var reader = std.io.bufferedReader(file.reader());
    var instream = reader.reader();

    const contents = try instream.readAllAlloc(allocator, fileSize);

    return contents;
}

test "createFileMap" {
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
    var fileMap = try createFileMap(absPath, std.testing.allocator);
    defer fileMap.deinit();

    // verify
    try std.testing.expect(fileMap.count() == 3);
    // try std.testing.expect(std.mem.eql(u8, "", fileMap.get("index.html") orelse "error"));
    // try std.testing.expect(fileMap.get("/index.html"));
    // try std.testing.expect(fileMap.get("/js/foo.js"));
    // try std.testing.expect(fileMap.get("/css/bar.css"));
}
