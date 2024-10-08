const std = @import("std");
const net = std.net;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const parseUnsigned = std.fmt.parseUnsigned;

const ValueMap = std.StringHashMap([]const u8);

pub const scheme_to_port = std.ComptimeStringMap(u16, .{
    .{ "acap", 674 },
    .{ "afp", 548 },
    .{ "dict", 2628 },
    .{ "dns", 53 },
    .{ "ftp", 21 },
    .{ "git", 9418 },
    .{ "gopher", 70 },
    .{ "http", 80 },
    .{ "https", 443 },
    .{ "imap", 143 },
    .{ "ipp", 631 },
    .{ "ipps", 631 },
    .{ "irc", 194 },
    .{ "ircs", 6697 },
    .{ "ldap", 389 },
    .{ "ldaps", 636 },
    .{ "mms", 1755 },
    .{ "msrp", 2855 },
    .{ "mtqp", 1038 },
    .{ "nfs", 111 },
    .{ "nntp", 119 },
    .{ "nntps", 563 },
    .{ "pop", 110 },
    .{ "prospero", 1525 },
    .{ "redis", 6379 },
    .{ "rsync", 873 },
    .{ "rtsp", 554 },
    .{ "rtsps", 322 },
    .{ "rtspu", 5005 },
    .{ "sftp", 22 },
    .{ "smb", 445 },
    .{ "snmp", 161 },
    .{ "ssh", 22 },
    .{ "svn", 3690 },
    .{ "telnet", 23 },
    .{ "ventrilo", 3784 },
    .{ "vnc", 5900 },
    .{ "wais", 210 },
    .{ "ws", 80 },
    .{ "wss", 443 },
});

/// Host - possible uri host values
pub const Host = union(enum) {
    ip: net.Address,
    name: []const u8,
};

/// EncodeError - possible errors during decoding and encoding.
pub const EncodeError = error{
    InvalidCharacter,
    OutOfMemory,
};

