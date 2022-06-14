#import <Foundation/Foundation.h>
#import <MTool/MTType.h>

NS_ASSUME_NONNULL_BEGIN

@class MTMappedRegion;
@class MTMachO;

typedef NS_ENUM(NSUInteger, MTDylibReferenceType) {
    kMTDylibReferenceTypeRegular,
    MTDylibReferenceTypeWeak,
    MTDylibReferenceTypeReexport,
    MTDylibReferenceTypeUpward
};

#pragma mark - Load Command Objects

@interface MTLoadCommand : NSObject

// The image in which this load command appears
@property (nonatomic, readonly) MTMachO *image;

@property (nonatomic, readonly) UInt32 type;

// This type depends on the type of this load command
@property (nonatomic, readonly) NSData *rawCommandData;

@end

@interface MTSegmentInfo : MTLoadCommand

@property (nonatomic, readonly) MTMappedRegion *data;

@end

@interface MTDylibInfo : MTLoadCommand

@property (nonatomic, readonly) NSString *name;

@property (nonatomic, readonly) MTDylibReferenceType referenceType;

// Note: This is lazily loaded. Only supported for libraries in some types of objects
//  (specifically when we need to resolve an @rpath or @executable_path or something.
@property (nonatomic, readonly) MTMachO *image;

@end

@interface MTDynamicLinkerInfo : MTLoadCommand

@property (nonatomic, readonly) NSString *name;

@property (nonatomic, readonly) MTMachO *image;

@end

@interface MTFileSetEntry : MTLoadCommand

@property (nonatomic, readonly) NSString *identifier;

@property (nonatomic, readonly) NSData *entryData;

@property (nonatomic, readonly) MTMachO *asImage;

@end

#pragma mark - Mach-O main class

@interface MTMachO : NSObject

// Return an array describing all Mach-O images in the given process space (as far as dyld is aware)
+ (NSArray<NSDictionary<NSString *, id> *> *) imageListFromProcess:(pid_t)process;

// Create an object from a loaded image in an existing process (from memory)
+ (instancetype) loadFromImageInProcess:(NSDictionary<NSString *, id> *)imageInfo;

+ (instancetype) loadFromMemoryAt:(void *)location maxSize:(NSUInteger)size;

// Create an object from a mach-o file on disk.
+ (instancetype) loadFromURL:(NSURL *)url;

@property (nonatomic, readonly) MTMachOImageType type;

@property (nonatomic, readonly) MTMachineType machineType;

@property (nonatomic, readonly) MTMachineSubtype subtype;

@property (nonatomic, readonly) NSArray<MTLoadCommand *> *allLoadCommands;

@property (nonatomic, readonly) NSArray<MTSegmentInfo *> *segments;

@end

#pragma mark - Specific image types

@interface MTExecutableImage : MTMachO

// TODO: main/unixthread goes here

@end

@interface MTDynamicLibrary : MTMachO

@property (nonatomic, readonly) NSString *identity;

@end

@interface MTDynamicLinker : MTMachO

@property (nonatomic, readonly) NSString *identity;

@end

@interface MTObjectFile : MTMachO

// TODO: Implement object file parsing.

@end

@interface MTFileSet : MTMachO

@property (nonatomic, readonly) NSArray<MTFileSetEntry *> *entries;

@end

NS_ASSUME_NONNULL_END

#pragma mark - Extended Discussion

#if 0

#define LC_REQ_DYLD 0x80000000

Mach-O file types:
==================

tools/intermediete:
MH_OBJECT
MH_CORE
MH_DSYM

valid:
MH_EXECUTE
MH_DYLIB
MH_DYLINKER
MH_BUNDLE
MH_KEXT_BUNDLE
MH_FILESET (kernel caches)

this is created by strip -c *.dylib
is this the precursor to tapi?
MH_DYLIB_STUB

legacy:
MH_FVMLIB
MH_PRELOAD



Mach-O load commands:
=====================

any filetype:
LC_SEGMENT_64 (xN)

LC_SYMTAB (x1, enforced by dyld)
LC_DYSYMTAB (x1, enforced by dyld)

LC_LOAD_DYLIB (xN)
LC_LOAD_WEAK_DYLIB (same as above, can be missing any functions)
LC_REEXPORT_DYLIB (xN)
LC_LOAD_UPWARD_DYLIB (xN)

LC_LOAD_DYLINKER (x1, enforced by xnu)
LC_UUID (x1, enforced by dyld, xnu)

LC_DATA_IN_CODE (x1, enforced by dyld)
LC_FUNCTION_STARTS (x1, enforced by dyld)

LC_ROUTINES_64 (x1, enforced by ??, initializer routines)

LC_ENCRYPTION_INFO_64 (x1, enforced by dyld)
LC_CODE_SIGNATURE (x1, enforced by dyld)
LC_DYLIB_CODE_SIGN_DRS (x?)

