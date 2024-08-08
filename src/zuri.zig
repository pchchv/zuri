const std = @import("std");
const net = std.net;
const mem = std.mem;
const assert = std.debug.assert;
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

    /// isPchar returns true if str starts with a valid path or octet character encoded in percentages.
    pub fn isPchar(str: []const u8) bool {
        assert(str.len > 0);
        return switch (str[0]) {
            'a'...'z', 'A'...'Z', '0'...'9', '-', '.', '_', '~', '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '=', ':', '@' => true,
            '%' => str.len > 3 and isHex(str[1]) and isHex(str[2]),
            else => false,
        };
    }

    /// isHex returns true if c is a hexadecimal digit.
    pub fn isHex(c: u8) bool {
        return switch (c) {
            '0'...'9', 'a'...'f', 'A'...'F' => true,
            else => false,
        };
    }

    /// decode decodes the path if it is percentage encoded
    pub fn decode(allocator: Allocator, path: []const u8) EncodeError!?[]u8 {
        var ret: ?[]u8 = null;
        errdefer if (ret) |some| allocator.free(some);
        var ret_index: usize = 0;
        var i: usize = 0;

        while (i < path.len) : (i += 1) {
            if (path[i] == '%') {
                if (!isPchar(path[i..])) {
                    return error.InvalidCharacter;
                }
                if (ret == null) {
                    ret = try allocator.alloc(u8, path.len);
                    mem.copy(u8, ret.?, path[0..i]);
                    ret_index = i;
                }

                // charToDigit cannot fail because the characters are checked earlier.
                var new = (std.fmt.charToDigit(path[i + 1], 16) catch unreachable) << 4;
                new |= std.fmt.charToDigit(path[i + 2], 16) catch unreachable;
                ret.?[ret_index] = new;
                ret_index += 1;
                i += 2;
            } else if (path[i] != '/' and !isPchar(path[i..])) {
                return error.InvalidCharacter;
            } else if (ret != null) {
                ret.?[ret_index] = path[i];
                ret_index += 1;
            }
        }

        if (ret) |some| return try allocator.realloc(some, ret_index);
        return null;
    }

    /// encode implements percentage encoding if the path contains characters not allowed in paths.
    pub fn encode(allocator: Allocator, path: []const u8) EncodeError!?[]u8 {
        var ret: ?[]u8 = null;
        var ret_index: usize = 0;
        for (path, 0..) |c, i| {
            if (c != '/' and !isPchar(path[i..])) {
                if (ret == null) {
                    ret = try allocator.alloc(u8, path.len * 3);
                    mem.copy(u8, ret.?, path[0..i]);
                    ret_index = i;
                }
                const hex_digits = "0123456789ABCDEF";
                ret.?[ret_index] = '%';
                ret.?[ret_index + 1] = hex_digits[(c & 0xF0) >> 4];
                ret.?[ret_index + 2] = hex_digits[c & 0x0F];
                ret_index += 3;
            } else if (ret != null) {
                ret.?[ret_index] = c;
                ret_index += 1;
            }
        }

        if (ret) |some| return try allocator.realloc(some, ret_index);
        return null;
    }
};
