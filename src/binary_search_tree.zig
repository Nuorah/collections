const std = @import("std");
const testing = std.testing;

pub fn BinarySearchTree(comptime K: type, comptime V: type, comptime lessThanFn: fn (K, K) bool) type {
    return struct {
        const Self = @This();
        const Entry = struct {
            key: K,
            value: V,
        };

        const Node = struct {
            entry: Entry,
            left: ?*Node = null,
            right: ?*Node = null,
        };

        root: ?*Node,

        pub fn init() Self {
            return Self{
                .root = null,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            freeNode(allocator, self.root);
            self.root = null;
        }

        fn freeNode(allocator: std.mem.Allocator, node: ?*Node) void {
            if (node) |n| {
                freeNode(allocator, n.left);
                freeNode(allocator, n.right);
                allocator.destroy(n);
            }
        }

        pub fn insert(self: *Self, allocator: std.mem.Allocator, key: K, value: V) !?V {
            var parent: ?*Node = null;
            var current = self.root;
            while (current) |c| {
                if (lessThanFn(key, c.entry.key)) {
                    parent = current;
                    current = c.left;
                    continue;
                }
                if (lessThanFn(c.entry.key, key)) {
                    parent = current;
                    current = c.right;
                    continue;
                }
                const previous_value = current.?.*.entry.value;
                current.?.*.entry.value = value;
                return previous_value;
            }
            const new_node: *Node = try allocator.create(Node);
            new_node.* = Node{
                .entry = Entry{
                    .key = key,
                    .value = value,
                },
            };
            if (parent) |p| {
                if (lessThanFn(key, p.entry.key)) {
                    p.left = new_node;
                } else {
                    p.right = new_node;
                }
            } else {
                self.root = new_node;
            }
            return null;
        }

        pub fn search(self: *const Self, key: K) ?V {
            var current = self.root;
            while (current) |c| {
                if (lessThanFn(key, c.entry.key)) {
                    current = c.left;
                    continue;
                }
                if (lessThanFn(c.entry.key, key)) {
                    current = c.right;
                    continue;
                }
                return c.entry.value;
            }
            return null;
        }

        pub fn delete(self: *Self, allocator: std.mem.Allocator, key: K) ?V {
            _ = allocator;
            var current = self.root;

            while (current) |c| {
                if (lessThanFn(key, c.entry.key)) {
                    current = c.left;
                    continue;
                }
                if (lessThanFn(c.entry.key, key)) {
                    current = c.right;
                    continue;
                }
                return c.entry.value;
            }
            return null;
        }
    };
}

pub fn lessThanU32(a: u32, b: u32) bool {
    return a < b;
}

test "init creates empty tree" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    defer bst.deinit(testing.allocator);
    try std.testing.expectEqual(null, bst.root);
}

test "insert into empty tree returns null" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    const result = try bst.insert(allocator, 5, "five");
    try std.testing.expectEqual(null, result);
}

test "insert duplicate key returns old value" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = std.testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");
    const result = try bst.insert(allocator, 5, "cinq");
    try std.testing.expectEqualStrings("five", result.?);
}

test "insert multiple keys" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = std.testing.allocator;
    defer bst.deinit(allocator);

    try std.testing.expectEqual(null, try bst.insert(allocator, 5, "five"));
    try std.testing.expectEqual(null, try bst.insert(allocator, 3, "three"));
    try std.testing.expectEqual(null, try bst.insert(allocator, 7, "seven"));
    try std.testing.expectEqual(null, try bst.insert(allocator, 1, "one"));
}

test "tree structure is correct after inserts" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = std.testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");
    _ = try bst.insert(allocator, 3, "three");
    _ = try bst.insert(allocator, 7, "seven");

    try std.testing.expectEqual(5, bst.root.?.entry.key);
    try std.testing.expectEqual(3, bst.root.?.left.?.entry.key);
    try std.testing.expectEqual(7, bst.root.?.right.?.entry.key);
}

const Person = struct {
    id: u32,
    name: []const u8,
};

pub fn lessThanPerson(a: Person, b: Person) bool {
    return a.id < b.id;
}

test "search empty tree returns null" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    defer bst.deinit(testing.allocator);

    const result = bst.search(5);
    try std.testing.expectEqual(null, result);
}

test "search finds existing key" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");
    _ = try bst.insert(allocator, 3, "three");
    _ = try bst.insert(allocator, 7, "seven");

    try std.testing.expectEqualStrings("five", (bst.search(5)).?);
    try std.testing.expectEqualStrings("three", (bst.search(3)).?);
    try std.testing.expectEqualStrings("seven", (bst.search(7)).?);
}

