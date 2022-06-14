#import <Foundation/Foundation.h>
#import <MTool/MTType.h>

// For vm_address_t, vm_size_t, vm_prot
#import <mach/vm_types.h>

// For pid_t
#import <sys/types.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTMappedRegion : NSObject
// Is this mapping from a mmap'd file?
@property (readonly, nonatomic) BOOL isFileRegion;

// Is this mapping a region from another task?
@property (readonly, nonatomic) BOOL isTaskRegion;

// Base address of this mapping in it's source (mapped file or other task)
@property (readonly, nonatomic) vm_address_t sourceBase;

// The base address of this mapping in this task's address space
@property (readonly, nonatomic) vm_address_t base;

// The address of the last byte in this region
@property (readonly, nonatomic) vm_address_t end;

// Current memory protection on this region
@property (readonly, nonatomic) vm_prot_t protection;

// The size of this mapping
@property (readonly, nonatomic) vm_size_t size;

+ (instancetype) regionFromTask:(mach_port_name_t)port containing:(vm_address_t)address;

+ (instancetype) regionFromProcess:(pid_t)pid containing:(vm_address_t)address;

+ (instancetype) regionInMappedFile:(void *)base from:(off_t)offset size:(size_t)size writable:(BOOL)write executable:(BOOL)exec;

- (NSString *) description;

@end

NS_ASSUME_NONNULL_END
