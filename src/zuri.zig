const std = @import("std");
const net = std.net;

/// Host - possible uri host values
pub const Host = union(enum) {
    ip: net.Address,
    name: []const u8,
};

pub const Uri = struct {
    len: usize,
    host: Host,
    port: ?u16,
    path: []const u8,
    query: []const u8,
    scheme: []const u8,
    username: []const u8,
    password: []const u8,
    fragment: []const u8,
};