test "search returns null for missing key" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");
    _ = try bst.insert(allocator, 3, "three");

    try std.testing.expectEqual(null, bst.search(99));
}

test "search with struct keys" {
    var bst = BinarySearchTree(Person, []const u8, lessThanPerson).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    const alice = Person{ .id = 1, .name = "alice" };
    const bob = Person{ .id = 2, .name = "bob" };
    const charlie = Person{ .id = 3, .name = "charlie" };

    _ = try bst.insert(allocator, bob, "engineer");
    _ = try bst.insert(allocator, alice, "designer");
    _ = try bst.insert(allocator, charlie, "manager");

    try std.testing.expectEqualStrings("designer", (bst.search(alice)).?);
    try std.testing.expectEqualStrings("engineer", (bst.search(bob)).?);
    try std.testing.expectEqual(null, bst.search(Person{ .id = 99, .name = "nobody" }));
}

test "delete from empty tree returns null" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    defer bst.deinit(testing.allocator);

    const result = bst.delete(testing.allocator, 5);
    try std.testing.expectEqual(null, result);
}

test "delete non-existent key returns null" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");

    const result = bst.delete(allocator, 99);
    try std.testing.expectEqual(null, result);
}

test "delete leaf node" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");
    _ = try bst.insert(allocator, 3, "three");
    _ = try bst.insert(allocator, 7, "seven");

    const result = bst.delete(allocator, 3);
    try std.testing.expectEqualStrings("three", result.?);
    try std.testing.expectEqual(null, bst.root.?.left);
    try std.testing.expectEqual(null, bst.search(3));
}

test "delete node with only left child" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");
    _ = try bst.insert(allocator, 3, "three");
    _ = try bst.insert(allocator, 1, "one");

    const result = bst.delete(allocator, 3);
    try std.testing.expectEqualStrings("three", result.?);
    try std.testing.expectEqual(1, bst.root.?.left.?.entry.key);
}

test "delete node with only right child" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");
    _ = try bst.insert(allocator, 3, "three");
    _ = try bst.insert(allocator, 4, "four");

    const result = bst.delete(allocator, 3);
    try std.testing.expectEqualStrings("three", result.?);
    try std.testing.expectEqual(4, bst.root.?.left.?.entry.key);
}

test "delete node with two children" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    //       5
    //      / \
    //     3   7
    //    / \
    //   1   4
    _ = try bst.insert(allocator, 5, "five");
    _ = try bst.insert(allocator, 3, "three");
    _ = try bst.insert(allocator, 7, "seven");
    _ = try bst.insert(allocator, 1, "one");
    _ = try bst.insert(allocator, 4, "four");

    const result = bst.delete(allocator, 3);
    try std.testing.expectEqualStrings("three", result.?);
    // successor is 4, should take 3's place
    try std.testing.expectEqual(4, bst.root.?.left.?.entry.key);
    try std.testing.expectEqual(1, bst.root.?.left.?.left.?.entry.key);
    try std.testing.expectEqual(null, bst.root.?.left.?.right);
}

test "delete root with two children" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");
    _ = try bst.insert(allocator, 3, "three");
    _ = try bst.insert(allocator, 7, "seven");

    const result = bst.delete(allocator, 5);
    try std.testing.expectEqualStrings("five", result.?);
    // successor is 7
    try std.testing.expectEqual(7, bst.root.?.entry.key);
    try std.testing.expectEqual(3, bst.root.?.left.?.entry.key);
}

test "delete root when it's the only node" {
    var bst = BinarySearchTree(u32, []const u8, lessThanU32).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    _ = try bst.insert(allocator, 5, "five");

    const result = bst.delete(allocator, 5);
    try std.testing.expectEqualStrings("five", result.?);
    try std.testing.expectEqual(null, bst.root);
}

test "delete with struct keys" {
    var bst = BinarySearchTree(Person, []const u8, lessThanPerson).init();
    const allocator = testing.allocator;
    defer bst.deinit(allocator);

    const alice = Person{ .id = 1, .name = "alice" };
    const bob = Person{ .id = 2, .name = "bob" };
    const charlie = Person{ .id = 3, .name = "charlie" };

    _ = try bst.insert(allocator, bob, "engineer");
    _ = try bst.insert(allocator, alice, "designer");
    _ = try bst.insert(allocator, charlie, "manager");

    const result = bst.delete(allocator, bob);
    try std.testing.expectEqualStrings("engineer", result.?);
    try std.testing.expectEqual(null, bst.search(bob));
    try std.testing.expectEqualStrings("designer", (bst.search(alice)).?);
    try std.testing.expectEqualStrings("manager", (bst.search(charlie)).?);
}
