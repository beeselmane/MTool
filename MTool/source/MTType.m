#import <MTool/MTool.h>
#import <MTool/MTType.h>

// For getting current machine pair
#import <sys/sysctl.h>

bool MTMachinePairGetCurrent(MTMachineType *type, MTMachineSubtype *subtype)
{
    if (!type && !subtype)
    {
        return false;
    }

    // There are sysctls for this. Namely, hw.cputype and hw.cpusubtype. These can only be done by name
    size_t sysctl_size = sizeof(int32_t);
    int32_t sysctl_subtype;
    int32_t sysctl_type;

    if (type)
    {
        if (sysctlbyname("hw.cputype", &sysctl_type, &sysctl_size, NULL, 0))
        {
            NSLog(@"Failed to get 'hw.cputype' from sysctl!");

            return false;
        }

        // Just in case, even though the man page explicitly says this is the returned size.
        sysctl_size = sizeof(int32_t);

        // Save this here
        (*type) = sysctl_type;
    }

    if (subtype)
    {
        if (sysctlbyname("hw.cpusubtype", &sysctl_subtype, &sysctl_size, NULL, 0))
        {
            NSLog(@"Failed to get 'hw.cpusubtype' from sysctl!");

            return false;
        }

        (*subtype) = sysctl_subtype;
    }

    return true;
}

// I don't support some of the more obscure things found here in cctools...
NSString *MTMachinePairToArchName(MTMachineType type, MTMachineSubtype _subtype)
{
    MTMachineSubtype subtype = (_subtype & ~kMTMachineCapabilitiesMask);

    switch (type)
    {
        case kMTMachineTypeI386: {
            switch (subtype)
            {
                case CPU_SUBTYPE_I386_ALL:      return @"i386";
                case CPU_SUBTYPE_486:           return @"i486";
                case CPU_SUBTYPE_486SX:         return @"i486SX";
                case CPU_SUBTYPE_PENT:          return @"pentium";
                case CPU_SUBTYPE_PENTPRO:       return @"pentpro";
                case CPU_SUBTYPE_PENTII_M3:     return @"pentIIm3";
                case CPU_SUBTYPE_PENTII_M5:     return @"pentIIm5";
            }
        } break;
        case kMTMachineTypeX86_64: {
            switch (subtype)
            {
                case CPU_SUBTYPE_X86_64_ALL:    return @"x86_64";
                case CPU_SUBTYPE_X86_64_H:      return @"x86_64h";
            }
        } break;
        case kMTMachineTypeARM: {
            switch (subtype)
            {
                case CPU_SUBTYPE_ARM_ALL:       return @"arm";
                case CPU_SUBTYPE_ARM_V4T:       return @"armv4t";
                case CPU_SUBTYPE_ARM_V5TEJ:     return @"armv5";
                case CPU_SUBTYPE_ARM_XSCALE:    return @"xscale";
                case CPU_SUBTYPE_ARM_V6:        return @"armv6";
                case CPU_SUBTYPE_ARM_V6M:       return @"armv6m";
                case CPU_SUBTYPE_ARM_V7:        return @"armv7";
                case CPU_SUBTYPE_ARM_V7F:       return @"armv7f";
                case CPU_SUBTYPE_ARM_V7S:       return @"armv7s";
                case CPU_SUBTYPE_ARM_V7K:       return @"armv7k";
                case CPU_SUBTYPE_ARM_V7M:       return @"armv7m";
                case CPU_SUBTYPE_ARM_V7EM:      return @"armv7em";
            }
        } break;
        case kMTMachineTypeAArch64: {
            switch (subtype)
            {
                case CPU_SUBTYPE_ARM64_ALL:     return @"arm64";
                case CPU_SUBTYPE_ARM64_V8:      return @"arm64v8";
                case CPU_SUBTYPE_ARM64E:        return @"arm64e";
            }
        } break;
        case kMTMachineTypeARM64_32: {
            if (subtype == CPU_SUBTYPE_ARM64_32_V8)
                return @"arm64_32";
        } break;
        case kMTMachineTypePowerPC: {
            switch (subtype)
            {
                case CPU_SUBTYPE_POWERPC_ALL:   return @"ppc";
                case CPU_SUBTYPE_POWERPC_601:   return @"ppc601";
                case CPU_SUBTYPE_POWERPC_603:   return @"ppc603";
                case CPU_SUBTYPE_POWERPC_603e:  return @"ppc603e";
                case CPU_SUBTYPE_POWERPC_603ev: return @"ppc603ev";
                case CPU_SUBTYPE_POWERPC_604:   return @"ppc604";
                case CPU_SUBTYPE_POWERPC_604e:  return @"ppc604e";
                case CPU_SUBTYPE_POWERPC_750:   return @"ppc750";
                case CPU_SUBTYPE_POWERPC_7400:  return @"ppc7400";
                case CPU_SUBTYPE_POWERPC_7450:  return @"ppc7450";
                case CPU_SUBTYPE_POWERPC_970:   return @"ppc970";
            }
        } break;
        case kMTMachineTypePowerPC64: {
            switch (subtype)
            {
                case CPU_SUBTYPE_POWERPC_ALL:   return @"ppc64";
                case CPU_SUBTYPE_POWERPC_970:   return @"ppc970-64";
            }
        } break;
    }

    return [NSString stringWithFormat:@"(cputype (%d) cpusubtype (%d))", type, subtype];
}

