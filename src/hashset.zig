const std = @import("std");
const testing = std.testing;
const ArrayList = @import("array_list.zig").ArrayList;

pub fn HashSet(comptime T: type, comptime hashFn: fn (T) u64, comptime eqlFn: fn (T, T) bool) type {
    return struct {
        const Self = @This();
        const default_bucket_count = 8;
        buckets: []ArrayList(T),
        count: usize = 0,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const buckets = try allocator.alloc(ArrayList(T), default_bucket_count);
            errdefer allocator.free(buckets);
            var initialized: usize = 0;
            errdefer {
                for (buckets[0..initialized]) |*b| {
                    b.deinit(allocator);
                }
            }
            for (buckets) |*bucket| {
                bucket.* = try ArrayList(T).init(allocator);
                initialized += 1;
            }
            return Self{
                .buckets = buckets,
            };
        }

        // You need to free entries independently
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            for (self.buckets) |*bucket| {
                bucket.deinit(allocator);
            }
            allocator.free(self.buckets);
        }

        fn resize(self: *Self, allocator: std.mem.Allocator) !void {
            const new_buckets = try allocator.alloc(ArrayList(T), self.buckets.len * 2);
            errdefer allocator.free(new_buckets);
            var initialized: usize = 0;
            errdefer {
                for (new_buckets[0..initialized]) |*b| {
                    b.deinit(allocator);
                }
            }
            for (new_buckets) |*bucket| {
                bucket.* = try ArrayList(T).init(allocator);
                initialized += 1;
            }
            for (self.buckets) |*bucket| {
                for (bucket.items[0..bucket.len]) |item| {
                    const index = hashFn(item) % new_buckets.len;
                    try new_buckets[index].append(allocator, item);
                }
            }
            for (self.buckets) |*bucket| {
                bucket.deinit(allocator);
            }
            allocator.free(self.buckets);
            self.buckets = new_buckets;
        }

        fn resizeAndAdd(self: *Self, allocator: std.mem.Allocator, elem: T) !void {
            const new_buckets = try allocator.alloc(ArrayList(T), self.buckets.len * 2);
            errdefer allocator.free(new_buckets);
            var initialized: usize = 0;
            errdefer {
                for (new_buckets[0..initialized]) |*b| {
                    b.deinit(allocator);
                }
            }
            for (new_buckets) |*bucket| {
                bucket.* = try ArrayList(T).init(allocator);
                initialized += 1;
            }
            for (self.buckets) |*bucket| {
                for (bucket.items[0..bucket.len]) |item| {
                    const index = hashFn(item) % new_buckets.len;
                    try new_buckets[index].append(allocator, item);
                }
            }
            const index = hashFn(elem) % new_buckets.len;
            try new_buckets[index].append(allocator, elem);
            for (self.buckets) |*bucket| {
                bucket.deinit(allocator);
            }
            allocator.free(self.buckets);
            self.buckets = new_buckets;
        }

        pub fn add(self: *Self, allocator: std.mem.Allocator, elem: T) !bool {
            if (self.contains(elem)) return false;
            const load_factor: f32 = @as(f32, @floatFromInt(self.count)) / @as(f32, @floatFromInt(self.buckets.len));
            if (load_factor > 0.75) {
                try self.resizeAndAdd(allocator, elem);
            } else {
                const index = hashFn(elem) % self.buckets.len;
                try self.buckets[index].append(allocator, elem);
            }
            self.count = self.count + 1;
            return true;
        }

        pub fn bucketContains(bucket: ArrayList(T), elem: T) bool {
            for (bucket.items[0..bucket.len]) |item| {
                if (eqlFn(item, elem)) return true;
            }
            return false;
        }

        pub fn contains(self: *const Self, elem: T) bool {
            const elem_hash = hashFn(elem);
            const index = elem_hash % self.buckets.len;
            return bucketContains(self.buckets[index], elem);
        }
    };
}

// ======
// Tests
// ======

const Point = struct {
    x: i32,
    y: i32,
};

fn hashString(s: []const u8) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(s);
    return hasher.final();
}

