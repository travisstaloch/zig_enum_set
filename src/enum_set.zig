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

        pub fn set(self: *Self, e: var) void {
            inline for (std.meta.fields(@TypeOf(e))) |f| {
                self.bits.set(@enumToInt(@as(T, @field(e, f.name))));
            }
        }

        pub fn unset(self: *Self, e: var) void {
            inline for (std.meta.fields(@TypeOf(e))) |f| {
                self.bits.unset(@enumToInt(@as(T, @field(e, f.name))));
            }
        }

        pub fn has(self: Self, e: T) bool {
            return if (self.bits.at(@enumToInt(e))) |bit| bit == 1 else false;
        }

        pub fn hasAll(self: Self, e: var) bool {
            inline for (std.meta.fields(@TypeOf(e))) |f|
                if (!self.has(@field(e, f.name))) return false;
            return true;
        }

        pub fn hasAny(self: Self, e: var) bool {
            inline for (std.meta.fields(@TypeOf(e))) |f|
                if (self.has(@field(e, f.name))) return true;
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
            // TODO: make format string at comptime based on len
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
        /// caller is responsible for freeing memory
        pub fn toEnumSlice(self: Self, a: *std.mem.Allocator) ![]T {
            return try self.translate(a, T);
        }

        /// allocates memory for returned enum slice
        /// caller is responsible for freeing memory
        pub fn translate(self: Self, a: *std.mem.Allocator, comptime To: type) ![]To {
            const ct = self.count();
            var result = try a.alloc(To, ct);
            const result_start_ptr = result.ptr;
            var i: BitsType.ShiftType = 0;
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

    my_set.set(.{ .AA, .AB });
    testing.expect(my_set.has(.AA));
    testing.expect(my_set.has(.AB));
    testing.expect(!my_set.has(.AC));

    my_set.unset(.{.AB});
    testing.expect(my_set.has(.AA));
    testing.expect(!my_set.has(.AB));
    testing.expect(!my_set.has(.AC));

    my_set.set(.{ .ZZ, .ZY });
    testing.expect(my_set.has(.ZY));
    testing.expect(my_set.has(.ZZ));
    testing.expect(!my_set.has(.ZX));

    my_set.unset(.{.ZY});
    testing.expect(!my_set.has(.ZY));
    testing.expect(my_set.has(.ZZ));
    testing.expect(!my_set.has(.ZX));

    my_set.set(.{ .AH, .AI, .AJ });
    testing.expect(my_set.hasAll(.{ .AH, .AI, .AJ }));
    testing.expect(!my_set.hasAny(.{ .BH, .BI, .BJ }));
}

test "set / get with huge enum" {
    const HugeEnum = @import("../test/my_huge_enum.zig").HugeEnum; // 26 ^ 3 members .AAA .. .ZZZ
    var huge_set = EnumSet(HugeEnum).init(.{.AAA});

    huge_set.set(.{ .AAA, .AAB });
    testing.expect(huge_set.has(.AAA));
    testing.expect(huge_set.has(.AAB));
    testing.expect(!huge_set.has(.AAC));

    huge_set.unset(.{.AAB});
    testing.expect(huge_set.has(.AAA));
    testing.expect(!huge_set.has(.AAB));
    testing.expect(!huge_set.has(.AAC));

    huge_set.set(.{ .ZZZ, .ZZY });
    testing.expect(huge_set.has(.ZZY));
    testing.expect(huge_set.has(.ZZZ));
    testing.expect(!huge_set.has(.ZZX));

    huge_set.unset(.{.ZZY});
    testing.expect(huge_set.has(.ZZZ));
    testing.expect(!huge_set.has(.ZZY));
    testing.expect(!huge_set.has(.ZZX));

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
    testing.expect(c.has(.B));
    testing.expect(!c.hasAny(.{ .A, .C }));

    const d = a.join(b);
    testing.expect(d.hasAll(.{ .A, .B, .C }));

    var e = ESet.init(.{ .A, .B, .C });
    e.clear();
    testing.expect(e.isEmpty());
    testing.expect(!e.hasAny(.{ .A, .B, .C }));

    const f = ESet.init(.{ .A, .B, .C }).difference(ESet.init(.{ .A, .B }));
    testing.expect(f.has(.C));
    testing.expect(!f.hasAny(.{ .A, .B }));

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
