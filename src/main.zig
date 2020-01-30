const std = @import("std");
const testing = std.testing;
const warn = std.debug.warn;

pub fn EnumSet(comptime T: type) type {
    return struct {
        const LimbType = u64;
        const limb_bit_count = @sizeOf(LimbType) * 8;
        const bit_offset_size = std.math.log(LimbType, 2, limb_bit_count);
        const BitOffsetType = @IntType(false, bit_offset_size);
        const limb_count = (@memberCount(T) / limb_bit_count) + 1;
        const LimbsType = @Vector(limb_count, LimbType);

        limbs: LimbsType = [1]LimbType{0} ** limb_count,
        // const NewLimbType = @IntType(false, limb_bit_count);
        // limbs: NewLimbType = 0,

        const Self = @This();
        const Offsets = struct {
            whole: usize,
            limb: usize,
            bit: BitOffsetType,
        };

        pub fn limbOffsets(enum_value: T) Offsets {
            const whole = @as(LimbType, @enumToInt(enum_value));
            const limb = whole / limb_bit_count;
            return .{ .whole = whole, .limb = limb, .bit = @intCast(BitOffsetType, whole % limb_bit_count) };
        }

        pub fn init(e: var) Self {
            var result = Self{};
            inline for (std.meta.fields(@TypeOf(e))) |f| {
                const offsets = limbOffsets(@field(e, f.name));
                result.limbs[offsets.limb] |= @as(LimbType, 1) << offsets.bit;
            }
            return result;
        }

        pub fn set(self: *Self, e: var) void {
            inline for (std.meta.fields(@TypeOf(e))) |f| {
                const offsets = limbOffsets(@field(e, f.name));
                self.limbs[offsets.limb] |= @as(LimbType, 1) << offsets.bit;
            }
        }

        pub fn unset(self: *Self, e: var) void {
            inline for (std.meta.fields(@TypeOf(e))) |f| {
                const offsets = limbOffsets(@field(e, f.name));
                self.limbs[offsets.limb] &= ~(@as(LimbType, 1) << offsets.bit);
            }
        }

        pub fn has(self: Self, e: T) bool {
            const offsets = limbOffsets(e);
            return self.limbs[offsets.limb] & (@as(LimbType, 1) << offsets.bit) > 0;
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

        pub fn limbString(self: Self, limb_index: usize, buf: []u8) ![]const u8 {
            const size_str = comptime blk: {
                var buf2: [3]u8 = undefined;
                break :blk try std.fmt.bufPrint(&buf2, "{}", .{limb_bit_count});
            };
            return try std.fmt.bufPrint(buf, "{b:0>" ++ size_str ++ "}", .{self.limbs[limb_index]});
        }

        pub fn printLimbs(self: Self) void {
            var buf: [limb_bit_count]u8 = undefined;
            warn("\n", .{});
            var i: usize = 0;
            while (i < limb_count) : (i += 1) warn("{} ", .{self.limbString(i, &buf) catch unreachable});
            warn("\n", .{});
        }

        pub fn intersect(self: Self, other: Self) Self {
            return .{ .limbs = self.limbs & other.limbs };
        }

        /// set union
        pub fn join(self: Self, other: Self) Self {
            return .{ .limbs = self.limbs | other.limbs };
        }

        pub fn difference(self: Self, other: Self) Self {
            return self.intersect(other.complement());
        }

        pub fn complement(self: Self) Self {
            // TODO: when vectors support bit complement use this
            // return .{ .limbs = self.limbs & ~other.limbs };
            var result = Self{ .limbs = undefined };
            var i: usize = 0;
            while (i < limb_count) : (i += 1) result.limbs[i] = ~self.limbs[i];
            return result;
        }

        pub fn count(self: Self) LimbType {
            // TODO: switch to simd operation when supported
            // return @popCount(LimbsType, self.limbs);
            var result: LimbType = 0;
            var i: usize = 0;
            while (i < limb_count) : (i += 1) result += @popCount(LimbType, self.limbs[i]);
            return result;
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
            // TODO: replace with @reduce when language supports it
            // NOTE: following line doesn't work for usize/isize limb types
            const limbs_eq = self.limbs == other.limbs;
            var i: usize = 0;
            var result = true;
            while (result and i < limb_count) : (i += 1) result = limbs_eq[i];
            return result;
        }

        pub fn clear(self: *Self) void {
            self.limbs = @splat(limb_count, @as(LimbType, 0));
        }

        pub fn toEnums(self: Self, a: *std.mem.Allocator) ![]T {
            return try self.translate(a, T);
        }

        pub fn translate(self: Self, a: *std.mem.Allocator, comptime To: type) ![]To {
            const ct = self.count();
            var result = try a.alloc(To, ct);
            // const result_start_ptr = result.ptr;
            // var limb_i: usize = 0;
            // while (limb_i < limb_count) : (limb_i += 1) {
            //     var limb = self.limbs[limb_i];
            //     var bit_i: usize = 0;
            //     while (limb > 0 and bit_i < limb_bit_count) : (bit_i += 1) {
            //         if (limb & 1 == 1) {
            //             result[0] = @intToEnum(To, @intCast(@TagType(T), limb_i * limb_bit_count + bit_i));
            //             result.ptr += 1;
            //         }
            //         limb >>= 1;
            //     }
            // }
            // result.ptr = result_start_ptr;
            const result_start_ptr = result.ptr;
            const as_bit_vec = self.asBitVec();
            var i: usize = 0;
            while (i < ct) : (i += 1) {
                if (as_bit_vec[i]) {
                    result[0] = @intToEnum(To, @intCast(@TagType(T), i));
                    result.ptr += 1;
                }
            }
            result.ptr = result_start_ptr;
            return result;
        }

        pub fn asBitVec(self: Self) @Vector(limb_bit_count, bool) {
            return @bitCast(@Vector(limb_bit_count, bool), self.limbs);
        }
    };
}

test "bitset with enum" {
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

    // my_set.printLimbs();
}

test "bitset with huge enum" {
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

test "translate / toEnums" {
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
    testing.expect(std.mem.eql(E, &[_]E{ .A, .B, .C }, try e.toEnums(al)));

    testing.expect(std.mem.eql(F, &[_]F{ .D, .E, .F }, try e.translate(al, F)));
}

test "asArray" {
    const E = enum {
        A,
        B,
        C,
    };
    const ESet = EnumSet(E);
    var e = ESet.init(.{ .A, .B, .C });

    var bit_vec = e.asBitVec();
    testing.expect(bit_vec[0]);
    testing.expect(bit_vec[1]);
    testing.expect(bit_vec[2]);
    e.unset(.{.A});
    bit_vec = e.asBitVec();
    testing.expect(!bit_vec[0]);
    testing.expect(bit_vec[1]);
    testing.expect(bit_vec[2]);
}