// I don't support some of the more obscure things found here in cctools...
NSString *MTMachinePairSubtypeName(MTMachineType type, MTMachineSubtype _subtype)
{
    MTMachineSubtype subtype = (_subtype & ~kMTMachineCapabilitiesMask);

    switch (type)
    {
        case kMTMachineTypeI386: {
            switch (subtype)
            {
                case CPU_SUBTYPE_I386_ALL:      return @"CPU_SUBTYPE_I386_ALL";
                case CPU_SUBTYPE_486:           return @"CPU_SUBTYPE_486";
                case CPU_SUBTYPE_486SX:         return @"CPU_SUBTYPE_486SX";
                case CPU_SUBTYPE_PENT:          return @"CPU_SUBTYPE_PENT";
                case CPU_SUBTYPE_PENTPRO:       return @"CPU_SUBTYPE_PENTPRO";
                case CPU_SUBTYPE_PENTII_M3:     return @"CPU_SUBTYPE_PENTII_M3";
                case CPU_SUBTYPE_PENTII_M5:     return @"CPU_SUBTYPE_PENTII_M5";
            }
        } break;
        case kMTMachineTypeX86_64: {
            switch (subtype)
            {
                case CPU_SUBTYPE_X86_64_ALL:    return @"CPU_SUBTYPE_X86_64_ALL";
                case CPU_SUBTYPE_X86_64_H:      return @"CPU_SUBTYPE_X86_64_H";
            }
        } break;
        case kMTMachineTypeARM: {
            switch (subtype)
            {
                case CPU_SUBTYPE_ARM_ALL:       return @"CPU_SUBTYPE_ARM_ALL";
                case CPU_SUBTYPE_ARM_V4T:       return @"CPU_SUBTYPE_ARM_V4T";
                case CPU_SUBTYPE_ARM_V5TEJ:     return @"CPU_SUBTYPE_ARM_V5TEJ";
                case CPU_SUBTYPE_ARM_XSCALE:    return @"CPU_SUBTYPE_ARM_XSCALE";
                case CPU_SUBTYPE_ARM_V6:        return @"CPU_SUBTYPE_ARM_V6";
                case CPU_SUBTYPE_ARM_V6M:       return @"CPU_SUBTYPE_ARM_V6M";
                case CPU_SUBTYPE_ARM_V7:        return @"CPU_SUBTYPE_ARM_V7";
                case CPU_SUBTYPE_ARM_V7F:       return @"CPU_SUBTYPE_ARM_V7F";
                case CPU_SUBTYPE_ARM_V7S:       return @"CPU_SUBTYPE_ARM_V7S";
                case CPU_SUBTYPE_ARM_V7K:       return @"CPU_SUBTYPE_ARM_V7K";
                case CPU_SUBTYPE_ARM_V7M:       return @"CPU_SUBTYPE_ARM_V7M";
                case CPU_SUBTYPE_ARM_V7EM:      return @"CPU_SUBTYPE_ARM_V7EM";
            }
        } break;
        case kMTMachineTypeAArch64: {
            switch (subtype)
            {
                case CPU_SUBTYPE_ARM64_ALL:     return @"CPU_SUBTYPE_ARM64_ALL";
                case CPU_SUBTYPE_ARM64_V8:      return @"CPU_SUBTYPE_ARM64_V8";
                case CPU_SUBTYPE_ARM64E:        return @"CPU_SUBTYPE_ARM64E";
            }
        } break;
        case kMTMachineTypeARM64_32: {
            if (subtype == CPU_SUBTYPE_ARM64_32_V8)
                return @"CPU_SUBTYPE_ARM64_32_V8";
        } break;
        case kMTMachineTypePowerPC: {
            switch (subtype)
            {
                case CPU_SUBTYPE_POWERPC_ALL:   return @"CPU_SUBTYPE_POWERPC_ALL";
                case CPU_SUBTYPE_POWERPC_601:   return @"CPU_SUBTYPE_POWERPC_601";
                case CPU_SUBTYPE_POWERPC_603:   return @"CPU_SUBTYPE_POWERPC_603";
                case CPU_SUBTYPE_POWERPC_603e:  return @"CPU_SUBTYPE_POWERPC_603e";
                case CPU_SUBTYPE_POWERPC_603ev: return @"CPU_SUBTYPE_POWERPC_603ev";
                case CPU_SUBTYPE_POWERPC_604:   return @"CPU_SUBTYPE_POWERPC_604";
                case CPU_SUBTYPE_POWERPC_604e:  return @"CPU_SUBTYPE_POWERPC_604e";
                case CPU_SUBTYPE_POWERPC_750:   return @"CPU_SUBTYPE_POWERPC_750";
                case CPU_SUBTYPE_POWERPC_7400:  return @"CPU_SUBTYPE_POWERPC_7400";
                case CPU_SUBTYPE_POWERPC_7450:  return @"CPU_SUBTYPE_POWERPC_7450";
                case CPU_SUBTYPE_POWERPC_970:   return @"CPU_SUBTYPE_POWERPC_970";
            }
        } break;
        case kMTMachineTypePowerPC64: {
            switch (subtype)
            {
                case CPU_SUBTYPE_POWERPC_ALL:   return @"CPU_SUBTYPE_POWERPC_ALL";
                case CPU_SUBTYPE_POWERPC_970:   return @"CPU_SUBTYPE_POWERPC_970-64";
            }
        } break;
    }

    return [NSString stringWithFormat:@"(%d)", subtype];
}

