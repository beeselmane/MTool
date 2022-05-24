#pragma once

#import <MTool/MTool.h>

@interface MTCCommand : NSObject

+ (instancetype) commandWithArguments:(NSArray<NSString *> *)args;

@property (strong, nonatomic) NSArray<NSString *> *args;

- (int) invoke;

@end

// This class implements the interface for the lipo command shipped with macOS.
@interface MTCLipoCommand : MTCCommand

// This dictionary has two keys: @"name": NSString * is the format in which the
//   file was specified on the command line and @"url": NSURL * is a fully resolved
//   URL to the file itself.
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, id> *> *inputFiles;
@property (nonatomic, strong) NSURL *outputURL;

- (void) detailedInfo;

@end
