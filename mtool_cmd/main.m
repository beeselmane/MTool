// This program will depend on the Mach-O ABI defined in the following locations:
// 1. clang
// 2. ld64
// 3. cctools
// 4. dyld
// 5. objc4
// 6. xnu
// 7. the c++ runtime
// 8. swift
//
// These are the main pieces of the build toolchain/OS that touch mach-o files.
// They should collectively provide a full "documentation" of how mach-o files work.

#import <Foundation/Foundation.h>
#import <MTool/MTFatFile.h>
#import <MTool/MTMachO.h>

#import <sys/sysctl.h>
#import <libproc.h>

#import <mach-o/dyld_cache_format.h>

#import "mtool.h"

NSArray *allProcesses(void)
{
    size_t count = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t *pid_list = calloc(count, sizeof(pid_t));

    count = proc_listpids(PROC_ALL_PIDS, 0, pid_list, (int)count);

    NSMutableArray<NSDictionary<NSString *, id> *> *array = [[NSMutableArray alloc] initWithCapacity:count];

    for (size_t i = 0; i < count; i++)
    {
        char path[PROC_PIDPATHINFO_MAXSIZE];
        char name[2 * MAXCOMLEN];

        proc_pidpath(pid_list[i], path, PROC_PIDPATHINFO_MAXSIZE);
        proc_name(pid_list[i], name, 2 * MAXCOMLEN);

        [array insertObject:@{
            @"PID"  : @(pid_list[i]),
            @"Name" : [NSString stringWithUTF8String:name],
            @"Path" : [NSString stringWithUTF8String:path]
        } atIndex:i];
    }

    return [array copy];
}

MTMachO *MTTFindMainBinaryForPID(pid_t pid, NSString *suffix)
{
    NSArray<NSDictionary<NSString *, id> *> *images = [MTMachO imageListFromProcess:pid];

    for (NSDictionary<NSString *, id> *image in images)
    {
        if (![[image objectForKey:@"valid"] boolValue])
            continue;

        if ([[image objectForKey:@"path"] hasSuffix:suffix])
        {
            MTMachO *loadedObject = [MTMachO loadFromImageInProcess:image];

            return loadedObject;
        }
    }

    return nil;
}

int main(int argc, const char *const *argv, const char *const *envp, const char *const *apple)
{
    printf("argv:\n");
    int i;

    for (i = 0; i < argc; i++)
        printf("[%d]: %s\n", i, argv[i]);

    printf("\nenvp:\n");

    for (i = 0; envp[i]; i++)
        printf("[%d]: %s\n", i, envp[i]);

    printf("\napple:\n");

    for (i = 0; apple[i]; i++)
        printf("[%d]: %s\n", i, apple[i]);

    @autoreleasepool
    {
        NSError *error;

        NSArray<NSURL *> *caches = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:@"/System/Library/dyld"] includingPropertiesForKeys:nil options:0 error:&error];

        if (!caches)
        {
            NSLog(@"Couldn't find dyld caches!");

            return 1;
        }

        NSUInteger bufferSize = getpagesize();
        UInt8 *buffer = malloc(bufferSize);

        if (!buffer)
            return 2;

        for (NSURL *cacheFile in caches)
        {
            if (![[cacheFile path] containsString:@"arm64"])
                continue;

            if ([[cacheFile path] hasSuffix:@".map"])
                continue;

            NSInputStream *stream = [NSInputStream inputStreamWithURL:cacheFile];
            [stream open];

            NSInteger bytesRead = [stream read:buffer maxLength:bufferSize];
            [stream close];

            if (bytesRead == -1)
            {
                NSLog(@"Failed to read header for cache '%@'! (%@)", cacheFile, [stream streamError]);

                continue;
            }

            if (bytesRead < sizeof(struct dyld_cache_header))
            {
                NSLog(@"Failed to read header for cache '%@'!", cacheFile);

                continue;
            }

            struct dyld_cache_header *header = (struct dyld_cache_header *)buffer;

            NSLog(@"Magic: %s, cache: %@", header->magic, cacheFile);
        }

        MTCLipoCommand *lipo = [MTCLipoCommand commandWithArguments:nil];
        [lipo setInputFiles:@[@{
            @"name" : @"/bin/bash",
            @"url"  : [NSURL URLWithString:@"file:///bin/bash"]
        }, @{
            @"name" : @"/usr/lib/dyld",
            @"url"  : [NSURL URLWithString:@"file:///usr/lib/dyld"]
        }]];

        [lipo detailedInfo];

        [MTSharedCache currentSharedCache];

        MTTFindMainBinaryForPID(85129, @"pid");
        MTTFindMainBinaryForPID(98685, @"x86_64");
    }

    return 0;
}
