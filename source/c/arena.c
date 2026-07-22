#include <stdbool.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>

size_t getPageSize(void) {
    return sysconf(_SC_PAGESIZE);
}

void *reserveMemory(size_t sizeToReserve) {
    if ((size_t)sizeToReserve % getPageSize() != 0) {
        fprintf(stderr, "%s: sizeToReserve not a multiple of page size : %lu %% %lu != 0\n",
                __PRETTY_FUNCTION__, sizeToReserve, getPageSize());
        return NULL;
    }
    void *reserved = mmap(NULL, sizeToReserve, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (reserved == MAP_FAILED) return NULL;
    return reserved;
}

void freeMemory(void *reservedMemoryBase, size_t reservedSize) {
    munmap(reservedMemoryBase, reservedSize);
}

bool commitMemory(void *commitStartAddress, size_t sizeToCommit) {
    if ((size_t)commitStartAddress % getPageSize() != 0) {
        fprintf(stderr, "%s: commitStartAddress not aligned to page boundary : %p %% %lu != 0\n",
                __PRETTY_FUNCTION__, (char*)commitStartAddress, getPageSize());
        return false;
    }
    if ((size_t)sizeToCommit % getPageSize() != 0) {
        fprintf(stderr, "%s: sizeToCommit not a multiple of page size : %lu %% %lu != 0\n",
                __PRETTY_FUNCTION__, sizeToCommit, getPageSize());
        return false;
    }
    return mprotect(commitStartAddress, sizeToCommit, PROT_READ | PROT_WRITE) == 0;
}
