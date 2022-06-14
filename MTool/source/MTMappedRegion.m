#import <MTool/MTool.h>
#import <MTool/MTMappedRegion.h>

#import <mach/mach_traps.h>
#import <mach/machine.h>
#import <mach/vm_map.h>

// For class_getName
#import <objc/runtime.h>

// We use this assertion to ensure we have enough space to use mach_vm_region
static_assert(VM_REGION_BASIC_INFO_COUNT_64 < sizeof(struct vm_region_basic_info_64), "vm_region structure size mismatch!!");

@implementation MTMappedRegion

@synthesize isFileRegion = _isFileRegion;
@synthesize isTaskRegion = _isTaskRegion;

@synthesize sourceBase = _sourceBase;

@synthesize protection = _protection;
@synthesize base = _base;
@synthesize size = _size;

@dynamic end;

+ (instancetype) regionFromTask:(mach_port_name_t)port containing:(vm_address_t)address
{
    // Get vm information for the region containing this address
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    struct vm_region_basic_info_64 regionInfo;
    mach_vm_address_t regionStart = address;
    mach_vm_size_t regionSize;
    kern_return_t result;
    mach_port_t object;

    if ((result = mach_vm_region(port, &regionStart, &regionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&regionInfo, &count, &object)) != KERN_SUCCESS)
    {
        NSLog(@"mach_vm_region: %s", mach_error_string(result));

        return nil;
    }

    // Remap the region into our task's address space
    mach_vm_address_t resultMap = 0;

    // Use the same protection as in the target task (+ ensure readable if not already)
    vm_prot_t protectionCurrent = regionInfo.protection | VM_PROT_READ;
    vm_prot_t protectionMax = regionInfo.max_protection | VM_PROT_READ;

    // VM_FLAGS_RETURN_DATA_ADDR tells the kernel to give us the address of mapped data
    //   instead of the base page offset (needs to be shifted by PAGE_SHIFT)
    int flags = VM_FLAGS_ANYWHERE | VM_FLAGS_RETURN_DATA_ADDR;

    // Actually remap the data
    if ((result = mach_vm_remap_new(mach_task_self(), &resultMap, regionSize, 0, flags, port, regionStart, false, &protectionCurrent, &protectionMax, VM_INHERIT_SHARE)))
    {
        NSLog(@"mach_vm_remap_new: %s", mach_error_string(result));

        return nil;
    }

    MTMappedRegion *region = [[MTMappedRegion alloc] init];

    if (region)
    {
        region->_isFileRegion = NO;

        region->_isTaskRegion = YES;

        region->_sourceBase = regionStart;

        region->_size = regionSize;

        region->_base = resultMap;

        region->_protection = protectionCurrent;
    }

    return region;
}

+ (instancetype) regionFromProcess:(pid_t)pid containing:(vm_address_t)address
{
    mach_port_name_t task;
    kern_return_t result;

    if ((result = task_for_pid(mach_task_self(), pid, &task)) != KERN_SUCCESS)
    {
        NSLog(@"task_for_pid: %s", mach_error_string(result));

        return nil;
    }

    return [self regionFromTask:task containing:address];
}

+ (instancetype) regionInMappedFile:(void *)base from:(off_t)offset size:(size_t)size writable:(BOOL)write executable:(BOOL)exec
{
    vm_prot_t protection = VM_PROT_READ | (write ? VM_PROT_WRITE : 0) | (exec ? VM_PROT_EXECUTE : 0);
    int flags = VM_FLAGS_ANYWHERE | VM_FLAGS_RETURN_DATA_ADDR;

    mach_vm_address_t regionStart = 0;
    mach_vm_size_t _size = size;

    // I would use mach_vm_copy here, but that would require we be page aligned.
    // As such, we need to make our own allocation and copy data to it directly.
    // This takes longer, but it is more "correct"
    // Although, we may want to look at just zeroing out the end of a region from
    //   mach_vm_copy, as this would likely take advantage of COW.
    kern_return_t result = mach_vm_allocate(mach_task_self(), &regionStart, _size, flags);

    if (result != KERN_SUCCESS)
    {
        NSLog(@"mach_vm_allocate: %s", mach_error_string(result));

        return nil;
    }

    // We need to write the new data, so ensure we enable writing here
    vm_prot_t tempProtection = VM_PROT_READ | VM_PROT_WRITE;

    result = mach_vm_protect(mach_task_self(), regionStart, _size, NO, tempProtection);

    if (result != KERN_SUCCESS)
    {
        NSLog(@"mach_vm_protect: %s", mach_error_string(result));

        return nil;
    }

    memcpy((void *)regionStart, base, size);

    // Now set the actual user protections requested (if necessary)

    if (protection != tempProtection)
    {
        result = mach_vm_protect(mach_task_self(), regionStart, _size, NO, protection);

        if (result != KERN_SUCCESS)
        {
            NSLog(@"mach_vm_protect: %s", mach_error_string(result));

            return nil;
        }
    }

    MTMappedRegion *region = [[MTMappedRegion alloc] init];

    if (region)
    {
        region->_isFileRegion = YES;

        region->_isTaskRegion = NO;

        region->_sourceBase = regionStart;

        region->_size = _size;

        region->_base = regionStart;

        region->_protection = protection;
    }

    return region;
}

- (vm_address_t) end
{
    return ([self base] + [self size]);
}

- (NSString *) description
{
    NSString *sourceName;

    if ([self isFileRegion]) {
        sourceName = @"mapped file";
    } else if ([self isTaskRegion]) {
        sourceName = @"remote task";
    } else {
        sourceName = @"unknown source";
    }

    return [NSString stringWithFormat:@"%s 0x%08lX-0x%08lX (0x%08lX bytes) from %@", class_getName([self class]), [self base], [self end], [self size], sourceName];
}

- (void) dealloc
{
    if (![self base])
        return;

    kern_return_t result = mach_vm_deallocate(mach_task_self(), [self base], [self size]);

    if (result != KERN_SUCCESS)
        NSLog(@"mach_vm_deallocate: %s", mach_error_string(result));
}

@end
