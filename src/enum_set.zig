const Bits = @import("bits.zig").Bits;
const std = @import("std");
const testing = std.testing;
const warn = std.debug.warn;

pub fn EnumSet(comptime T: type) type {
    return struct {
        pub const member_count = @memberCount(T);
        pub const BitsIntType = @IntType(false, member_count);
        pub const BitsType = Bits(BitsIntType);

        bits: BitsType,

        const Self = @This();

        pub fn init(e: var) Self {
            var result = Self{ .bits = BitsType.initZero() };
            inline for (std.meta.fields(@TypeOf(e))) |f| {
                result.bits.set(@enumToInt(@as(T, @field(e, f.name))));
            }
            return result;
        }

        pub fn put(self: *Self, e: var) void {
            inline for (std.meta.fields(@TypeOf(e))) |f| {
                self.bits.set(@enumToInt(@as(T, @field(e, f.name))));
            }
        }

        pub fn get(self: Self, i: u1) ?T {
            return if (self.bits.at(i)) |_| @intToEnum(T, i) else null;
        }

        pub fn remove(self: *Self, e: var) void {
            inline for (std.meta.fields(@TypeOf(e))) |f| {
                self.bits.unset(@enumToInt(@as(T, @field(e, f.name))));
            }
        }

        pub fn contains(self: Self, e: T) bool {
            return if (self.bits.at(@enumToInt(e))) |bit| bit == 1 else false;
        }

        pub fn containsAll(self: Self, e: var) bool {
            inline for (std.meta.fields(@TypeOf(e))) |f|
                if (!self.contains(@field(e, f.name))) return false;
            return true;
        }

        pub fn containsAny(self: Self, e: var) bool {
            inline for (std.meta.fields(@TypeOf(e))) |f|
                if (self.contains(@field(e, f.name))) return true;
            return false;
        }

        fn bitFmtStr(buf: *[10]u8) ![]u8 {
            return try std.fmt.bufPrint(buf, "{d:0>10}", .{member_count});
        }

        pub fn limbString(self: Self, buf: []u8) ![]const u8 {
            comptime var buf2: [10]u8 = undefined;
            comptime const size_str = bitFmtStr(&buf2) catch unreachable;
            return try std.fmt.bufPrint(buf, "{b:0>" ++ size_str ++ "}", .{self.bits.value});
        }

        pub fn printLimbs(self: Self) void {
            comptime var buf: [10]u8 = undefined;
            comptime const size_str = bitFmtStr(&buf) catch unreachable;
            warn("\n", .{});
            warn("{b:0>" ++ size_str ++ "}\n", .{self.bits.value});
            warn("\n", .{});
        }

        pub fn intersect(self: Self, other: Self) Self {
            return .{ .bits = BitsType.init(self.bits.value & other.bits.value) };
        }

        /// set union
        pub fn join(self: Self, other: Self) Self {
            return .{ .bits = BitsType.init(self.bits.value | other.bits.value) };
        }

        pub fn difference(self: Self, other: Self) Self {
            return self.intersect(other.complement());
        }

        pub fn complement(self: Self) Self {
            return .{ .bits = BitsType.init(~self.bits.value) };
        }

        pub fn count(self: Self) usize {
            return @popCount(usize, self.bits.value);
        }

        pub fn isEmpty(self: Self) bool {
            return self.count() == 0;
        }

        pub fn isSubsetOf(self: Self, other: Self) bool {
            // is a subset of b if and only if (a | b) == b.
            // Or equivalently (a & b) == a.
            return self.intersect(other).equals(self);
        }

        pub fn equals(self: Self, other: Self) bool {
            return self.bits.value == other.bits.value;
        }

        pub fn clear(self: *Self) void {
            self.bits = BitsType.initZero();
        }

        /// allocates memory for returned enum slice
        /// caller is responsible for freeing
        pub fn toEnumSlice(self: Self, a: *std.mem.Allocator) ![]T {
            return try self.translate(a, T);
        }

        /// allocates memory for returned enum slice
        /// caller is responsible for freeing
        pub fn translate(self: Self, a: *std.mem.Allocator, comptime To: type) ![]To {
            const ct = self.count();
            var result = try a.alloc(To, ct);
            const result_start_ptr = result.ptr;
            var i: usize = 0;
            while (i < member_count) : (i += 1) {
                const at = self.bits.at(i) orelse continue;
                if (at == 1) {
                    result[0] = @intToEnum(To, @intCast(@TagType(T), i));
                    result.ptr += 1;
                }
            }

            result.ptr = result_start_ptr;
            return result;
        }
    };
}

