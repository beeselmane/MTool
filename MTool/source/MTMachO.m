#import <MTool/MTool.h>
#import <MTool/MTMachO.h>

#import <mach-o/dyld_process_info.h>
#import <mach-o/loader.h>

#import <mach/mach_traps.h>
#import <mach/machine.h>
#import <mach/vm_map.h>

@implementation MTMachO

+ (NSArray<NSDictionary<NSString *, id> *> *) imageListFromProcess:(pid_t)process
{
    NSUInteger pageSize = getpagesize();
    mach_port_name_t task;

    kern_return_t result = task_for_pid(mach_task_self(), process, &task);

    if (result != KERN_SUCCESS)
    {
        NSLog(@"task_for_pid(): %s", mach_error_string(result));

        return @[];
    }

    // We must always be able to read at least one page.
    NSUInteger bufferSize = (pageSize > sizeof(struct mach_header_64)) ? pageSize : sizeof(struct mach_header_64);
    dyld_process_info info = _dyld_process_info_create(task, 0, &result);

    NSMutableArray *array = [[NSMutableArray alloc] init];
    UInt8 *buffer = malloc(bufferSize);

    if (!buffer)
    {
        _dyld_process_info_release(info);

        return @[];
    }

    _dyld_process_info_for_each_image(info, ^(uint64_t machHeaderAddress, const unsigned char *uuid, const char *path) {
        mach_vm_size_t size = bufferSize;

        kern_return_t result = mach_vm_read_overwrite(task, machHeaderAddress, bufferSize, (mach_vm_address_t)buffer, &size);

        if (result != KERN_SUCCESS) {
            NSLog(@"mach_vm_read_overwrite(): %s", mach_error_string(result));

            [array addObject:@{
                @"task"             : @(task),
                @"path"             : [NSString stringWithUTF8String:path],
                @"image-location"   : @(machHeaderAddress),
                @"valid"            : @(NO)
            }];
        } else {
            [array addObject:@{
                @"task"             : @(task),
                @"path"             : [NSString stringWithUTF8String:path],
                @"image-location"   : @(machHeaderAddress),
                @"valid"            : @(YES),
                @"header"           : [NSData dataWithBytes:buffer length:size]
            }];
        }
    });

    _dyld_process_info_release(info);
    free(buffer);

    return [array copy];
}

