const std = @import("std");
const warn = std.debug.warn;

pub fn Bits(comptime T: type) type {
    return struct {
        value: T,
        current: ShiftType = 0,
        finished: bool = false,

        const Self = @This();
        pub const len = @bitSizeOf(T);
        pub const ShiftType = @IntType(false, std.math.log2_int_ceil(usize, len));

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        pub fn initZero() Self {
            return .{ .value = 0 };
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

        pub fn at(self: Self, index: ShiftType) ?u1 {
            if (index >= len) return null;
            return @truncate(u1, self.value >> index);
        }

        pub fn set(self: *Self, index: ShiftType) void {
            self.value |= (@as(T, 1) << index);
        }

        pub fn unset(self: *Self, index: ShiftType) void {
            self.value &= ~(@as(T, 1) << index);
        }
    };
}

const testing = std.testing;

test "iterate get / set" {
    const E = @import("../test/myflags.zig").MyFlags;
    const EnumSet = @import("enum_set.zig").EnumSet;
    const ESE = EnumSet(E);
    var e = ESE.init(.{ .AA, .ZZ });
    const BitsType = @IntType(false, ESE.member_count);
    var bits: BitsType = 1;

    const Itr = Bits(BitsType);
    var bititr = Itr.init(bits);
    for ([_]u8{ 20, 40, 41 }) |i| {
        bititr.set(i);
        testing.expect(bititr.at(i).? == 1);
    }
    var i: Itr.ShiftType = 0;
    warn("\n", .{});
    while (bititr.next()) |b| : (i += 1) {
        testing.expect(b == bititr.at(i).?);
    }
}