fn eqlString(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn hashPoint(p: Point) u64 {
    var hasher = std.hash.Wyhash.init(0);
    std.hash.autoHash(&hasher, p);
    return hasher.final();
}

fn eqlPoint(a: Point, b: Point) bool {
    return a.x == b.x and a.y == b.y;
}

fn hashU32(x: u32) u64 {
    var hasher = std.hash.Wyhash.init(0);
    std.hash.autoHash(&hasher, x);
    return hasher.final();
}

fn eqlU32(a: u32, b: u32) bool {
    return a == b;
}

fn hashI32(x: i32) u64 {
    var hasher = std.hash.Wyhash.init(0);
    std.hash.autoHash(&hasher, x);
    return hasher.final();
}

fn eqlI32(a: i32, b: i32) bool {
    return a == b;
}

test "basic add and contains" {
    const Set = HashSet(u32, hashU32, eqlU32);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    try testing.expect(try set.add(testing.allocator, 42));
    try testing.expect(set.contains(42));
    try testing.expect(!set.contains(69));
}

test "add returns false for duplicates" {
    const Set = HashSet(u32, hashU32, eqlU32);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    try testing.expect(try set.add(testing.allocator, 1337));
    try testing.expect(!try set.add(testing.allocator, 1337));
    try testing.expectEqual(@as(usize, 1), set.count);
}

test "count increments correctly" {
    const Set = HashSet(u32, hashU32, eqlU32);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    _ = try set.add(testing.allocator, 1);
    _ = try set.add(testing.allocator, 2);
    _ = try set.add(testing.allocator, 3);
    _ = try set.add(testing.allocator, 2); // duplicate

    try testing.expectEqual(@as(usize, 3), set.count);
}

test "resize triggers on load factor" {
    const Set = HashSet(u32, hashU32, eqlU32);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    for (0..10) |i| {
        _ = try set.add(testing.allocator, @intCast(i));
    }

    try testing.expectEqual(@as(usize, 10), set.count);
    try testing.expect(set.buckets.len > 8);

    for (0..10) |i| {
        try testing.expect(set.contains(@intCast(i)));
    }
}

test "works with strings" {
    const Set = HashSet([]const u8, hashString, eqlString);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    try testing.expect(try set.add(testing.allocator, "hello"));
    try testing.expect(try set.add(testing.allocator, "world"));
    try testing.expect(!try set.add(testing.allocator, "hello"));

    try testing.expect(set.contains("hello"));
    try testing.expect(set.contains("world"));
    try testing.expect(!set.contains("goodbye"));
}

test "works with structs" {
    const Set = HashSet(Point, hashPoint, eqlPoint);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    try testing.expect(try set.add(testing.allocator, .{ .x = 0, .y = 0 }));
    try testing.expect(try set.add(testing.allocator, .{ .x = 1, .y = 1 }));
    try testing.expect(!try set.add(testing.allocator, .{ .x = 0, .y = 0 }));

    try testing.expect(set.contains(.{ .x = 0, .y = 0 }));
    try testing.expect(!set.contains(.{ .x = 2, .y = 2 }));
}

test "empty set contains nothing" {
    const Set = HashSet(u32, hashU32, eqlU32);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    try testing.expect(!set.contains(0));
    try testing.expect(!set.contains(999999));
    try testing.expectEqual(@as(usize, 0), set.count);
}

test "many items with hash collisions" {
    const Set = HashSet(u32, hashU32, eqlU32);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    for (0..100) |i| {
        _ = try set.add(testing.allocator, @intCast(i * 8));
    }

    try testing.expectEqual(@as(usize, 100), set.count);

    for (0..100) |i| {
        try testing.expect(set.contains(@intCast(i * 8)));
    }
}

test "negative integers" {
    const Set = HashSet(i32, hashI32, eqlI32);
    var set = try Set.init(testing.allocator);
    defer set.deinit(testing.allocator);

    _ = try set.add(testing.allocator, -1);
    _ = try set.add(testing.allocator, -999);
    _ = try set.add(testing.allocator, 0);
    _ = try set.add(testing.allocator, 1);

    try testing.expect(set.contains(-1));
    try testing.expect(set.contains(-999));
    try testing.expect(set.contains(0));
    try testing.expect(!set.contains(-2));
}
