#import "mtool.h"

@implementation MTCCommand

@synthesize args = _args;

+ (instancetype) commandWithArguments:(NSArray<NSString *> *)args
{
    MTCCommand *command = [[self alloc] init];

    if (command)
        [command setArgs:args];

    return command;
}

- (int) invoke
{
    return 0;
}

@end
