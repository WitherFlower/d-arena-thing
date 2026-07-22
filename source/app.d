import core.stdc.stdio;

extern (C) void foo() @nogc;

struct Arena {
    void* base;
    size_t reserved;
    size_t committed;
    size_t offset;
}

void main() @nogc {
    foo();
}
