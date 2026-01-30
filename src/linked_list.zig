const std = @import("std");
const testing = std.testing;

// LinkedList: Singly Linked List

const Node = struct {
    const Self = @This();
    data: u32,
    next: ?*Node,

    pub fn create(allocator: std.mem.Allocator, data: u32) !*Self {
        var node = try allocator.create(Node);
        errdefer allocator.destroy(node);
        node.data = data;
        node.next = null;
        return node;
    }

    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        if (self.next) |n| {
            n.destroy(allocator);
        }
        allocator.destroy(self);
    }

    pub fn traverse(self: Self) void {
        std.debug.print("data: {d}\n", .{self.data});
        if (self.next) |n| {
            n.traverse();
        } else {
            std.debug.print("Null node\n", .{});
        }
    }
};

pub const LinkedList = struct {
    const Self = @This();

    head: ?*Node = null,
    len: u32 = 0,

    pub fn init() !Self {
        return Self{};
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.head) |h| {
            h.destroy(allocator);
        }
    }

    pub fn prepend(self: *Self, allocator: std.mem.Allocator, data: u32) !void {
        var newNode = try Node.create(allocator, data);
        errdefer newNode.destroy(allocator);
        if (self.head) |h| {
            newNode.next = h;
        }
        self.head = newNode;
        self.len = self.len + 1;
    }

    pub fn traverse(self: Self) void {
        if (self.head) |h| {
            h.traverse();
        } else {
            std.debug.print("Null node\n", .{});
        }
    }
};

test "init and deinit empty list" {
    var v = try LinkedList.init();
    v.deinit(testing.allocator);
}

test "len starts at zero" {
    var v = try LinkedList.init();
    defer v.deinit(testing.allocator);
    try testing.expectEqual(0, v.len);
}

test "prepend single element" {
    var v = try LinkedList.init();
    defer v.deinit(testing.allocator);
    try v.prepend(testing.allocator, 42);
    try testing.expectEqual(1, v.len);
}

test "prepend multiple elements" {
    var v = try LinkedList.init();
    defer v.deinit(testing.allocator);
    try v.prepend(testing.allocator, 1);
    try v.prepend(testing.allocator, 2);
    try v.prepend(testing.allocator, 3);
    try testing.expectEqual(3, v.len);
}

test "prepend adds to front" {
    var v = try LinkedList.init();
    defer v.deinit(testing.allocator);
    try v.prepend(testing.allocator, 1);
    try v.prepend(testing.allocator, 2);
    try v.prepend(testing.allocator, 3);
    // head should be 3
    try testing.expectEqual(3, v.head.?.data);
    // next should be 2
    try testing.expectEqual(2, v.head.?.next.?.data);
    // then 1
    try testing.expectEqual(1, v.head.?.next.?.next.?.data);
    // then null
    try testing.expectEqual(null, v.head.?.next.?.next.?.next);
}

test "traverse prints" {
    var v = try LinkedList.init();
    defer v.deinit(testing.allocator);
    try v.prepend(testing.allocator, 1);
    try v.prepend(testing.allocator, 2);
    try v.prepend(testing.allocator, 3);
    v.traverse(); // visual check, just don't crash
}

test "deinit frees all nodes" {
    var v = try LinkedList.init();
    for (0..100) |i| {
        try v.prepend(testing.allocator, @intCast(i));
    }
    v.deinit(testing.allocator);
    // testing.allocator screams if leaks
}
