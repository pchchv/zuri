const std = @import("std");
const Uri = @import("zuri.zig");
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
