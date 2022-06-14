#include <unistd.h>
#include <stdio.h>

__attribute__((noreturn)) int main(void)
{
    pid_t pid = getpid();

    fprintf(stderr, "%u\n", pid);

    for ( ; ; )
        ;
}
