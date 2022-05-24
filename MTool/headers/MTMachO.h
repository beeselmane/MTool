#import <Foundation/Foundation.h>
#import <MTool/MTType.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTMachO : NSObject

// Return an array describing all Mach-O images in the given process space (as far as dyld is aware)
+ (NSArray<NSDictionary<NSString *, id> *> *) imageListFromProcess:(pid_t)process;

// Create an object from a loaded image in an existing process (from memory)
+ (instancetype) loadFromImageInProcess:(NSDictionary<NSString *, id> *)imageInfo;

+ (instancetype) loadFromMemoryAt:(void *)location maxSize:(NSUInteger)size;

// Create an object from a mach-o file on disk.
+ (instancetype) loadFromURL:(NSURL *)url;

@property (nonatomic, readonly) BOOL is64bit;

@property (nonatomic, readonly) MTMachineType type;

@end

NS_ASSUME_NONNULL_END
