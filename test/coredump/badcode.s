.globl _main
.align 16

_main:
#ifdef __x86_64__
    ud2
#elif defined(__arm64__)
    udf #0xdead
#else
    #error Unsupported Architecture
#endif
    ret
    
