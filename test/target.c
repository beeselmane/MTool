#include <mach/machine.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

const char *cputype(void)
{
    size_t size = sizeof(cpu_type_t);
    cpu_type_t cpu_type;

    if (sysctlbyname("hw.cputype", &cpu_type, &size, NULL, 0))
    {
        perror("sysctlbyname");

        return "<unknown>";
    }

    printf("Raw CPU type: 0x%08X\n", cpu_type);

    switch (cpu_type)
    {
        case CPU_TYPE_X86:      return "x86";
        case CPU_TYPE_X86_64:   return "x86_64";
        case CPU_TYPE_ARM:      return "ARM";
        case CPU_TYPE_ARM64:    return "AArch64";
        default:                return "<unknown>";
    }
}

__attribute__((noreturn)) int main(void)
{
    fprintf(stderr, "Hello from arch %s, pid %u!\n", cputype(), getpid());

    for ( ; ; ) ;
}
