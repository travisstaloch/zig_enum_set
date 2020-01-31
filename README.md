### Enum Set
A library which provides enum set and iteration operations without allocation.

### Quidk Start
```console
  zig build install    # (default) Copy build artifacts to prefix path
  zig build uninstall  #           Remove build artifacts from prefix path
  zig build gen        #           Generate test files (depends on julia: https://julialang.org) 
  zig build clean      #           Remove test files
  zig build test       #           Run library tests
```

### Usage

```zig
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
```

### Ideas
- [] toVector