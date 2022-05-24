#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// I added a nice method to write a full input stream to an output stream.
@interface NSInputStream (MTPipe)

- (BOOL) transferTo:(NSOutputStream *)stream maxBytes:(NSUInteger)size;

- (BOOL) transferTo:(NSOutputStream *)stream;

@end

NS_ASSUME_NONNULL_END