test "basic set / get" {
    const MyFlags = @import("../test/myflags.zig").MyFlags;
    var my_set = EnumSet(MyFlags).init(.{.AA});

    my_set.put(.{ .AA, .AB });
    testing.expect(my_set.contains(.AA));
    testing.expect(my_set.contains(.AB));
    testing.expect(!my_set.contains(.AC));
    testing.expect(if (my_set.get(0)) |e| e == .AA else false);

    my_set.remove(.{.AB});
    testing.expect(my_set.contains(.AA));
    testing.expect(!my_set.contains(.AB));
    testing.expect(!my_set.contains(.AC));

    my_set.put(.{ .ZZ, .ZY });
    testing.expect(my_set.contains(.ZY));
    testing.expect(my_set.contains(.ZZ));
    testing.expect(!my_set.contains(.ZX));

    my_set.remove(.{.ZY});
    testing.expect(!my_set.contains(.ZY));
    testing.expect(my_set.contains(.ZZ));
    testing.expect(!my_set.contains(.ZX));

    my_set.put(.{ .AH, .AI, .AJ });
    testing.expect(my_set.containsAll(.{ .AH, .AI, .AJ }));
    testing.expect(!my_set.containsAny(.{ .BH, .BI, .BJ }));
}

test "set / get with huge enum" {
    const HugeEnum = @import("../test/my_huge_enum.zig").HugeEnum; // 26 ^ 3 members .AAA .. .ZZZ
    var huge_set = EnumSet(HugeEnum).init(.{.AAA});

    huge_set.put(.{ .AAA, .AAB });
    testing.expect(huge_set.contains(.AAA));
    testing.expect(huge_set.contains(.AAB));
    testing.expect(!huge_set.contains(.AAC));

    huge_set.remove(.{.AAB});
    testing.expect(huge_set.contains(.AAA));
    testing.expect(!huge_set.contains(.AAB));
    testing.expect(!huge_set.contains(.AAC));

    huge_set.put(.{ .ZZZ, .ZZY });
    testing.expect(huge_set.contains(.ZZY));
    testing.expect(huge_set.contains(.ZZZ));
    testing.expect(!huge_set.contains(.ZZX));

    huge_set.remove(.{.ZZY});
    testing.expect(huge_set.contains(.ZZZ));
    testing.expect(!huge_set.contains(.ZZY));
    testing.expect(!huge_set.contains(.ZZX));

    // bug triggered by printing this enumSet
    // zig version 0.5.0+7ebc624a1 Thu 30 Jan 2020
    // std.mem.Allocator.alignedRealloc...Assertion failed at zig/src/analyze.cpp:9222 in get_llvm_type. This is a bug in the Zig compiler.
    // huge_set.printLimbs();
}

test "set operations" {
    const E = enum {
        A,
        B,
        C,
    };
    const ESet = EnumSet(E);

    const a = ESet.init(.{ .A, .B });
    const b = ESet.init(.{ .B, .C });
    const c = a.intersect(b);
    testing.expect(c.contains(.B));
    testing.expect(!c.containsAny(.{ .A, .C }));

    const d = a.join(b);
    testing.expect(d.containsAll(.{ .A, .B, .C }));

    var e = ESet.init(.{ .A, .B, .C });
    e.clear();
    testing.expect(e.isEmpty());
    testing.expect(!e.containsAny(.{ .A, .B, .C }));

    const f = ESet.init(.{ .A, .B, .C }).difference(ESet.init(.{ .A, .B }));
    testing.expect(f.contains(.C));
    testing.expect(!f.containsAny(.{ .A, .B }));

    testing.expect(a.count() == 2);
    testing.expect(b.count() == 2);
    testing.expect(d.count() == 3);
    testing.expect(c.count() == 1);

    testing.expect(a.equals(ESet.init(.{ .A, .B })));

    e = ESet.init(.{ .A, .B, .C });
    testing.expect(f.isSubsetOf(e));
    testing.expect(a.isSubsetOf(e));
    testing.expect(b.isSubsetOf(e));
    testing.expect(f.isSubsetOf(b));
    testing.expect(!f.isSubsetOf(a));
    testing.expect(!b.isSubsetOf(a));
    testing.expect(!a.isSubsetOf(b));
}

