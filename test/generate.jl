f = open("test/myflags.zig", "w")
write(f, "pub const MyFlags = enum {")
for s1 in 'A':'Z', s2 in 'A':'Z'
    write(f, "$(s1)$(s2), \n")
end
write(f, "};")
close(f)


f = open("test/my_huge_enum.zig", "w")
write(f, "pub const HugeEnum = enum {")
for s1 in 'A':'Z', s2 in 'A':'Z', s3 in 'A':'Z'
    write(f, "$(s1)$(s2)$(s3), \n")
end
write(f, "};")
close(f)