NSString *MTMachineTypeToString(MTMachineType type)
{
    switch (type)
    {
        case kMTMachineTypeAny:         return @"CPU_TYPE_ANY";
        case kMTMachineTypeMC680x0:     return @"CPU_TYPE_MC680x0";
        case kMTMachineTypePowerPC:     return @"CPU_TYPE_POWERPC";
        case kMTMachineTypePowerPC64:   return @"CPU_TYPE_POWERPC64";
        case kMTMachineTypeVEO:         return @"CPU_TYPE_VEO";
        case kMTMachineTypeMC88000:     return @"CPU_TYPE_MC88000";
        case kMTMachineTypeI386:        return @"CPU_TYPE_I386";
        case kMTMachineTypeX86_64:      return @"CPU_TYPE_X86_64";
        case kMTMachineTypeI860:        return @"CPU_TYPE_I860";
        case kMTMachineTypeHPPA:        return @"CPU_TYPE_HPPA";
        case kMTMachineTypeSPARC:       return @"CPU_TYPE_SPARC";
        case kMTMachineTypeARM:         return @"CPU_TYPE_ARM";
        case kMTMachineTypeAArch64:     return @"CPU_TYPE_ARM64";
        case kMTMachineTypeARM64_32:    return @"CPU_TYPE_ARM64_32";
        default:                        return [NSString stringWithFormat:@"(%d)", type];
    }
}

NSString *MTMachinePairGetCapabilitiesString(MTMachineType type, MTMachineSubtype subtype)
{
    MTMachineSubtype capabilities = (subtype & kMTMachineCapabilitiesMask);

    if (type == kMTMachineTypeX86_64 || type == kMTMachineTypePowerPC64) {
        if (capabilities == kMTMachineCapabilityLib64) {
            return @"CPU_SUBTYPE_LIB64";
        }
    } else if (type == kMTMachineTypeAArch64) {
        if (capabilities & kMTMachinePointerAuthUserMask)
        {
            // See source for lipo. I don't know why this is done in such a way. It actually seems incorrect.
            // The macro CPU_SUBTYPE_ARM64_PTR_AUTH_VERSION defined in mach/machine.h uses a different mask
            //   with the same shift, which leads me to believe this is actually a bug in lipo.
            // Clang has to write these flags, or LLVM or someone, so there must be a definitive answer.
            // Lipo is probably wrong; it only gives us debugging info, which should not be taken as authoritative.
            // TODO: Check the tools who write these flags; determine who is wrong here, because someone clearly is.
            UInt8 version = (capabilities & kMTMachinePointerAuthKernelMask) >> 24;

            if (capabilities & kMTMachinePointerAuthKernelMask) {
                return [NSString stringWithFormat:@"PTR_AUTH_VERSION KERNEL %d", version];
            } else {
                return [NSString stringWithFormat:@"PTR_AUTH_VERSION USERSPACE %d", version];
            }
        }
    }

    return [NSString stringWithFormat:@"0x%x", (unsigned int)(capabilities >> 24)];
}

