#import <Foundation/Foundation.h>
#import <MTool/NSStream+pipe.h>

@implementation NSInputStream (MTPipe)

- (BOOL) transferTo:(NSOutputStream *)stream maxBytes:(NSUInteger)size
{
    NSUInteger transferred = 0;
    UInt8 buffer[PAGE_SIZE];

    while ([self hasBytesAvailable] && transferred < size)
    {
        NSUInteger length = (size - transferred > PAGE_SIZE) ? PAGE_SIZE : (size - transferred);

        NSInteger count = [self read:buffer maxLength:length];
        if (count <= 0) return NO;

        count = [stream write:buffer maxLength:count];
        if (count <= 0) return NO;
    }

    return YES;
}

- (BOOL) transferTo:(NSOutputStream *)stream
{
    UInt8 buffer[PAGE_SIZE];

    while ([self hasBytesAvailable])
    {
        NSInteger count = [self read:buffer maxLength:PAGE_SIZE];
        if (count <= 0) return NO;

        count = [stream write:buffer maxLength:count];
        if (count <= 0) return NO;
    }

    return YES;
}

@end
