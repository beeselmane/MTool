#import <MTool/MTool.h>
#import <MTool/MTFatFile.h>

// transferTo:
#import <NSStream+pipe.h>

// For struct fat_header, struct fat_arch, etc.
#import <mach-o/fat.h>

#pragma mark - MTFatFileEntryDescriptor

@interface MTFatFileEntryDescriptor (Private)

// This is used internally
- (instancetype) initWithType:(MTMachineType)type subtype:(MTMachineSubtype)subtype offset:(UInt64)offset size:(UInt64)size alignment:(UInt32)alignment;

- (instancetype) initWithRawEntry:(const void *)entry is64bit:(BOOL)is64;

@end

@implementation MTFatFileEntryDescriptor
{
    struct fat_arch_64 _underlying;
}

@dynamic subtype;
@dynamic type;

@dynamic alignment;
@dynamic offset;
@dynamic size;

// This is calculated from `alignment`
@dynamic trueAlignment;

- (instancetype) initWithType:(MTMachineType)type subtype:(MTMachineSubtype)subtype offset:(UInt64)offset size:(UInt64)size alignment:(UInt32)alignment
{
    self = [super init];

    if (self)
    {
        self->_underlying.cputype = type;
        self->_underlying.cpusubtype = subtype;
        self->_underlying.offset = offset;
        self->_underlying.size = size;
        self->_underlying.align = alignment;
    }

    return self;
}

- (instancetype) initWithRawEntry:(const void *)_entry is64bit:(BOOL)is64
{
    self = [super init];

    if (self)
    {
        // Internally, we store everything as a 64 bit entry.
        if (is64) {
            struct fat_arch_64 *entry = (struct fat_arch_64 *)_entry;

            self->_underlying.cputype = MTSwapToHostEndian(entry->cputype);
            self->_underlying.cpusubtype = MTSwapToHostEndian(entry->cpusubtype);
            self->_underlying.offset = MTSwapToHostEndian(entry->offset);
            self->_underlying.size = MTSwapToHostEndian(entry->size);
            self->_underlying.align = MTSwapToHostEndian(entry->align);
        } else {
            struct fat_arch *entry = (struct fat_arch *)_entry;

            self->_underlying.cputype = MTSwapToHostEndian(entry->cputype);
            self->_underlying.cpusubtype = MTSwapToHostEndian(entry->cpusubtype);
            self->_underlying.offset = MTSwapToHostEndian(entry->offset);
            self->_underlying.size = MTSwapToHostEndian(entry->size);
            self->_underlying.align = MTSwapToHostEndian(entry->align);
        }
    }

    return self;
}

#pragma mark Property getters

- (MTMachineType) type
{
    return self->_underlying.cputype;
}

- (MTMachineSubtype) subtype
{
    return self->_underlying.cpusubtype;
}

- (UInt64) offset
{
    return self->_underlying.offset;
}

- (UInt64) size
{
    return self->_underlying.size;
}

- (UInt32) alignment
{
    return self->_underlying.align;
}

- (UInt64) trueAlignment
{
    return (1 << [self alignment]);
}

@end

#pragma mark - MTFatFile

@interface MTFatFile (Private)

// Read header, validate magic, detect entry types.
- (NSInteger) readHeaderFromBuffer:(const void *)buffer size:(NSUInteger)size;

// Calculate the length of all archive entries in this file
- (NSUInteger) entryLength;

- (NSInteger) readEntriesFromBuffer:(const void *)buffer size:(NSUInteger)size;

// Check if the pair (type, subtype) is a recognizable machine type/subtype.
// Be permissible on subtype, but the machine types should be well understood.
// This is used during validation, as well as to detect hidden entries that lipo
//   sometimes likes to output (if passed the right flags, that is)
- (BOOL) isValidType:(MTMachineType)type subtype:(MTMachineSubtype)subtype;

@end

@implementation MTFatFile
{
    NSMutableArray<MTFatFileEntryDescriptor *> *_entries;

    struct fat_header _header;

    // Cache of the full archive data, if provided.
    // If we have no other source for this archive, we need to keep this around
    NSData *_dataCache;

    // The location this file was loaded from, if provided.
    // If this object is valid, we generally don't need to cache the archive data.
    NSURL *_url;

    // This is used for various support routines
    NSUInteger _archiveSize;
}

@synthesize is64bit = _is64bit;

@dynamic members;
@dynamic magic;

#pragma mark Loading Archives