/// Error - possible errors for parse.
pub const Error = error{
    /// input is not a valid uri due to a invalid character
    /// mostly a result of invalid ipv6
    InvalidCharacter,
    /// given input was empty
    EmptyUri,
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

    /// resolvePath resolves `path` leaving a '/' at the end, assumes `path` is valid.
    pub fn resolvePath(allocator: Allocator, path: []const u8) error{OutOfMemory}![]u8 {
        assert(path.len > 0);
        var list = std.ArrayList([]const u8).init(allocator);
        defer list.deinit();

        var it = mem.tokenize(u8, path, "/");
        while (it.next()) |p| {
            if (mem.eql(u8, p, ".")) {
                continue;
            } else if (mem.eql(u8, p, "..")) {
                _ = list.popOrNull();
            } else {
                try list.append(p);
            }
        }

        var buf = try allocator.alloc(u8, path.len);
        errdefer allocator.free(buf);
        var len: usize = 0;

        for (list.items) |s| {
            buf[len] = '/';
            len += 1;
            mem.copy(u8, buf[len..], s);
            len += s.len;
        }

        if (path[path.len - 1] == '/') {
            buf[len] = '/';
            len += 1;
        }

        return allocator.realloc(buf, len);
    }

    /// parse parses the URI from input.
    /// Empty input data is an error,
    /// if assume_auth is true then `example.com` will cause `example.com` to be the host and not the path.
    pub fn parse(input: []const u8, assume_auth: bool) Error!Uri {
        if (input.len == 0) {
            return error.EmptyUri;
        }

        var uri = Uri{
            .scheme = "",
            .username = "",
            .password = "",
            .host = .{ .name = "" },
            .port = null,
            .path = "",
            .query = "",
            .fragment = "",
            .len = 0,
        };

        switch (input[0]) {
            'a'...'z', 'A'...'Z' => {
                uri.parseMaybeScheme(input);
            },
            else => {},
        }

        if (input.len > uri.len + 2 and input[uri.len] == '/' and input[uri.len + 1] == '/') {
            uri.len += 2; // for the '//'
            try uri.parseAuth(input[uri.len..]);
        } else if (assume_auth) {
            try uri.parseAuth(input[uri.len..]);
        }

        // make host ip4 address if possible
        if (uri.host == .name and uri.host.name.len > 0) blk: {
            const a = net.Address.parseIp4(uri.host.name, 0) catch break :blk;
            uri.host = .{ .ip = a };
        }

        if (uri.host == .ip and uri.port != null) {
            uri.host.ip.setPort(uri.port.?);
        }

        uri.parsePath(input[uri.len..]);

        if (input.len > uri.len + 1 and input[uri.len] == '?') {
            uri.parseQuery(input[uri.len + 1 ..]);
        }

        if (input.len > uri.len + 1 and input[uri.len] == '#') {
            uri.parseFragment(input[uri.len + 1 ..]);
        }

        return uri;
    }

    fn parseAuth(u: *Uri, input: []const u8) Error!void {
        var i: u32 = 0;
        var at_index = i;
        while (i < input.len) : (i += 1) {
            switch (input[i]) {
                '@' => at_index = i,
                '[' => {
                    if (i != 0) return error.InvalidCharacter;
                    return u.parseIP6(input);
                },
                else => if (!isPchar(input[i..])) break,
            }
        }

        if (at_index != 0) {
            u.username = input[0..at_index];
            if (mem.indexOfScalar(u8, u.username, ':')) |colon| {
                u.password = u.username[colon + 1 ..];
                u.username = u.username[0..colon];
            }
            at_index += 1;
        }

        u.host.name = input[at_index..i];
        u.len += i;
        if (mem.indexOfScalar(u8, u.host.name, ':')) |colon| {
            u.port = parseUnsigned(u16, u.host.name[colon + 1 ..], 10) catch return error.InvalidCharacter;
            u.host.name = u.host.name[0..colon];
        }
    }

    fn parseMaybeScheme(u: *Uri, input: []const u8) void {
        for (input, 0..) |c, i| {
            switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9', '+', '-', '.' => {
                    // allowed characters
                },
                ':' => {
                    u.scheme = input[0..i];
                    u.port = scheme_to_port.get(u.scheme);
                    u.len += u.scheme.len + 1; // +1 for the ':'
                    return;
                },
                else => {
                    // not a valid scheme
                    return;
                },
            }
        }
    }

    fn parseIP6(u: *Uri, input: []const u8) Error!void {
        const end = mem.indexOfScalar(u8, input, ']') orelse return error.InvalidCharacter;
        const addr = net.Address.parseIp6(input[1..end], 0) catch return error.InvalidCharacter;
        u.host = .{ .ip = addr };
        u.len += end + 1;

        if (input.len > end + 2 and input[end + 1] == ':') {
            u.len += 1;
            try u.parsePort(input[end + 2 ..]);
        }
    }

    fn parsePort(u: *Uri, input: []const u8) Error!void {
        var i: u32 = 0;
        while (i < input.len) : (i += 1) {
            switch (input[i]) {
                '0'...'9' => {}, // digits
                else => break,
            }
        }
        if (i == 0) return error.InvalidCharacter;
        u.port = parseUnsigned(u16, input[0..i], 10) catch return error.InvalidCharacter;
        u.len += i;
    }

    fn parsePath(u: *Uri, input: []const u8) void {
        for (input, 0..) |c, i| {
            if (c != '/' and (c == '?' or c == '#' or !isPchar(input[i..]))) {
                u.path = input[0..i];
                u.len += u.path.len;
                return;
            }
        }
        u.path = input[0..];
        u.len += u.path.len;
    }

    fn parseQuery(u: *Uri, input: []const u8) void {
        u.len += 1;
        for (input, 0..) |c, i| {
            if (c == '#' or (c != '/' and c != '?' and !isPchar(input[i..]))) {
                u.query = input[0..i];
                u.len += u.query.len;
                return;
            }
        }
        u.query = input;
        u.len += input.len;
    }

    fn parseFragment(u: *Uri, input: []const u8) void {
        u.len += 1;
        for (input, 0..) |c, i| {
            if (c != '/' and c != '?' and !isPchar(input[i..])) {
                u.fragment = input[0..i];
                u.len += u.fragment.len;
                return;
            }
        }
        u.fragment = input;
        u.len += u.fragment.len;
    }
};
