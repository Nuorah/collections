const std = @import("std");

const Vec3 = @import("vec.zig").Vec3;

const Box = struct {
    min: Vec3,
    max: Vec3,
};

const Triangle = struct {
    points: [3]Vec3,
};

const NodeData = union(enum) {
    leaf: []Triangle,
    internal: struct { left: *Node, right: *Node },
};

const Node = struct {
    data: NodeData,
    box: Box,
};

pub const BoundingVolumeHierarchy = struct {
    const Self = @This();

    root: ?*Node,

    pub fn init(allocator: std.mem.Allocator, triangles: []const Triangle, max_depth: usize) !Self {}

    pub fn initHelper(allocator: std.mem.Allocator, triangles: []const Triangle, depth: usize, max_depth: usize) !Node {}
};
