const std = @import("std");
const testing = std.testing;

pub fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();
        const default_capacity = 8;
        items: []T,
        len: usize = 0,
        capacity: usize = default_capacity,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{
                .items = try allocator.alloc(T, default_capacity),
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.items);
        }

        pub fn append(self: *Self, allocator: std.mem.Allocator, elem: T) !void {
            if (self.capacity == self.len) {
                var new_items = try allocator.alloc(T, self.capacity * 2);
                errdefer allocator.free(new_items);
                for (self.items[0..self.len], 0..) |item, i| {
                    new_items[i] = item;
                }
                allocator.free(self.items);
                self.items = new_items;
                self.capacity = self.capacity * 2;
            }
            self.items[self.len] = elem;
            self.len = self.len + 1;
        }

        pub fn get(self: Self, index: usize) !T {
            if (index >= self.len) {
                return error.OutOfBounds;
            }
            return self.items[index];
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

test "init and deinit" {
    var list = try ArrayList(u32).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), list.len);
    try testing.expectEqual(@as(usize, 8), list.capacity);
}

test "append single element" {
    var list = try ArrayList(u32).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 42);

    try testing.expectEqual(@as(usize, 1), list.len);
    try testing.expectEqual(@as(u32, 42), try list.get(0));
}

test "append multiple elements" {
    var list = try ArrayList(u32).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 1);
    try list.append(testing.allocator, 2);
    try list.append(testing.allocator, 3);

    try testing.expectEqual(@as(usize, 3), list.len);
    try testing.expectEqual(@as(u32, 1), try list.get(0));
    try testing.expectEqual(@as(u32, 2), try list.get(1));
    try testing.expectEqual(@as(u32, 3), try list.get(2));
}

test "get out of bounds returns error" {
    var list = try ArrayList(u32).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 69);

    try testing.expectError(error.OutOfBounds, list.get(1));
    try testing.expectError(error.OutOfBounds, list.get(999));
}

test "get on empty list returns error" {
    var list = try ArrayList(u32).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try testing.expectError(error.OutOfBounds, list.get(0));
}

test "resize triggers when capacity reached" {
    var list = try ArrayList(u32).init(testing.allocator);
    defer list.deinit(testing.allocator);

    // default capacity is 8, fill it up
    for (0..8) |i| {
        try list.append(testing.allocator, @intCast(i));
    }

    try testing.expectEqual(@as(usize, 8), list.len);
    try testing.expectEqual(@as(usize, 8), list.capacity);

    // this should trigger resize
    try list.append(testing.allocator, 99);

    try testing.expectEqual(@as(usize, 9), list.len);
    try testing.expectEqual(@as(usize, 16), list.capacity);

    // verify all elements survived
    for (0..8) |i| {
        try testing.expectEqual(@as(u32, @intCast(i)), try list.get(i));
    }
    try testing.expectEqual(@as(u32, 99), try list.get(8));
}

test "multiple resizes" {
    var list = try ArrayList(u32).init(testing.allocator);
    defer list.deinit(testing.allocator);

    // add 50 elements, should trigger multiple resizes
    // 8 -> 16 -> 32 -> 64
    for (0..50) |i| {
        try list.append(testing.allocator, @intCast(i));
    }

    try testing.expectEqual(@as(usize, 50), list.len);
    try testing.expectEqual(@as(usize, 64), list.capacity);

    for (0..50) |i| {
        try testing.expectEqual(@as(u32, @intCast(i)), try list.get(i));
    }
}

test "works with different types - i32" {
    var list = try ArrayList(i32).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, -42);
    try list.append(testing.allocator, 0);
    try list.append(testing.allocator, 42);

    try testing.expectEqual(@as(i32, -42), try list.get(0));
    try testing.expectEqual(@as(i32, 0), try list.get(1));
    try testing.expectEqual(@as(i32, 42), try list.get(2));
}

test "works with different types - f64" {
    var list = try ArrayList(f64).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 3.14159);
    try list.append(testing.allocator, 2.71828);

    try testing.expectEqual(@as(f64, 3.14159), try list.get(0));
    try testing.expectEqual(@as(f64, 2.71828), try list.get(1));
}

test "works with structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    var list = try ArrayList(Point).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, .{ .x = 10, .y = 20 });
    try list.append(testing.allocator, .{ .x = -5, .y = 100 });

    const p0 = try list.get(0);
    const p1 = try list.get(1);

    try testing.expectEqual(@as(i32, 10), p0.x);
    try testing.expectEqual(@as(i32, 20), p0.y);
    try testing.expectEqual(@as(i32, -5), p1.x);
    try testing.expectEqual(@as(i32, 100), p1.y);
}

test "works with slices" {
    var list = try ArrayList([]const u8).init(testing.allocator);
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, "hello");
    try list.append(testing.allocator, "world");

    try testing.expectEqualStrings("hello", try list.get(0));
    try testing.expectEqualStrings("world", try list.get(1));
}

test "len stays accurate after many operations" {
    var list = try ArrayList(u8).init(testing.allocator);
    defer list.deinit(testing.allocator);

    for (0..100) |_| {
        try list.append(testing.allocator, 0xFF);
    }

    try testing.expectEqual(@as(usize, 100), list.len);
}
