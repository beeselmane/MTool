#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTSharedCache : NSObject

+ (instancetype) currentSharedCache;

// This will mmap the file at the provided URL
+ (instancetype) loadFromURL:(NSURL *)url;

@end

// This is how dyld loads one of these things... (see SharedCacheRuntime.cpp)

// preflightCacheFile():
//
// 1. open() RDONLY
// 2. stat()
// 3. Get length, read first 0x4000 bytes.
// 4. Validate magic
//    -- magic should be "dyld_v1<arch>" where <arch> is the name of the cache architecture padded on the left with spaces (0x20) to be exactly 8 bytes in length.
// 5. Validate platform
//    -- if the mapping offset is below 0xE0 (is this the platform offset?), accept.
//    -- check if the platform byte matches (see MachOFile.h for platform definitions)
// 6. Checking mapping count is > 0, < max
// 7. Assume first mapping in cache is text, if the cache has more than 1 mapping,
//      and the second mapping has read and write max protection, assume it's data.
//    Otherwise, if the second mapping does not have this protection, error.
//    Then, assume the linkedit mapping is the last mapping.
// 8. Error if text mapping (0) does not have offset 0.
// 9. Error if (codeSignatureOffset + codeSignatureSize) != cacheLength
// 10. Error if we have a linkedit mapping (> 1 mapping in step 7) and the maximum protection is not VM_PROT_READ
// 11. If we have a linkedit mapping (> 1 mapping in step 7), and the text mapping's maximum protection is not either read + execute or read only, error.
// 12. If there is no linkedit mapping (only 1 mapping in step 7), ensure the text mapping's maximum protection is read and execute.
// -- error out now if any check above failed.
// 13. If there is a data mapping (> 1 mapping in step 7), ensure all mappings except the first and last (text and linkedit) have max protection of read and write, error.
// -- error out now if the check above failed.
// 13.5. (this is ifdef'd out) Error out if either the text mapping's address is the start of the shared region, or if the linkedit mapping's last byte falls outside the shared region.
// 14. Get the end address of the code signature on the shared cache (file offset 0, code signature offset + size) with fcntl. If fcntl errors, error.
// -- error out now if the check above failed
// 15. Ensure the code signature covers the entire cache. Otherwise, error.
// -- error out now if the check above failed
// 16. Map the first 0x4000 bytes of the shared cache with PROT_READ | PROT_EXEC. Otherwise, error.
// -- error out now if the check above failed
// 17. Compare the previously read bytes to the mapped bytes. Error if mismatch.
// -- error out now if the check above failed
// 18. Unmap the first 0x4000 bytes. Return code is not checked.
// ** Now, we loop through each mapping (say i), checking...
// 19.a. First, copy the i'th mapping's inital protection.
// 19.b. If the offset of the header's mappingOffset field is below the mappingWithSlideOffset, do nothing unless (i == 1). If (i == 1), copy the info at slideInfo{Offset,Size}Unused in the header, auth protection to 0. (old caches act this way)
//       Else, look at the structure at mappingWithSlideOffset. copy the slide info offset and size for the specific mapping out, and check the flags for AUTH_DATA and CONST_DATA flags.
//  19.c Then, simply copy mapping info from the header.
//  19.d If there is slide info size > 0 on any given mapping, set VM_PROT_SLIDE on the initial and maximum protection, as well as VM_PROT_NO_AUTH if requested. Copy the slide size, and set the slide start to be the address of the linkedit section + (slide info file offset - linkedit file offset)
// 20. Copy out the rest of the header data, including the number of subcaches (+ 1) (if the mappingOffset is larger than the subCacheArrayCount header field's offset, else just 1)
// -- done. return true.

// mapSplitCacheSystemWide():
//
// 1. preflightCacheFile(). error out if not accepted
// 2. For each sub-cache file in the cache (file i) (from step 20 in preflightCacheFile), call preflightCacheFile() with the suffix '.i'. error out if any are not accepted. (note: there is a possible buffer overflow here if there are more than 15 subcaches. (there is a 16
// 3. Count the number of mappings in all caches, copy the maxSlide from the first cache.
// 4. Copy slide info into kernel-recognized format
// 5. __shared_region_map_and_slide_2_np(); [this is a syscall]
//    -- args:
//       - number of files
//       - (fd, mapping count, slide (from first cache)) for each file
//       - total mapping count
//       - (vm address, region size, file offset, relocation data offset, relocation data size, max protection + flags, initial protection) for each mapping

// Note: File mapped needs to be owned by uid 0 and be protected by SIP (unless disabled)

// In the kernel...
// shared_region_map_and_slide_2_np():
// 1. I haven't looked into this in detail. I'd guess it just directly maps out of the file.
//    There are a few security checks here, it's decently thorough...


// Then, we need to look at how dyld links to these...
// We need to know how to walk mach-o export trie's...

NS_ASSUME_NONNULL_END