+ (instancetype) loadFromData:(NSData *)data
{
    MTFatFile *instance = [[MTFatFile alloc] init];

    if (instance)
    {
        instance->_archiveSize = [data length];

        const UInt8 *buffer = (const UInt8 *)[data bytes];

        NSInteger bytesConsumed = [instance parseHeaderFromBuffer:buffer size:[data length]];

        if (bytesConsumed == -1)
        {
            NSLog(@"Buffer is too small for FAT header!");

            return nil;
        }

        buffer += bytesConsumed;
        NSInteger result = [instance readEntriesFromBuffer:buffer size:([data length] - bytesConsumed)];

        if (result < 0)
        {
            NSLog(@"Buffer is too small for FAT entries!");

            return nil;
        }

        instance->_dataCache = data;
    }

    return instance;
}

+ (instancetype) loadFromURL:(NSURL *)url
{
    MTFatFile *instance = [[MTFatFile alloc] init];

    if (instance)
    {
        NSNumber *fileSize;

        if (![url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil])
        {
            NSLog(@"Item at URL '%@' is not a file!", url);

            return nil;
        }

        instance->_archiveSize = [fileSize unsignedIntegerValue];

        NSInputStream *stream = [NSInputStream inputStreamWithURL:url];
        [stream open];

        // We read the header before anything else. This has a fixed size.
        UInt8 headerBuffer[sizeof(struct fat_header)];

        // First, read up to a page so that we can get the header data
        NSInteger bytesRead = [stream read:headerBuffer maxLength:sizeof(struct fat_header)];

        if (bytesRead <= 0)
        {
            [stream close];

            if (bytesRead)
                NSLog(@"Error reading %lu bytes from URL '%@'!", PAGE_SIZE, url);

            return nil;
        }

        NSInteger headerLength = [instance parseHeaderFromBuffer:headerBuffer size:sizeof(struct fat_header)];
        NSUInteger advance = (sizeof(struct fat_header) - headerLength);

        if (headerLength == -1)
        {
            [stream close];

            NSLog(@"Could not file valid FAT header in file at URL '%@'!", url);

            return nil;
        }

        NSUInteger entryBufferLength = [instance entryLength];

        if (!entryBufferLength)
        {
            [stream close];

            return instance;
        }

        UInt8 *entryBuffer = malloc(entryBufferLength);
        NSUInteger offset = 0;

        if (!entryBuffer) {
            [stream close];

            NSLog(@"Failed to allocate buffer for entries (required size: %llu)!", (UInt64)entryBufferLength);

            return nil;
        } else if (advance) {
            memcpy(entryBuffer, &headerBuffer[headerLength], advance);
        }

        bytesRead = [stream read:&entryBuffer[offset] maxLength:(entryBufferLength - offset)];

        if (bytesRead <= 0)
        {
            [stream close];

            NSLog(@"Found unexpected end of stream while reading from URL '%@'!", url);

            return nil;
        }

        NSInteger entryLength = [instance readEntriesFromBuffer:entryBuffer size:entryBufferLength];
        advance = entryBufferLength - entryLength;

        if (entryLength == -1)
        {
            [stream close];

            NSLog(@"Encountered corrupted entries in the FAT file at URL '%@'!", url);

            return nil;
        }

        // TODO: Look for lipo hidden entries after the end of the non-hidden entries.
        [stream close];

        // Save the source location for this object.
        instance->_url = url;
    }

    return instance;
}

#pragma mark Private Initialization Methods

- (NSInteger) parseHeaderFromBuffer:(const void *)buffer size:(NSUInteger)size
{
    // Buffer too short!
    if (size < sizeof(struct fat_header))
        return -1;

    memcpy(&self->_header, buffer, sizeof(struct fat_header));
    NSInteger bytesConsumed = sizeof(struct fat_header);

    // Swap these in place so we don't have to swap them later.
    self->_header.nfat_arch = MTSwapToHostEndian(self->_header.nfat_arch);
    self->_header.magic = MTSwapToHostEndian(self->_header.magic);

    if (self->_header.magic == FAT_MAGIC)
    {
        // 32-bit FAT haeder found
        self->_is64bit = NO;

        return bytesConsumed;
    }

    if (self->_header.magic == FAT_MAGIC_64)
    {
        // 64-bit FAT header found
        self->_is64bit = YES;

        return bytesConsumed;
    }

    return -1;
}

- (NSUInteger) entryLength
{
    NSUInteger multiplier = [self is64bit] ? sizeof(struct fat_arch_64) : sizeof(struct fat_arch);

    return (self->_header.nfat_arch * multiplier);
}

