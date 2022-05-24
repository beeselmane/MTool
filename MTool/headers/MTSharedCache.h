#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTSharedCache : NSObject

+ (instancetype) currentSharedCache;

// This will mmap the file at the provided URL
+ (instancetype) loadFromURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
