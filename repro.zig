//
// $ zig test repro.zig
// ./repro.zig:15:29: error: expected type '@Vector(4, u64)', found '@Vector(4, usize)'
//             const eqs = self.limbs == other.limbs; // <--- here
//                             ^
// ./repro.zig:15:36: note: referenced here
//             const eqs = self.limbs == other.limbs; // <--- here
//                                    ^
//

test "repro: vector == with usize/isize" {
    const S = struct {
        limbs: @Vector(4, usize), // this error also occurs with isize
        pub fn equals(self: @This(), other: @This()) bool {
            // error: expected type '@Vector(1, u64)', found '@Vector(1, usize)'
            const eqs = self.limbs == other.limbs; // <--- here
            return true;
        }
    };
    const s1 = S{ .limbs = @splat(4, @as(usize, 0)) };
    const s2 = S{ .limbs = @splat(4, @as(usize, 0)) };
    const eqs = s1.limbs == s2.limbs; // here == with usize vectors is ok
    const eq = s1.equals(s2);
}
