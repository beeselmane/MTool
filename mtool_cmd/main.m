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

#import <LibObjC/LibObjC.h>

#import <MTool/MTFatFile.h>
#import <MTool/MTMachO.h>

#import <mach-o/dyld_cache_format.h>

#import "mtool.h"

@interface MToolCommand : NXCommand

- (MTMachO *) findBinaryInProcess:(pid_t)pid withNameSuffix:(NSString *)suffix;

@end

@implementation MToolCommand

- (MTMachO *) findBinaryInProcess:(pid_t)pid withNameSuffix:(NSString *)suffix
{
    NSArray<NSDictionary<NSString *, id> *> *images = [MTMachO imageListFromProcess:pid];

    for (NSDictionary<NSString *, id> *image in images)
    {
        if (![[image objectForKey:@"valid"] boolValue])
            continue;

        if ([[image objectForKey:@"path"] hasSuffix:suffix])
            return [MTMachO loadFromImageInProcess:image];
    }

    return nil;
}

- (int) invoke
{
    NSLog(@"MTool invoked with state:");
    NSLog(@"Arguments: %@", [self args]);
    NSLog(@"Environment: %@", [self environment]);
    NSLog(@"Apple: %@", [self appleStrings]);

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

    // Unfortunately, Apple is no fun and forbids task_for_pid() for system processes under SIP.
    // I mean fine, *technically* this is more secure, but it's also not very *fun*...
    [self findBinaryInProcess:1 withNameSuffix:@"launchd"];

    MTMachineType type, subtype;

    if (!MTMachinePairGetCurrent(&type, &subtype))
    {
        NSLog(@"Failed to get current machine pair!");

        return 1;
    }

    // We can use this to run some test tooling for our native arch
    NSString *currentArch = MTMachinePairToArchName(type, subtype);
    NSLog(@"Current CPU arch: %@ (%@, %@)", currentArch, MTMachineTypeToString(type), MTMachinePairSubtypeName(type, subtype));

    // This isn't nearly as cool since everything is already in our address space...
    [self findBinaryInProcess:getpid() withNameSuffix:@"mtool"];
    [self findBinaryInProcess:getpid() withNameSuffix:@"libSystem.B.dylib"];

    return 0;
}

@end

int main(int argc, char *const *argv, char *const *envp, char *const *apple)
{
    return NXCommandMain(NSStringFromClass([MToolCommand class]), argc, argv, apple);
}
