import core.stdc.stdio;

import numem;
import numem.heap;

extern (C) @nogc {
    size_t getPageSize();
    void* reserveMemory(size_t sizeToReserve);
    void freeMemory(void* reservedMemoryBase, size_t reservedSize);
    bool commitMemory(void* commitStartAddress, size_t sizeToCommit);
}

enum FOUR_GIGABYTES = 4 * (1LU << 30);

struct ArenaAllocator {
    @nogc:

    void* baseAddress = null;
    size_t reservedSize = 0;
    size_t committedSize = 0;
    size_t usedSize = 0;

    void reserve(size_t sizeToReserve = FOUR_GIGABYTES) {
        baseAddress = reserveMemory(sizeToReserve);

        if (baseAddress == null) {
            fprintf(stderr, "%s: Failed to reserved arena memory of size %ld\n", __PRETTY_FUNCTION__.ptr, sizeToReserve);
            return;
        }

        reservedSize = sizeToReserve;
        debug(Arena) printf("Reserved arena memory at address %p\n", baseAddress);
    }

    void destroy() {
        debug(Arena) printf("Deleting arena memory %p\n", baseAddress);
        freeMemory(baseAddress, reservedSize);
    }

    void* alloc(size_t bytes) {
        if (reservedSize == 0) reserve();
        debug(Arena) printf("Allocating %ld bytes of memory, available %ld, used %ld\n", bytes, committedSize - usedSize, usedSize);
        while (committedSize - usedSize < bytes) {
            // Start at page size, then double it
            size_t sizeToCommit = (committedSize == 0) ? getPageSize() : committedSize;
            if (!commitMemory(baseAddress + committedSize, sizeToCommit))
                return null;
            debug(Arena) printf("Commited %ld bytes of memory\n", sizeToCommit);
            committedSize += sizeToCommit;
        }
        void* returnAddress = baseAddress + usedSize;
        debug(Arena) printf("Return address for allocation is %p\n", returnAddress);
        usedSize += bytes;
        return returnAddress;
    }

    void reset() {
        usedSize = 0;
    }
}

struct Array(T) {
    ArenaAllocator arena;
    private size_t _count;

    void append(T t) {
        T* mem = cast(T*)arena.alloc(T.sizeof);
        if (mem == null) return;
        *mem = t;
        _count++;
    }

    size_t count() => _count;
    size_t count(size_t newCount) {
        assert(newCount <= count, "Cannot set an array to more elements than it has\n");
        arena.usedSize -= (count - newCount) * T.sizeof;
        _count = newCount;
        return newCount;
    }

    T[] asSlice() {
         return cast(T[])(cast(T*)arena.baseAddress)[0 .. _count];
    }
}

class ArenaHeap : NuHeap {
    @nogc:

    ArenaAllocator arena;
    this(size_t sizeToReserve = FOUR_GIGABYTES) {
        arena.reserve(sizeToReserve);
    }

    ~this() {
        arena.destroy();
    }

    override
    void* alloc(size_t bytes) {
        void* address = arena.alloc(bytes);
        debug(Arena) printf("%s: allocated %ld bytes at address %p\n", __PRETTY_FUNCTION__.ptr, bytes, address);
        return address;
    }

    override
    void* realloc(void* allocation, size_t bytes) {
        assert(0, "Unimplemented");
    }

    override
    void free(void* allocation) { }

    void reset() {
        arena.reset();
    }
}

class ObjectArena {
    @nogc:

    ArenaHeap heap;
    Array!Object allocatedObjects;

    this() {
        heap = nogc_new!ArenaHeap;
    }

    ~this() {
        debug(Arena) printf("Destroying arena containing %ld objects\n", allocatedObjects.count);
        foreach(i, obj; allocatedObjects.asSlice()) {
            nogc_delete!(Object, false)(obj);
        }
        nogc_delete(heap);
    }

    T make(T, Args...)(Args args) {
        auto o = nogc_new!T(heap: heap, args);
        debug(Arena) printf("Allocated object o with pointer %p\n", o);
        allocatedObjects.append(o);
        return o;
    }

    void reset() {
        debug(Arena) printf("Resetting arena containing %ld objects\n", allocatedObjects.count);
        foreach(i, obj; allocatedObjects.asSlice()) {
            nogc_delete!(Object, false)(obj);
        }
        allocatedObjects.count = 0;
        heap.reset();
    }
}

class A : I {
    @nogc:
    int i;

    this(int i) {
        this.i = i;
    }

    ~this() {
        printf("A %d died horribly\n", i);
    }

    void doThing() {
        printf("A %d does thing\n", i);
    }
}

class B : I {
    @nogc:

    void doThing() {
        printf("B does thing\n");
    }

    ~this() {
        printf("B died horribly\n");
    }
}

interface I {
    @nogc:
    void doThing();
}

void main() @nogc {
    auto objArena = nogc_new!ObjectArena();
    scope(exit) nogc_delete(objArena);
    foreach (j; 0..3) {
        Array!I itfs;
        objArena.reset();
        foreach (i; 0..4) {
            auto a = objArena.make!A(i);
            auto b = objArena.make!B();
            itfs.append(a);
            itfs.append(b);
        }
        foreach(i; itfs.asSlice()) {
            i.doThing();
        }
        printf("---\n\n");
    }
}
