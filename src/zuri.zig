const std = @import("std");
const net = std.net;

/// possible uri host values
pub const Host = union(enum) {
    ip: net.Address,
    name: []const u8,
};