NSString *MTMachOImageTypeName(MTMachOImageType type)
{
    switch (type)
    {
        case kMTMachOImageTypeObject:               return @"MH_OBJECT";
        case kMTMachOImageTypeExecutable:           return @"MH_EXECUTE";
        case kMTMachOImageTypeFVMLibrary:           return @"MH_FVMLIB";
        case kMTMachOImageTypeCore:                 return @"MH_CORE";
        case kMTMachOImageTypePreloadedExecutable:  return @"MH_PRELOAD";
        case kMTMachOImageTypeDynamicLibrary:       return @"MH_DYLIB";
        case kMTMachOImageTypeDynamicLinker:        return @"MH_DYLINKER";
        case kMTMachOImageTypeBundle:               return @"MH_BUNDLE";
        case kMTMachOImageTypeLibraryStub:          return @"MH_DYLIB_STUB";
        case kMTMachOImageTypeDsym:                 return @"MH_DSYM";
        case kMTMachOImageTypeKext:                 return @"MH_KEXT_BUNDLE";
        case kMTMachOImageTypeFileSet:              return @"MH_FILESET";
        default:                                    return @"MH_UNKNOWN";
    }
}

NSString *MTMachOLoadCommandName(uint32_t command)
{
    switch (command)
    {
        #define case(s) case s: return @#s
        case(LC_SEGMENT);
        case(LC_SYMTAB);
        case(LC_SYMSEG);
        case(LC_THREAD);
        case(LC_UNIXTHREAD);
        case(LC_LOADFVMLIB);
        case(LC_IDFVMLIB);
        case(LC_IDENT);
        case(LC_FVMFILE);
        case(LC_PREPAGE);
        case(LC_DYSYMTAB);
        case(LC_LOAD_DYLIB);
        case(LC_ID_DYLIB);
        case(LC_LOAD_DYLINKER);
        case(LC_ID_DYLINKER);
        case(LC_PREBOUND_DYLIB);
        case(LC_ROUTINES);
        case(LC_SUB_FRAMEWORK);
        case(LC_SUB_UMBRELLA);
        case(LC_SUB_CLIENT);
        case(LC_SUB_LIBRARY);
        case(LC_TWOLEVEL_HINTS);
        case(LC_PREBIND_CKSUM);
        case(LC_LOAD_WEAK_DYLIB);
        case(LC_SEGMENT_64);
        case(LC_ROUTINES_64);
        case(LC_UUID);
        case(LC_RPATH);
        case(LC_CODE_SIGNATURE);
        case(LC_SEGMENT_SPLIT_INFO);
        case(LC_REEXPORT_DYLIB);
        case(LC_LAZY_LOAD_DYLIB);
        case(LC_ENCRYPTION_INFO);
        case(LC_DYLD_INFO);
        case(LC_DYLD_INFO_ONLY);
        case(LC_LOAD_UPWARD_DYLIB);
        case(LC_VERSION_MIN_MACOSX);
        case(LC_VERSION_MIN_IPHONEOS);
        case(LC_FUNCTION_STARTS);
        case(LC_DYLD_ENVIRONMENT);
        case(LC_MAIN);
        case(LC_DATA_IN_CODE);
        case(LC_SOURCE_VERSION);
        case(LC_DYLIB_CODE_SIGN_DRS);
        case(LC_ENCRYPTION_INFO_64);
        case(LC_LINKER_OPTION);
        case(LC_LINKER_OPTIMIZATION_HINT);
        case(LC_VERSION_MIN_TVOS);
        case(LC_VERSION_MIN_WATCHOS);
        case(LC_NOTE);
        case(LC_BUILD_VERSION);
        case(LC_DYLD_EXPORTS_TRIE);
        case(LC_DYLD_CHAINED_FIXUPS);
        case(LC_FILESET_ENTRY);
        #undef case

        default: return @"LC_UNKNOWN";
    }
}
