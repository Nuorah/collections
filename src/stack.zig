const std = @import("std");
const testing = std.testing;

pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        const default_capacity: usize = 8;

        items: []T,
        len: usize = 0,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{
                .items = try allocator.alloc(T, default_capacity),
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.items);
        }

        pub fn push(self: *Self, allocator: std.mem.Allocator, elem: T) !void {
            if (self.items.len == self.len) {
                var new_items = try allocator.alloc(T, self.items.len * 2);
                for (self.items, 0..) |item, i| {
                    new_items[i] = item;
                }
                allocator.free(self.items);
                self.items = new_items;
            }
            self.items[self.len] = elem;
            self.len = self.len + 1;
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            self.len = self.len - 1;
            return self.items[self.len];
        }

        pub fn peek(self: *const Self) ?T {
            if (self.len == 0) return null;
            return self.items[self.len - 1];
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }
    };
}

test "init and deinit" {
    var p = try Stack(u32).init(testing.allocator);
    p.deinit(testing.allocator);
}

test "isEmpty on new stack" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try testing.expect(p.isEmpty());
}

test "push single element" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try p.push(testing.allocator, 42);
    try testing.expect(!p.isEmpty());
}

test "peek returns top" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try p.push(testing.allocator, 42);
    try testing.expectEqual(@as(?u32, 42), p.peek());
}

test "peek does not remove" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try p.push(testing.allocator, 42);
    _ = p.peek();
    _ = p.peek();
    try testing.expect(!p.isEmpty());
}

test "pop returns top" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try p.push(testing.allocator, 42);
    try testing.expectEqual(@as(?u32, 42), p.pop());
}

test "pop removes element" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try p.push(testing.allocator, 42);
    _ = p.pop();
    try testing.expect(p.isEmpty());
}

test "LIFO order" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try p.push(testing.allocator, 1);
    try p.push(testing.allocator, 2);
    try p.push(testing.allocator, 3);
    try testing.expectEqual(@as(?u32, 3), p.pop());
    try testing.expectEqual(@as(?u32, 2), p.pop());
    try testing.expectEqual(@as(?u32, 1), p.pop());
}

test "pop empty returns null" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try testing.expectEqual(@as(?u32, null), p.pop());
}

test "peek empty returns null" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    try testing.expectEqual(@as(?u32, null), p.peek());
}

test "push many elements" {
    var p = try Stack(u32).init(testing.allocator);
    defer p.deinit(testing.allocator);
    for (0..100) |i| {
        try p.push(testing.allocator, @intCast(i));
    }
    try testing.expectEqual(@as(?u32, 99), p.peek());
}