- (NSInteger) readEntriesFromBuffer:(const void *)buffer size:(NSUInteger)size
{
    NSUInteger advance = [self is64bit] ? sizeof(struct fat_arch_64) : sizeof(struct fat_arch);
    NSUInteger totalSize = (self->_header.nfat_arch * advance);

    // Buffer too short!
    if (size < totalSize)
        return -1;

    for (NSUInteger i = 0; i < self->_header.nfat_arch; i++)
    {
        MTFatFileEntryDescriptor *entry = [[MTFatFileEntryDescriptor alloc] initWithRawEntry:buffer + (i * advance) is64bit:[self is64bit]];
        if (!entry) return -1;

        [self->_entries addObject:entry];
    }

    return totalSize;
}

- (BOOL) isValidType:(MTMachineType)type subtype:(MTMachineSubtype)subtype
{
    // First level types
    if (type == kMTMachineTypeAArch64 || type == kMTMachineTypeX86_64)
        return YES;

    // 32-bit variants
    if (type == kMTMachineTypeARM || type == kMTMachineTypeI386)
        return YES;

    // Historic types
    if (type == kMTMachineTypePowerPC64 || type == kMTMachineTypePowerPC)
        return YES;

    return NO;
}

#pragma mark Empty Archive Creation

- (instancetype) init
{
    self = [super init];

    if (self)
    {
        self->_entries = [[NSMutableArray alloc] init];

        self->_header.magic = FAT_MAGIC_64;
        self->_header.nfat_arch = 0;
        self->_is64bit = YES;

        self->_dataCache = nil;
        self->_url = nil;
    }

    return self;
}

#pragma mark Property get/set

- (NSData *) magic
{
    UInt32 magicData = MTSwapToBigEndian(self->_header.magic);

    return [NSData dataWithBytes:&magicData length:sizeof(UInt32)];
}

- (NSArray<MTFatFileEntryDescriptor *> *) members
{
    return [self->_entries copy];
}

- (void) setIs64bit:(BOOL)is64bit
{
    // TODO: Change format of archive

    if ([self is64bit] && !is64bit) {
        //
    } else if (![self is64bit] && is64bit) {
        //
    }

    self->_is64bit = is64bit;
}

#pragma mark Validation

- (BOOL) validate
{
    BOOL result = YES;

    for (MTFatFileEntryDescriptor *entry in self->_entries)
    {
        if ([entry offset] + [entry size] > self->_archiveSize)
        {
            NSLog(@"Warning: Entry in FAT file goes past end of archive!");

            result = NO;
        }

        if ([entry offset] % (1 << [entry alignment]))
        {
            NSLog(@"Warning: Found improperly aligned entry in FAT archive!");

            result = NO;
        }

        // This seems somewhat arbitrary, but this is what lipo enforces
        if ([entry alignment] > 15)
        {
            NSLog(@"Warning: Found alignment larger than macOS tools allow in FAT archive!");

            result = NO;
        }

        if (![self isValidType:[entry type] subtype:[entry subtype]])
        {
            NSLog(@"Warning: Found unrecognized type/subtype pair in FAT archive!");

            result = NO;
        }
    }

    for (MTFatFileEntryDescriptor *first in self->_entries)
    {
        for (MTFatFileEntryDescriptor *second in self->_entries)
        {
            if ([first type] == [second type] && [first subtype] == [second subtype])
            {
                NSLog(@"Warning: Found duplicate type/subtype pair in FAT archive!");

                result = NO;
            }
        }
    }

    return result;
}

#pragma mark Backing store URL

- (BOOL) copyTo:(NSURL *)url
{
    if (![self writeArchiveToURL:url])
        return NO;

    self->_url = url;

    // Drop this reference if no longer needed
    if (self->_dataCache)
        self->_dataCache = nil;

    return YES;
}

#pragma mark Writing out data

- (BOOL) writeEntry:(MTFatFileEntryDescriptor *)entry toStream:(NSOutputStream *)stream
{
    NSInputStream *inputStream;

    if (self->_url) {
        inputStream = [NSInputStream inputStreamWithURL:self->_url];
        [inputStream setProperty:@([entry offset]) forKey:NSStreamFileCurrentOffsetKey];
    } else if (self->_dataCache) {
        inputStream = [NSInputStream inputStreamWithData:[self dataForEntry:entry]];
    } else {
        NSLog(@"Invalid object!");

        return NO;
    }

    [inputStream open];
    BOOL result = [inputStream transferTo:stream maxBytes:[entry size]];
    [inputStream close];

    return result;
}

- (BOOL) writeEntry:(MTFatFileEntryDescriptor *)entry toURL:(NSURL *)url
{
    NSOutputStream *stream = [NSOutputStream outputStreamWithURL:url append:NO];

    if (!stream)
    {
        NSLog(@"Failed to open output stream to URL '%@'!", url);

        return NO;
    }

    [stream open];
    BOOL result = [self writeEntry:entry toStream:stream];
    [stream close];

    return result;
}

