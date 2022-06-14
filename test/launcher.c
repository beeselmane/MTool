#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

int main(int argc, const char *const *argv)
{
    if (argc != 2)
    {
        fprintf(stderr, "Error: No forward binary!\n");

        exit(1);
    }

    const char *forward = argv[1];
    char *const *args = { NULL };
    char *const *envp = { NULL };

    fprintf(stderr, "Forwarding to binary '%s'...\n", forward);

    execve(forward, args, envp);

    perror("execve");

    return 1;
}

