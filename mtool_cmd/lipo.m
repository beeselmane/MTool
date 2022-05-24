#import "mtool.h"

@implementation MTCLipoCommand

@synthesize inputFiles = _inputFiles;
@synthesize outputURL = _outputURL;

- (void) detailedInfo
{
    for (NSDictionary<NSString *, id> *file in [self inputFiles])
    {
        NSString *name = [file objectForKey:@"name"];
        NSURL *url = [file objectForKey:@"url"];

        if (!url)
        {
            printf("Error: Invalid input dictionary %s!", [[file description] UTF8String]);

            continue;
        }

        if (!name)
            name = [url path];

        MTFatFile *fatFile = [MTFatFile loadFromURL:url];

        if (!fatFile)
        {
            // TODO: Thin files
            printf("input file %s is not a fat file\n", [name UTF8String]);

            continue;
        }

        UInt32 magic = MTSwapToHostEndian(*((UInt32 *)[[fatFile magic] bytes]));

        printf("Fat header in: %s\n", [name UTF8String]);
        printf("fat_magic: 0x%x\n", magic);
        printf("nfat_arch %u\n", (UInt32)[[fatFile members] count]); // TODO: +hidden

        for (MTFatFileEntryDescriptor *entry in [fatFile members])
        {
            NSString *arch = MTMachinePairToArchName([entry type], [entry subtype]);
            NSString *subtype = MTMachinePairSubtypeName([entry type], [entry subtype]);
            NSString *type = MTMachineTypeToString([entry type]);
            NSString *capabilities = MTMachinePairGetCapabilitiesString([entry type], [entry subtype]);

            printf("architecture %s\n", [arch UTF8String]);
            printf("    cputype %s\n", [type UTF8String]);
            printf("    cpusubtype %s\n", [subtype UTF8String]);
            printf("    capabilities %s\n", [capabilities UTF8String]);
            printf("    offset %llu\n", [entry offset]);
            printf("    size %llu\n", [entry size]);
            printf("    align 2^%u (%d)\n", [entry alignment], (SInt32)[entry trueAlignment]);
        }
    }
}

- (int) invoke
{
    // We process arguments similarly to Apple's lipo binary.
    // That is, not well.
    for (NSString *arg in [self args])
    {
        if ([arg hasPrefix:@"-"]) {
            // Command arguments
        } else {
            //
        }
    }

    return 0;
}

@end
