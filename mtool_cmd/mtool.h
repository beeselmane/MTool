#pragma once

#import <LibObjC/LibObjC.h>
#import <MTool/MTool.h>

// This class implements the interface for the lipo command shipped with macOS.
@interface MTCLipoCommand : NXCommand

// This dictionary has two keys: @"name": NSString * is the format in which the
//   file was specified on the command line and @"url": NSURL * is a fully resolved
//   URL to the file itself.
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, id> *> *inputFiles;
@property (nonatomic, strong) NSURL *outputURL;

- (void) detailedInfo;

@end