// Note: We make some assumptions about the types of images that can be in other processes's address space.
// Specifically, we assume there are only 64-bit images which aren't object files,
//   core files, or dsym files. Other than that, we should be able to grab everything.
+ (instancetype) loadFromImageInProcess:(NSDictionary<NSString *, id> *)imageInfo
{
    if (![[imageInfo objectForKey:@"valid"] boolValue])
    {
        NSLog(@"Can't load invalid image!");

        return nil;
    }

    // We need at least a task and an offset into the task's vm space to load an image.
    if (![imageInfo objectForKey:@"task"] || ![imageInfo objectForKey:@"image-location"])
    {
        NSLog(@"Not enough information provided to get image from process!");

        return nil;
    }

    // Who and where are we getting our image from?
    mach_port_name_t targetTask = (mach_port_name_t)[[imageInfo objectForKey:@"task"] integerValue];
    mach_vm_address_t target = (mach_vm_address_t)[[imageInfo objectForKey:@"image-location"] pointerValue];

    // Note: This may be nil
    NSString *path = [imageInfo objectForKey:@"path"];
    pid_t pid;

    // This is just used for diagnostics.
    kern_return_t result = pid_for_task(targetTask, &pid);

    if (result == KERN_SUCCESS) {
        NSLog(@"Loading image '%@' from pid %d (task %u) from address 0x%08llX...", path, pid, targetTask, target);
    } else {
        NSLog(@"Loading image '%@' from pid ??? (task %u) from address 0x%08llX...", path, targetTask, target);
    }

    // Map the target header into our task's address space
    MTMappedRegion *headerRegion = [MTMappedRegion regionFromTask:targetTask containing:target];

    if (!headerRegion)
        return nil;

    // Make sure we get at least a mach-o image header.
    if ([headerRegion size] < sizeof(struct mach_header_64))
    {
        NSLog(@"Provided memory region too small for image header!");

        return nil;
    }

    NSLog(@"Mach-O header located in %@", headerRegion);

    // Figure out the offset of the Mach-O header in the mapped region.
    // Note: I do think XNU enforces this to be 0, but we can handle if not.
    mach_vm_offset_t headerOffset = target - [headerRegion sourceBase];

    // This is now in our task's address space
    vm_address_t headerBase = [headerRegion base] + headerOffset;
    struct mach_header_64 *header = (struct mach_header_64 *)headerBase;

    // Make sure we have a valid Mach-O header before doing anything else.
    // Note: We only support native endian 64-bit images here.
    // If you have more than that in your address space, you're doing something weird...
    if (header->magic != MH_MAGIC_64)
    {
        NSLog(@"Mach-O header magic value malformed!");

        return nil;
    }

    NSLog(@"Mach-O image has %u load commands taking up %u bytes. Flags: 0x%08X", header->ncmds, header->sizeofcmds, header->flags);

    NSLog(@"Mach-O is for architecture '%@'", MTMachineTypeToString(header->cputype));

    // Check some flags and things to ensure we know what to do with the image we've found.
    BOOL isCached;
    BOOL isPie;

    if (!(header->cputype & CPU_ARCH_ABI64))
    {
        // We can't handle 32-bit in process images for now.
        NSLog(@"Mach-O image CPU_ARCH_ABI64 unset!");

        return nil;
    }

    switch (header->filetype)
    {
        case MH_EXECUTE: {
            // On some machine type/subtype pairs, this is actually required by XNU.
            // We aren't so strict since our goal is mainly introspection.
            isPie = !!(header->flags & MH_PIE);

            // dyld shared cache doesn't include executables.
            isCached = NO;

            NSLog(@"Mach-O image is of type 'MH_EXECUTE'");
        } break;
        case MH_DYLIB: {
            // Some mapped dylibs are sourced from the shared cache
            isCached = !!(header->flags & MH_DYLIB_IN_CACHE);

            // dylibs essentially need to be position independent
            isPie = YES;

            NSLog(@"Mach-O image is of type 'MH_DYLIB'");
        } break;
        case MH_DYLINKER:
        case MH_BUNDLE: {
            // Neither of these can be cached.
            isCached = NO;

            // These need to be position independednt
            isPie = YES;

            // These are pretty normal. Don't complain.
            NSLog(@"Mach-O image is of type '0x%02X'", header->filetype);
        } break;
        default: {
            NSLog(@"Found 'weird' Mach-O image of type '0x%02X'... This may not work...", header->filetype);

            // Assume these can't be cached
            isCached = NO;

            // Assume these can be anywhere
            isPie = YES;
        } break;
    }

    if (isCached)
    {
        NSLog(@"Found cached image while laoding from process!");

        // We can't handle this now. The load commands don't appear like normal...
        return nil;
    }

    // The load commands need to fall in the same map we just grabbed, otherwise we
    //   wouldn't be able to locate them. Technically, I do think the kernel would be
    //   able to load a Mach-O image with load commands/header in various segments,
    //   but no standard tools create such images, and they don't make much sense.
    // In any case, we assume load commands and header fall in the same segment.
    // After checking mach_loader.c in XNU source, it appears the kernel only ensures
    //   there exists some segment mapping the header. I don't know if this is really
    //   enough, to ensure we can process all valid Mach-O files, but oh well...
    if (sizeof(struct mach_header_64) + header->sizeofcmds > ([headerRegion size] - headerOffset))
    {
        NSLog(@"Mapped region is too small for Mach-O header and load commands!");

        return nil;
    }

    // Now we need to go through the load commands and find the other segments from this image.
    // We need to do two passes to do this:
    //   First, we need to find the segment command mapping the file header.
    //     Then, we can calculate the slide value for the binary. The slide is simply
    //       the real vmaddr for the header map - expected vmaddr for the header map.
    //   Second, now that we have slide, we can find other segments by finding all
    //      LC_SEGMENT{,_64} commands, and they should be located in the target space
    //      at the offset vmaddr in the load command + slide calculated in step 1.
    // Effectively, we reverse the algorithm used by the kernel to load segemnts in
    //   memory. I've read the algorithm used in bsd/mach_loader.c and reverse it here.

    BOOL foundHeaderSegment = NO;
    uint32_t segmentCount = 1;
    int64_t slide = 0;

    for (int pass = 0; pass < 2; pass++)
    {
        // Non-PIE binaries can't be slid.
        if (pass == 0 && !isPie)
        {
            foundHeaderSegment = YES;
            slide = 0;

            continue;
        }

        size_t commandsEnd = sizeof(struct mach_header_64) + header->sizeofcmds;
        size_t offset = sizeof(struct mach_header_64);
        uint32_t ncmds = header->ncmds;

        while (ncmds--)
        {
            if (offset + sizeof(struct load_command) > commandsEnd)
            {
                NSLog(@"Found load commands past end of expected section!");

                return nil;
            }

            struct load_command *loadCommand = (struct load_command *)([headerRegion base] + offset);
            offset += loadCommand->cmdsize;

            if (offset > commandsEnd || loadCommand->cmdsize < sizeof(struct load_command))
            {
                NSLog(@"Found command with too small/large size in image!");

                return nil;
            }

            // Look for segment commands
            switch (loadCommand->cmd)
            {
                case LC_SEGMENT_64: {
                    if (loadCommand->cmdsize < sizeof(struct segment_command_64))
                    {
                        NSLog(@"Found undersized segment command (64 bit) in image!");

                        return nil;
                    }

                    struct segment_command_64 *segment = (struct segment_command_64 *)loadCommand;

                    if (pass == 0) {
                        if (segment->fileoff == 0 && segment->filesize > 0) {
                            if (foundHeaderSegment)
                            {
                                NSLog(@"Found two segments mapping image header!");

                                return nil;
                            }

                            // Slide is the offset from the expected vmaddr in the target task's address space.
                            slide = target - segment->vmaddr;

                            NSLog(@"Found segment '%.16s' mapping file header!", segment->segname);
                            NSLog(@"Calculated image slide: 0x%08llX", slide);

                            foundHeaderSegment = YES;
                        } else if (segment->filesize > 0) {
                            segmentCount++;
                        }
                    } else { // pass == 1
                        if (segment->filesize > 0 && segment->fileoff != 0)
                        {
                            vm_address_t slidBase = segment->vmaddr + slide;

                            NSLog(@"Found segment '%.16s'", segment->segname);
                            NSLog(@"Should be mapped at 0x%08llX --> 0x%08lX", segment->vmaddr, slidBase);
                        }
                    }
                } break;
                // Skip non-segment load commands
                default:
                    NSLog(@"Found load command: %@", MTMachOLoadCommandName(loadCommand->cmd));
                    break;
            }
        }

        if (pass == 0)
        {
            if (!foundHeaderSegment)
            {
                NSLog(@"Didn't find load command mapping header segment in image!");

                return nil;
            }

            NSLog(@"Found %u segments in image", segmentCount);
        }
    }

    return nil;
}

@end
