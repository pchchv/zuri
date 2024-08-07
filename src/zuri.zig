const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;

const ValueMap = std.StringHashMap([]const u8);

/// Host - possible uri host values
pub const Host = union(enum) {
    ip: net.Address,
    name: []const u8,
};

/// EncodeError - possible errors during decoding and encoding
pub const EncodeError = error{
    InvalidCharacter,
    OutOfMemory,
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

    /// mapQuery maps query strings into a hashmap of key-value pairs, with no value being an empty string.
    pub fn mapQuery(allocator: Allocator, query: []const u8) Allocator.Error!ValueMap {
        if (query.len == 0) {
            return ValueMap.init(allocator);
        }

        var map = ValueMap.init(allocator);
        errdefer map.deinit();

        var start: usize = 0;
        var mid: usize = 0;
        for (query, 0..) |c, i| {
            if (c == '&') {
                if (mid != 0) {
                    _ = try map.put(query[start..mid], query[mid + 1 .. i]);
                } else {
                    _ = try map.put(query[start..i], "");
                }
                start = i + 1;
                mid = 0;
            } else if (c == '=') {
                mid = i;
            }
        }

        if (mid != 0) {
            _ = try map.put(query[start..mid], query[mid + 1 ..]);
        } else {
            _ = try map.put(query[start..], "");
        }

        return map;
    }
};
