// Here, we re-export a few useful types when dealing with Mach-O files.
#import <Foundation/Foundation.h>

#import <mach-o/loader.h>
#import <arpa/inet.h>

// These are useful for processing FAT files, which store fields in big endian
#define MTSwapToBigEndian   htonl
#define MTSwapToHostEndian  ntohl

// These are taken from mach-o/loader.h
// We re-export them with some new names + functions
enum {
    kMTMachOImageTypeUnknown                = -1,
    kMTMachOImageTypeObject                 = MH_OBJECT,
    kMTMachOImageTypeExecutable             = MH_EXECUTE,
    kMTMachOImageTypeFVMLibrary             = MH_FVMLIB,
    kMTMachOImageTypeCore                   = MH_CORE,
    kMTMachOImageTypePreloadedExecutable    = MH_PRELOAD,
    kMTMachOImageTypeDynamicLibrary         = MH_DYLIB,
    kMTMachOImageTypeDynamicLinker          = MH_DYLINKER,
    kMTMachOImageTypeBundle                 = MH_BUNDLE,
    kMTMachOImageTypeLibraryStub            = MH_DYLIB_STUB,
    kMTMachOImageTypeDsym                   = MH_DSYM,
    kMTMachOImageTypeKext                   = MH_KEXT_BUNDLE,
    kMTMachOImageTypeFileSet                = MH_FILESET
};

typedef uint32_t MTMachOImageType;

// These are taken from mach/machine.h
// We basically just re-export them with more objective-c style names.
// Note that in reality x86_64 and aarch64 are the only relevent types here.
enum {
    kMTMachineTypeAny       = CPU_TYPE_ANY,
    kMTMachineTypeVAX       = CPU_TYPE_VAX, // I find it quite funny that VAX is cpu type 1
    kMTMachineTypeROMP      = 2, // From cctools mach/machine.h
    kMTMachineTypeNS32032   = 4, // From cctools mach/machine.h
    kMTMachineTypeNS32332   = 5, // From cctools mach/machine.h
    kMTMachineTypeMC680x0   = CPU_TYPE_MC680x0,
    kMTMachineTypeI386      = CPU_TYPE_I386,
    kMTMachineTypeX86_64    = CPU_TYPE_X86_64, // Intel macs
    kMTMachineTypeMIPS      = 8, // This is skipped in mach/machine.h for whatever reason
    kMTMachineTypeNS32532   = 9, // From cctools mach/machine.h
    kMTMachineTypeMC98000   = CPU_TYPE_MC98000,
    kMTMachineTypeHPPA      = CPU_TYPE_HPPA,
    kMTMachineTypeARM       = CPU_TYPE_ARM,
    kMTMachineTypeAArch64   = CPU_TYPE_ARM64, // iPhones, M1 macs
    kMTMachineTypeARM64_32  = CPU_TYPE_ARM64_32, // I'm pretty sure this is unsed, but Apple references it a lot.
    kMTMachineTypeMC88000   = CPU_TYPE_MC88000,
    kMTMachineTypeSPARC     = CPU_TYPE_SPARC,
    kMTMachineTypeI860      = CPU_TYPE_I860,
    kMTMachineTypeALPHA     = 16, // This is skipped in mach/machine.h for whatever reason
    kMTMachineTypeRS6000    = 17, // From cctools mach/machine.h
    kMTMachineTypePowerPC   = CPU_TYPE_POWERPC, // 20 year old macs
    kMTMachineTypePowerPC64 = CPU_TYPE_POWERPC64,
    kMTMachineTypeVEO       = 255 // This is found in the version of mach/machine.h from the cctools distribution, and it's actually supported by some of the tools therein. I'm not sure why, I don't even know what a VEO is.
};

// Apply this mask to MTMachineSubtype to access machine capabilities
#define kMTMachineCapabilitiesMask      CPU_SUBTYPE_MASK

// For AArch64, this ABI is defined in an inconsistent way.
#define kMTMachinePointerAuthMask       CPU_SUBTYPE_ARM64_PTR_AUTH_MASK

// This is what what Apple calls arm64-e, which is AArch64 8.3+ I believe.
// These don't seem to be exported in the current version of mach/machine.h
// I found them in the header version shipped with cctools, which seems to
//   be missing a lot of AArch64 content, but includes these definitions.
#define kMTMachinePointerAuthKernelMask 0x40000000
#define kMTMachinePointerAuthUserMask   0x80000000

enum {
    kMTMachineCapabilitiyPointerAuthentication  = CPU_SUBTYPE_PTRAUTH_ABI,
    kMTMachineCapabilityLib64                   = CPU_SUBTYPE_LIB64
};

typedef cpu_subtype_t MTMachineSubtype;

typedef cpu_type_t MTMachineType;

// Get the current cpytype/subtype combo. Return false on failure.
extern bool MTMachinePairGetCurrent(MTMachineType *type, MTMachineSubtype *subtype);

// Methods for getting various information as strings
extern NSString *MTMachinePairToArchName(MTMachineType type, MTMachineSubtype subtype);

// Machine subtype is a function of machine type, so this function needs both.
extern NSString *MTMachinePairSubtypeName(MTMachineType type, MTMachineSubtype subtype);
extern NSString *MTMachineTypeToString(MTMachineType type);

// Some subtypes expose "capability" information. This includes features such as pointer authentcation.
extern NSString *MTMachinePairGetCapabilitiesString(MTMachineType type, MTMachineSubtype subtype);

// Get name of Mach-O type
extern NSString *MTMachOImageTypeName(MTMachOImageType type);

extern NSString *MTMachOLoadCommandName(uint32_t command);
