#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTProcess : NSObject

+ (NSArray<MTProcess *> *) allProcesses;

+ (instancetype) processFromId:(pid_t)pid;

@end

NS_ASSUME_NONNULL_END
