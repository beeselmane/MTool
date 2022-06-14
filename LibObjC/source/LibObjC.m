#import <Foundation/Foundation.h>
#import <LibObjC/LibObjC.h>

// For proc_* functions, PROC_* macros
#import <libproc.h>

// From libC
extern char ***_NSGetEnviron(void);

#pragma mark - NSArray category

@implementation NSArray (LibObjC)

+ (instancetype) arrayWithUTF8StringArray:(char *const *)array ofLength:(NSInteger)length
{
    NSMutableArray<NSString *> *result = [[NSMutableArray alloc] init];

    if (result)
    {
        for (NSUInteger i = 0; ; i++)
        {
            if (i == length || !array[i])
                break;

            [result addObject:[NSString stringWithUTF8String:array[i]]];
        }
    }

    return [self arrayWithArray:result];
}

// The passed array is assumed to be NULL-terminated
+ (instancetype) arrayWithUTF8StringArray:(char *const *)array
{
    return [self arrayWithUTF8StringArray:array ofLength:-1];
}

@end

#pragma mark - NSData category

@implementation NSData (LibObjC)

- (NSString *) hexString;
{
    const UInt8 *buffer = [self bytes];
    NSUInteger length = [self length];

    UniChar *result = calloc(length * 2, sizeof(UniChar));

    if (!result)
    {
        NSLog(@"Out of memory!");

        return nil;
    }

    for (NSUInteger i = 0; i < length; i++)
    {
        UniChar c = buffer[i] / 0x10;

        c += (c < 10) ? '0' : ('A' - 10);
        result[i * 2] = c;

        c = buffer[i] % 0x10;

        c += (c < 10) ? '0' : ('A' - 10);
        result[(i * 2) + 1] = c;
    }

    return [[NSString alloc] initWithCharactersNoCopy:result length:(length * 2) freeWhenDone:YES];
}

@end

#pragma mark - NSDictionary category

@implementation NSDictionary (LibObjC)

+ (NSDictionary<NSString *, NSString *> *) environmentDictionaryFromArray:(NSArray<NSString *> *)array
{
    NSMutableDictionary<NSString *, NSString *> *result = [[NSMutableDictionary alloc] initWithCapacity:[array count]];

    for (NSString *env in array)
    {
        NSRange range = [env rangeOfString:@"="];

        if (range.location == NSNotFound)
        {
            NSLog(@"Warning: Trimmed malformed environment string '%@'", env);

            continue;
        }

        NSString *value = [env substringFromIndex:(range.location + 1)];
        NSString *name = [env substringToIndex:range.location];

        [result setValue:value forKey:name];
    }

    return [self dictionaryWithDictionary:result];
}

+ (NSDictionary<NSString *, NSString *> *) environmentDictionary
{
    char *const *environ = (*_NSGetEnviron());

    return [self environmentDictionaryFromArray:[NSArray arrayWithUTF8StringArray:environ]];
}

@end

#pragma mark - NSInputStream category

@implementation NSInputStream (LibObjC)

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

#pragma mark - Command line tools

@implementation NXCommand

@synthesize appleStrings = _appleStrings;
@synthesize args = _args;

@dynamic environment;
@dynamic invokedName;

+ (instancetype) commandWithArguments:(NSArray<NSString *> *)args
{
    NXCommand *instance = [[self alloc] init];

    if (instance)
        instance->_args = args;

    return instance;
}

- (NSDictionary<NSString *, NSString *> *) environment
{
    return [NSDictionary environmentDictionary];
}

- (NSString *) invokedName
{
    return [[self args] objectAtIndex:0];
}

- (int) invoke
{
    // Do nothing by default.
    return 0;
}

@end

int NXCommandMain(NSString *commandClass, int argc, char *const *argv, char *const *apple)
{
    // Autorelease everything here.
    @autoreleasepool
    {
        NSArray<NSString *> *appleStrings = nil;

        if (apple)
            appleStrings = [NSArray arrayWithUTF8StringArray:apple];

        NSArray<NSString *> *args = [NSArray arrayWithUTF8StringArray:argv ofLength:argc];
        Class cls = NSClassFromString(commandClass);

        if (!cls)
        {
            NSLog(@"Can't find Class for string '%@'!", commandClass);

            return -1;
        }

        if (![cls isSubclassOfClass:[NXCommand class]])
        {
            NSLog(@"Class '%@' is not subclass of '%@'!", NSStringFromClass(cls), NSStringFromClass([NXCommand class]));

            return -1;
        }

        NXCommand *command = [cls commandWithArguments:args];
        [command setAppleStrings:appleStrings];
        return [command invoke];
    }
}

#pragma mark - System process list

NSArray<NSDictionary<NSString *, id> *> *NXGetAllProcesses(void)
{
    size_t count = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t *pid_list = calloc(count, sizeof(pid_t));

    if (!pid_list)
    {
        NSLog(@"Out of memory!");

        return nil;
    }

    count = proc_listpids(PROC_ALL_PIDS, 0, pid_list, (int)count);

    NSMutableArray<NSDictionary<NSString *, id> *> *processes = [[NSMutableArray alloc] initWithCapacity:count];

    for (size_t i = 0; i < count; i++)
    {
        char path[PROC_PIDPATHINFO_MAXSIZE];
        char name[2 * MAXCOMLEN];

        proc_pidpath(pid_list[i], path, PROC_PIDPATHINFO_MAXSIZE);
        proc_name(pid_list[i], name, 2 * MAXCOMLEN);

        [processes addObject:@{
            @"PID"  : @(pid_list[i]),
            @"Name" : [NSString stringWithUTF8String:name],
            @"Path" : [NSString stringWithUTF8String:path]
        }];
    }

    free(pid_list);

    return [NSArray arrayWithArray:processes];
}
