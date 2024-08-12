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
