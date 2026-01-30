const std = @import("std");
const testing = std.testing;
const ArrayList = @import("array_list.zig").ArrayList;

pub fn HashMap(
    comptime K: type,
    comptime V: type,
    comptime hashFn: fn (K) u64,
    comptime eqlFn: fn (K, K) bool,
) type {
    return struct {
        const Entry = struct {
            key: K,
            value: V,
        };

        const Bucket = ArrayList(Entry);

        const Self = @This();
        const default_bucket_count = 8;

        buckets: []Bucket,
        count: usize = 0,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const buckets = try allocator.alloc(Bucket, default_bucket_count);
            errdefer allocator.free(buckets);
            var initialized: usize = 0;
            errdefer {
                for (buckets[0..initialized]) |*b| {
                    b.deinit(allocator);
                }
            }
            for (buckets) |*bucket| {
                bucket.* = try Bucket.init(allocator);
                initialized += 1;
            }
            return Self{
                .buckets = buckets,
            };
        }

        // You need to free entries independently.
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            for (self.buckets) |*bucket| {
                bucket.deinit(allocator);
            }
            allocator.free(self.buckets);
        }

        pub fn get(self: *const Self, key: K) ?V {
            const index: usize = hashFn(key) % self.buckets.len;
            const bucket = self.buckets[index];
            for (bucket.items[0..bucket.len]) |item| {
                if (eqlFn(item.key, key)) return item.value;
            }
            return null;
        }

        fn resizeAndPut(self: *Self, allocator: std.mem.Allocator, entry: Entry, previous_value: ?V) !void {
            const new_buckets = try allocator.alloc(Bucket, self.buckets.len * 2);
            errdefer allocator.free(new_buckets);
            var initialized: usize = 0;
            errdefer {
                for (new_buckets[0..initialized]) |*b| {
                    b.deinit(allocator);
                }
            }
            for (new_buckets) |*bucket| {
                bucket.* = try Bucket.init(allocator);
                initialized += 1;
            }
            for (self.buckets) |*bucket| {
                for (bucket.items[0..bucket.len]) |item| {
                    const index = hashFn(item.key) % new_buckets.len;
                    try new_buckets[index].append(allocator, item);
                }
            }
            const index = hashFn(entry.key) % new_buckets.len;
            var new_bucket = &new_buckets[index];
            if (previous_value) |_| {
                for (new_bucket.items[0..new_bucket.len]) |*e| {
                    if (eqlFn(e.key, entry.key)) e.* = entry;
                }
            } else {
                try new_bucket.append(allocator, entry);
                self.count = self.count + 1;
            }
            for (self.buckets) |*bucket| {
                bucket.deinit(allocator);
            }
            allocator.free(self.buckets);
            self.buckets = new_buckets;
        }

        pub fn put(self: *Self, allocator: std.mem.Allocator, key: K, value: V) !?V {
            const previous_value = self.get(key);
            const entry = Entry{ .key = key, .value = value };
            const load_factor: f32 = @as(f32, @floatFromInt(self.count)) / @as(f32, @floatFromInt(self.buckets.len));
            if (load_factor >= 0.75) {
                try self.resizeAndPut(allocator, entry, previous_value);
            } else {
                const index = hashFn(entry.key) % self.buckets.len;
                const bucket = &self.buckets[index];
                if (previous_value) |_| {
                    for (bucket.items[0..bucket.len]) |*e| {
                        if (eqlFn(e.key, key)) e.* = entry;
                    }
                } else {
                    try self.buckets[index].append(allocator, entry);
                    self.count = self.count + 1;
                }
            }
            return previous_value;
        }
    };
}

// ======
// Tests
// ======

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

fn hashString(s: []const u8) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(s);
    return hasher.final();
}

fn eqlString(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

test "init and deinit" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), map.count);
}

test "put and get single element" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    const old = try map.put(testing.allocator, 42, 100);
    try testing.expectEqual(@as(?u32, null), old);
    try testing.expectEqual(@as(?u32, 100), map.get(42));
}

test "put returns previous value" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    _ = try map.put(testing.allocator, 1, 100);
    const old = try map.put(testing.allocator, 1, 200);

    try testing.expectEqual(@as(?u32, 100), old);
    try testing.expectEqual(@as(?u32, 200), map.get(1));
}

test "get nonexistent key returns null" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    try testing.expectEqual(@as(?u32, null), map.get(999));
}

test "put multiple elements" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    _ = try map.put(testing.allocator, 1, 10);
    _ = try map.put(testing.allocator, 2, 20);
    _ = try map.put(testing.allocator, 3, 30);

    try testing.expectEqual(@as(?u32, 10), map.get(1));
    try testing.expectEqual(@as(?u32, 20), map.get(2));
    try testing.expectEqual(@as(?u32, 30), map.get(3));
    try testing.expectEqual(@as(usize, 3), map.count);
}

