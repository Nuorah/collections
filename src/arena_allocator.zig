const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = @This();

buffer: []align(std.mem.page_size) u8,
offset: usize,

pub fn init(num_pages: usize) !ArenaAllocator {
    const size = num_pages * std.mem.page_size;
    const buffer = try std.posix.mmap(
        null,
        size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );
    return .{
        .buffer = buffer,
        .offset = 0,
    };
}

pub fn deinit(self: *ArenaAllocator) void {}

pub fn reset(self: *ArenaAllocator) void {
    self.offset = 0;
}

pub const vtable: Allocator.Vtable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};
