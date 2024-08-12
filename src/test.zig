const std = @import("std");
const Uri = @import("zuri.zig").Uri;
const testing = std.testing;
const expect = testing.expect;
const expectEqualStrings = testing.expectEqualStrings;

test "basic url" {
    const uri = try Uri.parse("https://ziglang.org:80/documentation/master/?test#toc-Introduction", false);
    try expectEqualStrings("https", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);
    try expectEqualStrings("ziglang.org", uri.host.name);
    try expect(uri.port.? == 80);
    try expectEqualStrings("/documentation/master/", uri.path);
    try expectEqualStrings("test", uri.query);
    try expectEqualStrings("toc-Introduction", uri.fragment);
    try expect(uri.len == 66);
}

test "short" {
    const uri = try Uri.parse("telnet://192.0.2.16:80/", false);
    try expectEqualStrings("telnet", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);

    var buf = [_]u8{0} ** 100;
    const ip = std.fmt.bufPrint(buf[0..], "{}", .{uri.host.ip}) catch unreachable;
    try expectEqualStrings("192.0.2.16:80", ip);
    try expect(uri.port.? == 80);
    try expectEqualStrings("/", uri.path);
    try expectEqualStrings("", uri.query);
    try expectEqualStrings("", uri.fragment);
    try expect(uri.len == 23);
}

test "single char" {
    const uri = try Uri.parse("a", false);
    try expectEqualStrings("", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);
    try expectEqualStrings("", uri.host.name);
    try expect(uri.port == null);
    try expectEqualStrings("a", uri.path);
    try expectEqualStrings("", uri.query);
    try expectEqualStrings("", uri.fragment);
    try expect(uri.len == 1);
}

test "ipv6" {
    const uri = try Uri.parse("ldap://[2001:db8::7]/c=GB?objectClass?one", false);
    try expectEqualStrings("ldap", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);

    var buf = [_]u8{0} ** 100;
    const ip = std.fmt.bufPrint(buf[0..], "{}", .{uri.host.ip}) catch unreachable;
    try expectEqualStrings("[2001:db8::7]:389", ip);
    try expect(uri.port.? == 389);
    try expectEqualStrings("/c=GB", uri.path);
    try expectEqualStrings("objectClass?one", uri.query);
    try expectEqualStrings("", uri.fragment);
    try expect(uri.len == 41);
}

test "mailto" {
    const uri = try Uri.parse("mailto:John.Doe@example.com", false);
    try expectEqualStrings("mailto", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);
    try expectEqualStrings("", uri.host.name);
    try expect(uri.port == null);
    try expectEqualStrings("John.Doe@example.com", uri.path);
    try expectEqualStrings("", uri.query);
    try expectEqualStrings("", uri.fragment);
    try expect(uri.len == 27);
}

test "tel" {
    const uri = try Uri.parse("tel:+1-816-555-1212", false);
    try expectEqualStrings("tel", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);
    try expectEqualStrings("", uri.host.name);
    try expect(uri.port == null);
    try expectEqualStrings("+1-816-555-1212", uri.path);
    try expectEqualStrings("", uri.query);
    try expectEqualStrings("", uri.fragment);
    try expect(uri.len == 19);
}

test "urn" {
    const uri = try Uri.parse("urn:oasis:names:specification:docbook:dtd:xml:4.1.2", false);
    try expectEqualStrings("urn", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);
    try expectEqualStrings("", uri.host.name);
    try expect(uri.port == null);
    try expectEqualStrings("oasis:names:specification:docbook:dtd:xml:4.1.2", uri.path);
    try expectEqualStrings("", uri.query);
    try expectEqualStrings("", uri.fragment);
    try expect(uri.len == 51);
}

test "userinfo" {
    const uri = try Uri.parse("ftp://username:password@host.com/", false);
    try expectEqualStrings("ftp", uri.scheme);
    try expectEqualStrings("username", uri.username);
    try expectEqualStrings("password", uri.password);
    try expectEqualStrings("host.com", uri.host.name);
    try expect(uri.port.? == 21);
    try expectEqualStrings("/", uri.path);
    try expectEqualStrings("", uri.query);
    try expectEqualStrings("", uri.fragment);
    try expect(uri.len == 33);
}

test "map query" {
    const uri = try Uri.parse("https://ziglang.org:80/documentation/master/?test;1=true&false#toc-Introduction", false);
    try expectEqualStrings("https", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);
    try expectEqualStrings("ziglang.org", uri.host.name);
    try expect(uri.port.? == 80);
    try expectEqualStrings("/documentation/master/", uri.path);
    try expectEqualStrings("test;1=true&false", uri.query);
    try expectEqualStrings("toc-Introduction", uri.fragment);

    var map = try Uri.mapQuery(std.testing.allocator, uri.query);
    defer map.deinit();

    try expectEqualStrings("true", map.get("test;1").?);
    try expectEqualStrings("", map.get("false").?);
}

test "ends in space" {
    const uri = try Uri.parse("https://ziglang.org/documentation/master/ something else", false);
    try expectEqualStrings("https", uri.scheme);
    try expectEqualStrings("", uri.username);
    try expectEqualStrings("", uri.password);
    try expectEqualStrings("ziglang.org", uri.host.name);
    try expectEqualStrings("/documentation/master/", uri.path);
    try expect(uri.len == 41);
}

test "assume auth" {
    const uri = try Uri.parse("ziglang.org", true);
    try expectEqualStrings("ziglang.org", uri.host.name);
    try expect(uri.len == 11);
}

test "username contains @" {
    const uri = try Uri.parse("https://1.1.1.1&@2.2.2.2%23@3.3.3.3", false);
    try expectEqualStrings("https", uri.scheme);
    try expectEqualStrings("1.1.1.1&@2.2.2.2%23", uri.username);
    try expectEqualStrings("", uri.password);

    var buf = [_]u8{0} ** 100;
    const ip = std.fmt.bufPrint(buf[0..], "{}", .{uri.host.ip}) catch unreachable;
    try expectEqualStrings("3.3.3.3:443", ip);
    try expect(uri.port.? == 443);
    try expectEqualStrings("", uri.path);
    try expect(uri.len == 35);
}

test "encode" {
    const path = (try Uri.encode(testing.allocator, "/안녕하세요.html")).?;
    defer testing.allocator.free(path);
    try expectEqualStrings("/%EC%95%88%EB%85%95%ED%95%98%EC%84%B8%EC%9A%94.html", path);
}

test "decode" {
    const path = (try Uri.decode(testing.allocator, "/%EC%95%88%EB%85%95%ED%95%98%EC%84%B8%EC%9A%94.html")).?;
    defer testing.allocator.free(path);
    try expectEqualStrings("/안녕하세요.html", path);
}

test "resolvePath" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var a = try Uri.resolvePath(alloc, "/a/b/..");
    try expectEqualStrings("/a", a);
    a = try Uri.resolvePath(alloc, "/a/b/../");
    try expectEqualStrings("/a/", a);
    a = try Uri.resolvePath(alloc, "/a/b/c/../d/../");
    try expectEqualStrings("/a/b/", a);
    a = try Uri.resolvePath(alloc, "/a/b/c/../d/..");
    try expectEqualStrings("/a/b", a);
    a = try Uri.resolvePath(alloc, "/a/b/c/../d/.././");
    try expectEqualStrings("/a/b/", a);
    a = try Uri.resolvePath(alloc, "/a/b/c/../d/../.");
    try expectEqualStrings("/a/b", a);
    a = try Uri.resolvePath(alloc, "/a/../../");
    try expectEqualStrings("/", a);
}
