const std = @import("std");
const warn = std.debug.warn;

pub fn Bits(comptime T: type) type {
    return struct {
        value: T,
        current: ShiftType = 0,
        finished: bool = false,

        const Self = @This();
        pub const bit_len = @bitSizeOf(T);
        pub const aligned_bit_len = std.math.max(if (bit_len % 8 == 0) bit_len else bit_len + bit_len % 8, 8);
        const ShiftType = @IntType(false, std.math.log2_int_ceil(usize, bit_len));

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        pub fn initZero() Self {
            return init(0);
        }

        pub fn reset(self: *Self) void {
            self.current = 0;
            self.finished = false;
        }

        pub fn nextBit(self: *Self) ?u1 {
            if (self.finished) return null;
            const result = @truncate(u1, self.value >> self.current);
            if (self.current >= bit_len - 1) {
                self.finished = true;
            } else self.current += 1;
            return result;
        }

        pub fn byteViewSlice(self: Self) *const [aligned_bit_len / 8]ByteView {
            return @ptrCast(*align(1) const [aligned_bit_len / 8]ByteView, &self.value);
        }

        pub fn toSlice(self: Self) *const [aligned_bit_len / 8]u8 {
            return @ptrCast(*align(1) const [aligned_bit_len / 8]u8, &self.value);
        }

        pub fn at(self: Self, index: usize) ?u1 {
            if (index >= bit_len) return null;
            return @truncate(u1, self.value >> @truncate(ShiftType, index));
        }

        pub fn set(self: *Self, index: usize) void {
            self.value |= (@as(T, 1) << @truncate(ShiftType, index));
        }

        pub fn unset(self: *Self, index: usize) void {
            self.value &= ~(@as(T, 1) << @truncate(ShiftType, index));
        }
    };
}

pub const ByteView = packed struct {
    _0: u1,
    _1: u1,
    _2: u1,
    _3: u1,
    _4: u1,
    _5: u1,
    _6: u1,
    _7: u1,
};

const testing = std.testing;

test "iterate get / set" {
    const E = @import("../test/myflags.zig").MyFlags;
    const EnumSet = @import("enum_set.zig").EnumSet;
    const ESet = EnumSet(E);
    var e = ESet.init(.{ .AA, .ZZ });
    const ValType = @IntType(false, ESet.member_count);
    var value: ValType = 1;

    const BitsType = Bits(ValType);
    var bits = BitsType.init(value);
    for ([_]u8{ 20, 40, 41 }) |i| {
        bits.set(i);
        const bit = bits.at(i) orelse break;
        testing.expect(bit == 1);
    }
    var i: usize = 0;
    while (bits.nextBit()) |b| : (i += 1) {
        const bit = bits.at(i) orelse break;
        testing.expect(b == bit);
    }

    comptime std.debug.assert(@sizeOf(ByteView) == 1);

    for (bits.byteViewSlice()) |byte_view, j| {
        if (bits.at(j * 8 + 0)) |bit| testing.expect(byte_view._0 == bit);
        if (bits.at(j * 8 + 1)) |bit| testing.expect(byte_view._1 == bit);
        if (bits.at(j * 8 + 2)) |bit| testing.expect(byte_view._2 == bit);
        if (bits.at(j * 8 + 3)) |bit| testing.expect(byte_view._3 == bit);
        if (bits.at(j * 8 + 4)) |bit| testing.expect(byte_view._4 == bit);
        if (bits.at(j * 8 + 5)) |bit| testing.expect(byte_view._5 == bit);
        if (bits.at(j * 8 + 6)) |bit| testing.expect(byte_view._6 == bit);
        if (bits.at(j * 8 + 7)) |bit| testing.expect(byte_view._7 == bit);
    }

    for (bits.toSlice()) |byte, j| {
        if (bits.at(j * 8 + 0)) |bit| testing.expect((byte >> 0) & 1 == bit);
        if (bits.at(j * 8 + 1)) |bit| testing.expect((byte >> 1) & 1 == bit);
        if (bits.at(j * 8 + 2)) |bit| testing.expect((byte >> 2) & 1 == bit);
        if (bits.at(j * 8 + 3)) |bit| testing.expect((byte >> 3) & 1 == bit);
        if (bits.at(j * 8 + 4)) |bit| testing.expect((byte >> 4) & 1 == bit);
        if (bits.at(j * 8 + 5)) |bit| testing.expect((byte >> 5) & 1 == bit);
        if (bits.at(j * 8 + 6)) |bit| testing.expect((byte >> 6) & 1 == bit);
        if (bits.at(j * 8 + 7)) |bit| testing.expect((byte >> 7) & 1 == bit);
    }
}
