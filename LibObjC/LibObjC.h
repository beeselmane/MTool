// LibObjC -- This is a library of Objective-C classes and functions for use in command line tools and the like.
// Much of it wraps standard c functions in Foundation classes, and adds functions to do useful things.

// I'm going to revive something from the old NeXT days and use the 'NX' prefix.
// For now, this will be the only header.

#import <Foundation/Foundation.h>

#pragma mark - NSArray category

@interface NSArray (LibObjC)

// length = -1 ==> NULL-terminated array
+ (NSArray<NSString *> *) arrayWithUTF8StringArray:(char *const *)array ofLength:(NSInteger)length;

// The passed array is assumed to be NULL-terminated
+ (NSArray<NSString *> *) arrayWithUTF8StringArray:(char *const *)array;

@end

#pragma mark - NSData category

@interface NSData (LibObjC)

// Why doesn't NSData have this...
- (NSString *) hexString;

@end

#pragma mark - NSDictionary category

@interface NSDictionary (LibObjC)

// Dictionary containing the (name, value) pairs in this process's environment
+ (NSDictionary<NSString *, NSString *> *) environmentDictionary;

// Process environment-style dictionary from string array
+ (NSDictionary<NSString *, NSString *> *) environmentDictionaryFromArray:(NSArray<NSString *> *)array;

@end

#pragma mark - NSInputStream category

@interface NSInputStream (LibObjC)

// I've always thought NSInputStream has needed this method...
- (BOOL) transferTo:(NSOutputStream *)stream maxBytes:(NSUInteger)size;

// Fully write to the provided stream
- (BOOL) transferTo:(NSOutputStream *)stream;

@end

#pragma mark - Command line tools

// Implement a subclass of this class to make a convinient command line tool.
// Override the - invoke method, and call `NXCommandMain` below from your own main function.
@interface NXCommand : NSObject

+ (instancetype) commandWithArguments:(NSArray<NSString *> *)args;

// Note: This is NOT cached, since environ is subject to change. Store it locally if
//         you don't want to process it every time you access.
@property (strong, readonly, nonatomic) NSDictionary<NSString *, NSString *> *environment;

@property (strong, nonatomic) NSArray<NSString *> *args;

// The name used to invoke this command. This corresponds to args[0]
@property (strong, readonly, nonatomic) NSString *invokedName;

// If passed, contains Apple strings
@property (strong, nonatomic) NSArray<NSString *> *appleStrings;

// Override this in custom commands
- (int) invoke;

@end

// This method can be invoked similarly to NSApplicationMain in Cocoa Applications.
// Simply pass in the name of a class which extends NXCommand and the arguments provided
//   to your main() function. The - invoke method on your class will be called and the
//   `args` property will be set to the processed command line arguments.
// The last parameter can be the fourth argument of main() if desired on Apple platforms.
extern int NXCommandMain(NSString *commandClass, int argc, char *const *argv, char *const *apple);

#pragma mark - System process list

// Return an array with information on all processes running on this machine.
// Each entry is a dictionary with 3 keys:
//   - PID : An NSNumber with the pid_t value for the given process
//   - Name: An NSString with the name for the given process
//   - Path: An NSString with the path for the given process
extern NSArray<NSDictionary<NSString *, id> *> *NXGetAllProcesses(void);

#pragma mark - Library version

FOUNDATION_EXPORT const unsigned char LibObjCVersionString[];
FOUNDATION_EXPORT double LibObjCVersionNumber;
