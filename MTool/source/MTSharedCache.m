#import <MTool/MTSharedCache.h>
#import <Foundation/Foundation.h>

#import <mach-o/dyld_cache_format.h>
#import <mach/shared_region.h>

// shared_region_check_np is declared in shared_region.h above, but __shared_region_check_np
//   is the actual function dyld uses to check for the shared cache...
extern int __shared_region_check_np(uint64_t *startaddress);

@implementation MTSharedCache

+ (instancetype) currentSharedCache
{
    uint64_t startAddress;
    int status;

    if ((status = __shared_region_check_np(&startAddress)))
    {
        NSLog(@"No shared cache found! (status=%d)", status);

        return nil;
    }

    struct dyld_cache_header *header = (struct dyld_cache_header *)startAddress;

    //

    MTSharedCache *cache = [[MTSharedCache alloc] init];

    if (cache)
    {
        //
    }

    return cache;
}

- (BOOL) readFromMemory:(void *)address isLoaded:(BOOL)isLoaded
{
    return YES;
}

@end