test "translate / toEnumSlice" {
    const E = enum {
        A,
        B,
        C,
    };
    const ESet = EnumSet(E);
    const F = enum {
        D,
        E,
        F,
    };
    const FSet = EnumSet(F);
    const al = std.heap.page_allocator;
    const e = ESet.init(.{ .A, .B, .C });
    testing.expect(std.mem.eql(E, &[_]E{ .A, .B, .C }, try e.toEnumSlice(al)));

    testing.expect(std.mem.eql(F, &[_]F{ .D, .E, .F }, try e.translate(al, F)));

    var buf: [10]u8 = undefined;
    testing.expect(std.mem.eql(u8, try e.limbString(&buf), "111"));
}

test "demo" {
    // const std = @import("std");
    const expect = std.testing.expect;
    const E = enum {
        A,
        B,
        C,
    };
    const ESet = EnumSet(E);

    // insert and remove elements
    var ab = ESet.init(.{ .A, .B });
    ab.remove(.{.B});
    expect(ab.count() == 1);
    ab.clear();
    expect(ab.count() == 0);
    const bc = ESet.init(.{ .B, .C });
    const ac = ESet.init(.{ .A, .C });
    const abc = ESet.init(.{ .A, .B, .C });
    const b = ESet.init(.{.B});
    const c = ESet.init(.{.C});
    ab.put(.{ .A, .B });
    expect(if (ab.get(0)) |e| e == .A else false);

    // set operations
    expect(ab.contains(.A));
    expect(ab.containsAll(.{ .A, .B }));
    expect(ab.containsAny(.{.A}));
    expect(ab.intersect(bc).equals(b));
    expect(ab.join(bc).equals(abc));
    expect(abc.difference(ac).equals(b));
    expect(ab.complement().equals(c));
    expect(!ab.isEmpty());
    expect(ab.isSubsetOf(abc));
    expect(ab.equals(ab));

    // while loop over each bit
    var _abc = abc; // need to be a mutable 'var'
    var i: usize = 0;
    while (_abc.bits.next()) |bit| : (i += 1) {
        const at = _abc.bits.at(i) orelse return testing.expect(false);
        testing.expect(bit == at);
    }
    _abc.bits.reset(); // to use as iterator again, first reset()

    // for loop over each byte (u8)
    for (abc.bits.toSlice()) |byte, byte_idx| {
        var bit_idx: usize = 0;
        while (bit_idx < 8) : (bit_idx += 1) {
            const bit_offset = byte_idx * 8 + bit_idx;
            if (bit_offset >= abc.count()) break;
            if (abc.bits.at(bit_offset)) |at|
                expect((byte >> @truncate(u3, bit_idx)) & 1 == at);
        }
    }

    // for loop over each byte using ByteView
    for (abc.bits.byteViewSlice()) |byte_view, byte_view_idx| {
        // ByteView allows field access of each bit with fields _0, _1 .. _7
        if (abc.bits.at(byte_view_idx * 8 + 0)) |at| expect(byte_view._0 == at);
        if (abc.bits.at(byte_view_idx * 8 + 1)) |at| expect(byte_view._1 == at);
        if (abc.bits.at(byte_view_idx * 8 + 2)) |at| expect(byte_view._2 == at);
        if (abc.bits.at(byte_view_idx * 8 + 3)) |at| expect(byte_view._3 == at);
        if (abc.bits.at(byte_view_idx * 8 + 4)) |at| expect(byte_view._4 == at);
        if (abc.bits.at(byte_view_idx * 8 + 5)) |at| expect(byte_view._5 == at);
        if (abc.bits.at(byte_view_idx * 8 + 6)) |at| expect(byte_view._6 == at);
        if (abc.bits.at(byte_view_idx * 8 + 7)) |at| expect(byte_view._7 == at);

        // the same can be done using @field
        inline for (std.meta.fields(ESet.BitsType.ByteView)) |f, field_idx| {
            const bit_offset = byte_view_idx * 8 + field_idx;
            if (bit_offset >= abc.count()) break;
            if (abc.bits.at(bit_offset)) |at| expect(@field(byte_view, f.name) == at);
        }
    }

    // making enum slices does requires an allocator
    // this is the only place an allocator is used
    const allocator = std.heap.page_allocator;
    expect(std.mem.eql(E, &[_]E{ .A, .B, .C }, try abc.toEnumSlice(allocator)));

    // translate from one enum set to another
    const F = enum {
        D,
        E,
        F,
    };
    const FSet = EnumSet(F);
    expect(std.mem.eql(F, &[_]F{ .D, .E, .F }, try abc.translate(allocator, F)));
}
