const std = @import("std");
const bootstrap_mod = @import("../bootstrap/root.zig");

pub fn resolveNearestExistingAncestor(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.fs.cwd().realpathAlloc(allocator, path) catch |err| switch (err) {
        error.FileNotFound => {
            const parent = std.fs.path.dirname(path) orelse return err;
            if (std.mem.eql(u8, parent, path)) return err;
            return resolveNearestExistingAncestor(allocator, parent);
        },
        else => return err,
    };
}

pub fn bootstrapRootFilename(path: []const u8) ?[]const u8 {
    if (std.fs.path.isAbsolute(path)) return null;
    const basename = std.fs.path.basename(path);
    if (!std.mem.eql(u8, basename, path)) return null;
    if (!bootstrap_mod.isBootstrapFilename(basename)) return null;
    return basename;
}

test "bootstrapRootFilename returns basename for workspace root bootstrap file" {
    try std.testing.expectEqualStrings("BOOTSTRAP.md", bootstrapRootFilename("BOOTSTRAP.md").?);
}

test "bootstrapRootFilename rejects nested and absolute paths" {
    try std.testing.expect(bootstrapRootFilename("docs/BOOTSTRAP.md") == null);

    const absolute_path = if (std.fs.path.sep == '\\')
        "C:\\workspace\\BOOTSTRAP.md"
    else
        "/workspace/BOOTSTRAP.md";
    try std.testing.expect(bootstrapRootFilename(absolute_path) == null);
}

test "resolveNearestExistingAncestor returns nearest existing parent" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("existing/child");

    const existing_path = try tmp.dir.realpathAlloc(std.testing.allocator, "existing/child");
    defer std.testing.allocator.free(existing_path);

    const missing_path = try std.fs.path.join(std.testing.allocator, &.{ existing_path, "missing", "leaf.txt" });
    defer std.testing.allocator.free(missing_path);

    const resolved = try resolveNearestExistingAncestor(std.testing.allocator, missing_path);
    defer std.testing.allocator.free(resolved);

    try std.testing.expectEqualStrings(existing_path, resolved);
}