test "count increments correctly" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    _ = try map.put(testing.allocator, 1, 100);
    _ = try map.put(testing.allocator, 2, 200);
    _ = try map.put(testing.allocator, 1, 150); // overwrite, should not increment

    try testing.expectEqual(@as(usize, 2), map.count);
}

test "resize triggers on load factor" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    for (0..10) |i| {
        _ = try map.put(testing.allocator, @intCast(i), @intCast(i * 10));
    }

    try testing.expectEqual(@as(usize, 10), map.count);
    try testing.expect(map.buckets.len > 8);

    for (0..10) |i| {
        try testing.expectEqual(@as(?u32, @intCast(i * 10)), map.get(@intCast(i)));
    }
}

test "string keys" {
    const Map = HashMap([]const u8, u32, hashString, eqlString);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    _ = try map.put(testing.allocator, "foo", 1);
    _ = try map.put(testing.allocator, "bar", 2);
    _ = try map.put(testing.allocator, "baz", 3);

    try testing.expectEqual(@as(?u32, 1), map.get("foo"));
    try testing.expectEqual(@as(?u32, 2), map.get("bar"));
    try testing.expectEqual(@as(?u32, 3), map.get("baz"));
    try testing.expectEqual(@as(?u32, null), map.get("qux"));
}

test "string keys and string values" {
    const Map = HashMap([]const u8, []const u8, hashString, eqlString);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    _ = try map.put(testing.allocator, "greeting", "hello");
    _ = try map.put(testing.allocator, "farewell", "goodbye");

    try testing.expectEqualStrings("hello", map.get("greeting").?);
    try testing.expectEqualStrings("goodbye", map.get("farewell").?);
}

test "overwrite same key multiple times" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    _ = try map.put(testing.allocator, 42, 1);
    _ = try map.put(testing.allocator, 42, 2);
    _ = try map.put(testing.allocator, 42, 3);
    _ = try map.put(testing.allocator, 42, 4);

    try testing.expectEqual(@as(?u32, 4), map.get(42));
    try testing.expectEqual(@as(usize, 1), map.count);
}

test "negative integer keys" {
    const Map = HashMap(i32, i32, hashI32, eqlI32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    _ = try map.put(testing.allocator, -1, 100);
    _ = try map.put(testing.allocator, -999, 200);
    _ = try map.put(testing.allocator, 0, 300);

    try testing.expectEqual(@as(?i32, 100), map.get(-1));
    try testing.expectEqual(@as(?i32, 200), map.get(-999));
    try testing.expectEqual(@as(?i32, 300), map.get(0));
    try testing.expectEqual(@as(?i32, null), map.get(-2));
}

test "many items stress test" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    for (0..500) |i| {
        _ = try map.put(testing.allocator, @intCast(i), @intCast(i * 2));
    }

    try testing.expectEqual(@as(usize, 500), map.count);

    for (0..500) |i| {
        try testing.expectEqual(@as(?u32, @intCast(i * 2)), map.get(@intCast(i)));
    }
}

test "overwrite at resize threshold" {
    const Map = HashMap(u32, u32, hashU32, eqlU32);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    // fill to 7 elements (7/8 = 0.875, definitely over 0.75)
    for (0..7) |i| {
        _ = try map.put(testing.allocator, @intCast(i), @intCast(i * 10));
    }

    // should have resized to 16 buckets by now
    try testing.expect(map.buckets.len > 8);

    // reset and try differently - force the edge case
    map.deinit(testing.allocator);
    map = try Map.init(testing.allocator);

    // add 6 items
    for (0..6) |i| {
        _ = try map.put(testing.allocator, @intCast(i), @intCast(i * 10));
    }

    // now we're at 6/8 = 0.75 exactly
    // add one more NEW key to trigger resize
    _ = try map.put(testing.allocator, 100, 1000);

    // now at 7 items, resized to 16 buckets
    // overwrite an existing key - should NOT increase count
    const old = try map.put(testing.allocator, 0, 999);

    try testing.expectEqual(@as(?u32, 0), old);
    try testing.expectEqual(@as(?u32, 999), map.get(0));
    try testing.expectEqual(@as(usize, 7), map.count); // should still be 7, not 8
}

fn hashU8(x: u8) u64 {
    var hasher = std.hash.Wyhash.init(0);
    std.hash.autoHash(&hasher, x);
    return hasher.final();
}

fn eqlU8(a: u8, b: u8) bool {
    return a == b;
}

test "get does not read past len" {
    const Map = HashMap(u8, u8, hashU8, eqlU8);
    var map = try Map.init(testing.allocator);
    defer map.deinit(testing.allocator);

    // add and remove would be ideal but you don't have remove
    // so just add one item and check that we don't find phantom keys
    _ = try map.put(testing.allocator, 42, 100);

    // try a bunch of keys that might collide into same bucket
    // none of these should return a value
    for (0..255) |i| {
        const key: u8 = @intCast(i);
        if (key == 42) continue;
        try testing.expectEqual(@as(?u8, null), map.get(key));
    }
}
