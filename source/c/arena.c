#include <stdio.h>
// #include <sys/mman.h>
#include <unistd.h>

void foo() {
    printf("Page size is %ld\n", sysconf(_SC_PAGESIZE));
}
