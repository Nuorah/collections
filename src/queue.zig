const std = @import("std");
const testing = std.testing;

pub const Queue = struct {
    const Self = @This();

    const default_capacity = 8;

    items: []u32,
    head: usize = 0,
    tail: usize = 0,
    len: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .items = try allocator.alloc(u32, default_capacity),
        };
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
    }

    pub fn enqueue(self: *Self, allocator: std.mem.Allocator, elem: u32) !void {
        if (self.head == self.tail and self.len != 0) { // Queue full, resize
            var new_items = try allocator.alloc(u32, self.items.len * 2);
            var i: usize = 0;
            while (i < self.len) : (i += 1) {
                new_items[i] = self.items[(self.head + i) % self.items.len];
            }
            allocator.free(self.items);
            self.items = new_items;
            self.head = 0;
            self.tail = self.len;
        }
        self.items[self.tail] = elem;
        self.tail = (self.tail + 1) % self.items.len;
        self.len += 1;
    }

    pub fn dequeue(self: *Self) ?u32 {
        if (self.len == 0) return null;
        const result = self.items[self.head];
        self.head = (self.head + 1) % self.items.len;
        self.len = self.len - 1;
        return result;
    }

    pub fn peek(self: *const Self) ?u32 {
        if (self.len == 0) return null;
        return self.items[self.head];
    }

    pub fn isEmpty(self: *const Self) bool {
        return self.len == 0;
    }
};

test "init and isEmpty" {
    var queue = try Queue.init(testing.allocator);
    defer queue.deinit(testing.allocator);
    try testing.expect(queue.isEmpty());
}

test "enqueue and peek" {
    var queue = try Queue.init(testing.allocator);
    defer queue.deinit(testing.allocator);
    try queue.enqueue(testing.allocator, 42);
    try testing.expect(!queue.isEmpty());
    try testing.expectEqual(@as(?u32, 42), queue.peek());
    try testing.expectEqual(@as(usize, 1), queue.len);
}

test "enqueue and dequeue single" {
    var queue = try Queue.init(testing.allocator);
    defer queue.deinit(testing.allocator);
    try queue.enqueue(testing.allocator, 10);
    const result = queue.dequeue();
    try testing.expectEqual(@as(?u32, 10), result);
    try testing.expect(queue.isEmpty());
}

test "FIFO order" {
    var queue = try Queue.init(testing.allocator);
    defer queue.deinit(testing.allocator);
    try queue.enqueue(testing.allocator, 1);
    try queue.enqueue(testing.allocator, 2);
    try queue.enqueue(testing.allocator, 3);
    try testing.expectEqual(@as(?u32, 1), queue.dequeue());
    try testing.expectEqual(@as(?u32, 2), queue.dequeue());
    try testing.expectEqual(@as(?u32, 3), queue.dequeue());
}

test "dequeue empty returns null" {
    var queue = try Queue.init(testing.allocator);
    defer queue.deinit(testing.allocator);
    try testing.expectEqual(@as(?u32, null), queue.dequeue());
    try testing.expectEqual(@as(?u32, null), queue.peek());
}

test "wrap around without resize" {
    var queue = try Queue.init(testing.allocator);
    defer queue.deinit(testing.allocator);
    // fill partially, dequeue some, then enqueue more to force wrap
    try queue.enqueue(testing.allocator, 1);
    try queue.enqueue(testing.allocator, 2);
    try queue.enqueue(testing.allocator, 3);
    _ = queue.dequeue();
    _ = queue.dequeue();
    // head is now at index 2, tail at 3
    try queue.enqueue(testing.allocator, 4);
    try queue.enqueue(testing.allocator, 5);
    try queue.enqueue(testing.allocator, 6);
    try queue.enqueue(testing.allocator, 7);
    try queue.enqueue(testing.allocator, 8);
    try queue.enqueue(testing.allocator, 9);
    // tail should have wrapped around
    try testing.expectEqual(@as(?u32, 3), queue.dequeue());
    try testing.expectEqual(@as(?u32, 4), queue.dequeue());
}

test "resize preserves order" {
    var queue = try Queue.init(testing.allocator);
    defer queue.deinit(testing.allocator);
    // enqueue more than default capacity (8)
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try queue.enqueue(testing.allocator, i);
    }
    // dequeue and verify order
    i = 0;
    while (i < 10) : (i += 1) {
        try testing.expectEqual(@as(?u32, i), queue.dequeue());
    }
}

test "resize after wrap preserves order" {
    var queue = try Queue.init(testing.allocator);
    defer queue.deinit(testing.allocator);
    // partially fill
    try queue.enqueue(testing.allocator, 100);
    try queue.enqueue(testing.allocator, 200);
    try queue.enqueue(testing.allocator, 300);
    // dequeue to move head forward
    _ = queue.dequeue();
    _ = queue.dequeue();
    // now head=2, tail=3, len=1
    // enqueue enough to wrap AND trigger resize
    var i: u32 = 1;
    while (i <= 10) : (i += 1) {
        try queue.enqueue(testing.allocator, i);
    }
    // should get 300 first, then 1-10
    try testing.expectEqual(@as(?u32, 300), queue.dequeue());
    i = 1;
    while (i <= 10) : (i += 1) {
        try testing.expectEqual(@as(?u32, i), queue.dequeue());
    }
}