- (NSData *) dataForEntry:(MTFatFileEntryDescriptor *)entry
{
    if (self->_url) {
        NSMutableData *result = [[NSMutableData alloc] initWithLength:[entry size]];
        NSInputStream *stream = [NSInputStream inputStreamWithURL:self->_url];
        [stream setProperty:@([entry offset]) forKey:NSStreamFileCurrentOffsetKey];
        [stream open];

        UInt8 buffer[PAGE_SIZE];
        NSUInteger offset = 0;

        while (offset < [entry size])
        {
            NSInteger bytesRead = [stream read:buffer maxLength:PAGE_SIZE];

            if (bytesRead <= 0)
            {
                NSLog(@"Found unexpected end of stream while reading entry from URL '%@'!", self->_url);

                [stream close];
                return nil;
            }

            [result replaceBytesInRange:NSMakeRange(offset, bytesRead) withBytes:buffer];
            offset += bytesRead;
        }

        [stream close];
        return result;
    } else if (self->_dataCache) {
        return [self->_dataCache subdataWithRange:NSMakeRange([entry offset], [entry size])];
    } else {
        NSLog(@"Invalid object!");

        return nil;
    }
}

- (BOOL) writeArchiveToStream:(NSOutputStream *)stream
{
    NSInputStream *inputStream;

    if (self->_url) {
        inputStream = [NSInputStream inputStreamWithURL:self->_url];

        if (!inputStream)
        {
            NSLog(@"Can't open stream to URL '%@'!", self->_url);

            return NO;
        }
    } else if (self->_dataCache) {
        inputStream = [NSInputStream inputStreamWithData:self->_dataCache];
    } else {
        NSLog(@"Invalid object!");

        return NO;
    }

    [inputStream open];

    if (![inputStream transferTo:stream])
    {
        NSLog(@"Failed to transfer input stream!");

        return NO;
    }

    [inputStream close];
    return YES;
}

- (BOOL) writeArchiveToURL:(NSURL *)url
{
    if (self->_url) {
        return [[NSFileManager defaultManager] copyItemAtURL:self->_url toURL:url error:nil];
    } else if (self->_dataCache) {
        return [self->_dataCache writeToURL:url options:NSDataWritingAtomic error:nil];
    } else {
        NSLog(@"Invalid object!");

        return NO;
    }
}

- (NSData *) dataForArchive
{
    if (self->_url) {
        return [NSData dataWithContentsOfURL:self->_url options:NSDataReadingMappedIfSafe error:nil];
    } else if (self->_dataCache) {
        return self->_dataCache;
    } else {
        NSLog(@"Invalid object!");

        return nil;
    }
}

// TODO: All of these methods...
#pragma mark Modifying archive contents

- (BOOL) setDataForEntry:(MTFatFileEntryDescriptor *)entry fromStream:(NSInputStream *)stream
{
    // We basically just need to zip everything together, first patch entries, then insert updated data.

    if (self->_url) {
        return NO;
    } else if (self->_dataCache) {
        //

        return NO;
    } else {
        NSLog(@"Invalid object!");

        return NO;
    }
}

- (BOOL) setDataForEntry:(MTFatFileEntryDescriptor *)entry fromData:(NSData *)data
{
    NSInputStream *stream = [NSInputStream inputStreamWithData:data];

    [stream open];
    BOOL result = [self setDataForEntry:entry fromStream:stream];
    [stream close];

    return result;
}

- (BOOL) setDataForEntry:(MTFatFileEntryDescriptor *)entry fromURL:(NSURL *)url
{
    NSInputStream *stream = [NSInputStream inputStreamWithURL:url];

    if (!stream)
    {
        NSLog(@"Failed to create input stream for URL '%@'!", url);

        return NO;
    }

    [stream open];
    BOOL result = [self setDataForEntry:entry fromStream:stream];
    [stream close];

    return result;
}

- (BOOL) deleteEntries:(NSArray<MTFatFileEntryDescriptor *> *)entries
{
    if (![entries count])
        return YES;

    //

    return NO;
}

- (BOOL) deleteEntry:(MTFatFileEntryDescriptor *)entry
{
    return [self deleteEntries:@[entry]];
}

- (NSArray<MTFatFileEntryDescriptor *> *) addEntries:(NSArray<NSDictionary<NSString *, id> *> *) entryDescriptions
{
    return @[];
}

- (MTFatFileEntryDescriptor *) addEntry:(NSDictionary<NSString *, id> *)description
{
    NSArray<MTFatFileEntryDescriptor *> *result = [self addEntries:@[description]];

    if (!result || [result count] < 1)
        return nil;

    return [result objectAtIndex:0];
}

@end
