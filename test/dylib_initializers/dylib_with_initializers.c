#include <stdlib.h>
#include <stdio.h>

__attribute__((constructor)) void dylib_init_1(void)
{
    printf("%s\n", __PRETTY_FUNCTION__);
}

__attribute__((constructor)) void dylib_init_2(void)
{
    printf("%s\n", __PRETTY_FUNCTION__);
}

__attribute__((constructor)) void dylib_init_3(void)
{
    printf("%s\n", __PRETTY_FUNCTION__);
}