LC_DYLD_CHAINED_FIXUPS (x1, enforced by dyld)
LC_DYLD_EXPORTS_TRIE (x1, enforced by dyld)
LC_DYLD_INFO (x1, enforced by dyld)
LC_DYLD_INFO_ONLY (same as above)

LC_DYLD_ENVIRONMENT (xN)
LC_NOTE (xN)
LC_RPATH (xN)

LC_SOURCE_VERSION (xN)
LC_BUILD_VERSION (x1, enforced by xnu)

(version commands)
LC_VERSION_MIN_MACOSX
LC_VERSION_MIN_IPHONEOS
LC_VERSION_MIN_TVOS
LC_VERSION_MIN_WATCHOS
one of the above, one instance, enforced by xnu, dyld.



executable: (one of the following are required)
LC_UNIXTHREAD (x1, enforced by dyld) (can specify stack if points to __UNIXSTACK segment)
LC_MAIN (x1, enforced by dyld)

library: (the following one is required)
LC_ID_DYLIB (x1, enforced by dyld [# maybe not enforced?])

LC_SUB_FRAMEWORK (x1, enforced by ld64 [so not really enforced])
LC_SUB_CLIENT (xN)

dylinker: (the following is required)
LC_ID_DYLINKER (enforced by ???)

object:
LC_LINKER_OPTION (xN)
LC_LINKER_OPTIMIZATION_HINT (x1, cctools indicates this in ofile.c)

fileset: (this is used for kernelcaches now I believe)
LC_FILESET_ENTRY (xN)



**legacy: (the first list is marked obsolete in llvm as well as being unused in cctools, dyld, ld64, and xnu)
LC_SYMSEG (unclear, only referenced in cctools)
LC_THREAD (for core files)
LC_LOADFVMLIB (only in cctools)
LC_IDFVMLIB (only in cctools)
LC_IDENT (only in cctools)
LC_FVMFILE (only in cctools)
LC_PREPAGE (only in cctools)
LC_PREBOUND_DYLIB (only in cctools [+ redo_prebinding])
LC_TWOLEVEL_HINTS (only in cctools)
LC_PREBIND_CKSUM (only in cctools)

LC_LAZY_LOAD_DYLIB (this is not output by ld64, although it is supported to some extent)

only in 32-bit images:
LC_ENCRYPTION_INFO (x1, enforced by dyld)
LC_ROUTINES (x1, enforced by ??)
LC_SEGMENT (xN)

partially deprecated (replaced by LC_REEXPORT_DYLIB):
LC_SUB_UMBRELLA (xN, a sub umbrella is itself an umbrella framework which is a sub framework of an embrella framework. This is in the parent umbrella)
LC_SUB_LIBRARY (xN, a sub library is a library exported by another library)



Supported load commands (grouped by function)
=============================================

image layout (segments, sections):
LC_SEGMENT_64 (xN)

symbol tables:
LC_SYMTAB (x1, enforced by dyld)
LC_DYSYMTAB (x1, enforced by dyld)

referenced libraries (each corresponds to a different type of reference):
LC_LOAD_DYLIB (xN)
LC_LOAD_WEAK_DYLIB (same as above, can be missing any functions)
LC_REEXPORT_DYLIB (xN)
LC_LOAD_UPWARD_DYLIB (xN)

dynamic linker:
LC_LOAD_DYLINKER (x1, enforced by xnu)

uuid:
LC_UUID (x1, enforced by dyld, xnu)

indicate data sections in code, used mainly for disassembly
LC_DATA_IN_CODE (x1, enforced by dyld)

offset of all functions in this image
LC_FUNCTION_STARTS (x1, enforced by dyld)

library initializers (seemingly not emitted by any tools currently):
LC_ROUTINES_64 (x1, enforced by ??, initializer routines)

binary text encryption (this must fall in __TEXT)
LC_ENCRYPTION_INFO_64 (x1, enforced by dyld)

image code signature info
LC_CODE_SIGNATURE (x1, enforced by dyld)
LC_DYLIB_CODE_SIGN_DRS (x?)

dyld environment strings
LC_DYLD_ENVIRONMENT (xN)

arbitrary note data
LC_NOTE (xN)

rpath additions
LC_RPATH (xN)

version of source code. Pretty arbitrary, only really used in cctools
LC_SOURCE_VERSION (xN)

build version including os info and tool info
LC_BUILD_VERSION (x1, enforced by xnu)

minimum OS version required to load this image
LC_VERSION_MIN_MACOSX
LC_VERSION_MIN_IPHONEOS
LC_VERSION_MIN_TVOS
LC_VERSION_MIN_WATCHOS
one of the above, one instance, enforced by xnu, dyld.






LC_DYLD_CHAINED_FIXUPS
LC_DYLD_EXPORTS_TRIE

image loading info:
LC_DYLD_INFO/LC_DYLD_INFO_ONLY





LC_SUB_FRAMEWORK
LC_SUB_CLIENT (name of clients allowed to link directly to the library)

#endif
