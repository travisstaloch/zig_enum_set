const std = @import("std");
const warn = std.debug.warn;

pub fn Bits(comptime T: type) type {
    return struct {
        value: T,
        current: ShiftType = 0,
        finished: bool = false,

        const Self = @This();
        pub const len = @bitSizeOf(T);
        pub const byte_len = std.math.max(if (len % 8 == 0) len else len + len % 8, 8);
        pub const ByteAlignedT = @IntType(false, byte_len);
        pub const ShiftType = @IntType(false, std.math.log2_int_ceil(usize, len));

        pub fn init(value: T) Self {
            // @compileLog(byte_len, ByteAlignedT);
            return .{ .value = value };
        }

        pub fn initZero() Self {
            return init(0);
        }

        pub fn reset(self: *Self) void {
            self.current = 0;
            self.finished = false;
        }

        pub fn next(self: *Self) ?u1 {
            if (self.finished) return null;
            const result = @truncate(u1, self.value >> self.current);
            if (self.current >= len - 1) {
                self.finished = true;
            } else self.current += 1;
            return result;
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

        pub fn byteViewSlice(self: Self) *const [byte_len / 8]ByteView {
            return @ptrCast(*align(1) const [byte_len / 8]ByteView, &self.value);
        }

        pub fn toSlice(self: Self) *const [byte_len / 8]u8 {
            return @ptrCast(*align(1) const [byte_len / 8]u8, &self.value);
        }

        pub fn at(self: Self, index: usize) ?u1 {
            if (index >= len) return null;
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

const testing = std.testing;

test "iterate get / set" {
    const E = @import("../test/myflags.zig").MyFlags;
    const EnumSet = @import("enum_set.zig").EnumSet;
    const ESE = EnumSet(E);
    var e = ESE.init(.{ .AA, .ZZ });
    const ValType = @IntType(false, ESE.member_count);
    var value: ValType = 1;

    const BitsType = Bits(ValType);
    var bits = BitsType.init(value);
    for ([_]u8{ 20, 40, 41 }) |i| {
        bits.set(i);
        testing.expect(bits.at(i).? == 1);
    }
    var i: usize = 0;
    while (bits.next()) |b| : (i += 1) {
        testing.expect(b == bits.at(i).?);
    }

    for (bits.byteViewSlice()) |bv, j| {
        if (bits.at(j * 8 + 0)) |at| testing.expect(bv._0 == at);
        if (bits.at(j * 8 + 1)) |at| testing.expect(bv._1 == at);
        if (bits.at(j * 8 + 2)) |at| testing.expect(bv._2 == at);
        if (bits.at(j * 8 + 3)) |at| testing.expect(bv._3 == at);
        if (bits.at(j * 8 + 4)) |at| testing.expect(bv._4 == at);
        if (bits.at(j * 8 + 5)) |at| testing.expect(bv._5 == at);
        if (bits.at(j * 8 + 6)) |at| testing.expect(bv._6 == at);
        if (bits.at(j * 8 + 7)) |at| testing.expect(bv._7 == at);
    }

    for (bits.toSlice()) |byte, j| {
        if (bits.at(j * 8 + 0)) |at| testing.expect((byte >> 0) & 1 == at);
        if (bits.at(j * 8 + 1)) |at| testing.expect((byte >> 1) & 1 == at);
        if (bits.at(j * 8 + 2)) |at| testing.expect((byte >> 2) & 1 == at);
        if (bits.at(j * 8 + 3)) |at| testing.expect((byte >> 3) & 1 == at);
        if (bits.at(j * 8 + 4)) |at| testing.expect((byte >> 4) & 1 == at);
        if (bits.at(j * 8 + 5)) |at| testing.expect((byte >> 5) & 1 == at);
        if (bits.at(j * 8 + 6)) |at| testing.expect((byte >> 6) & 1 == at);
        if (bits.at(j * 8 + 7)) |at| testing.expect((byte >> 7) & 1 == at);
    }
}
