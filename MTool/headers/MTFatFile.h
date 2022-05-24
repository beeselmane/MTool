#import <Foundation/Foundation.h>
#import <MTool/MTType.h>

@class MTMachO;

NS_ASSUME_NONNULL_BEGIN

// Note: Being a 32 or 64 bit entry is a property shared for a given archive, it is not a per-entry property.
// TODO: We should block against passing descriptors to the wrong archive.
@interface MTFatFileEntryDescriptor : NSObject

@property (nonatomic, readonly) MTMachineType type;

@property (nonatomic, readonly) MTMachineSubtype subtype;

// Note: This may only be a 32 bit field in reality.
@property (nonatomic, readonly) UInt64 offset;

// Note: This may only be a 32 bit field in reality.
@property (nonatomic, readonly) UInt64 size;

// This property holds the shift size for the alignment. The true alignment is 1 << `alignment`
@property (nonatomic, readonly) UInt32 alignment;

// This is the true alignment calculated from the in-file alignment.
@property (nonatomic, readonly) UInt64 trueAlignment;

@end

// Note that there is no protection here against other programs modifying a given archive while
//   this object exists. The object will cache the header and entries on creating, so if the
//   on-disk archive is modified while this object is valid, and then read/writes to entries
//   are performed, there is a very real chance of something being screwed up.
// If you want to ensure this object remains valid, it is your responsibility to track changes
//   to the file on disk or anywhere else by external programs.
@interface MTFatFile : NSObject

// These will perform loading logic immidietely. They will not however validate the data is valid.
// This should be done before attempting to read/write data from this object.
+ (instancetype) loadFromData:(NSData *)data;

+ (instancetype) loadFromURL:(NSURL *)url;

// Create a new archive containing the provided file objects, optionally writing to the provided URL
+ (instancetype) createArchiveForFiles:(NSArray<MTMachO *> *)fileList is64bit:(BOOL)is64bit atURL:(nullable NSURL *)url;

// This will create an empty archive.
- (instancetype) init;

@property (nonatomic, readonly) NSArray<MTFatFileEntryDescriptor *> *members;

// Copy raw file magic bytes.
@property (nonatomic, readonly) NSData *magic;

// Note: Writing to this property will change the header type, invalidating previous entry objects.
// This can fail if changing 64 bit --> 32 bit where archive entries have offset(s) >= 4GB
@property (nonatomic) BOOL is64bit;

// Validate header magic, member entries are non-overlapping, fully in file, padded properly.
- (BOOL) validate;

// Changing backing store URL

// Calling this method will set the backing store URL from which data will be read and modified.
// If this file was loaded from data or created in memory, this url will be written immidietely,
//   and entry caches will be deleted.
// If this file was loaded from another URL, the backing store URL will be changed in place, and
//   this URL will be written immidietely.
- (BOOL) copyTo:(NSURL *)url;

// Writing archive and entriy contents. These methods do not modify the internal data source/backing store.

- (BOOL) writeEntry:(MTFatFileEntryDescriptor *)entry toStream:(NSOutputStream *)stream;

- (BOOL) writeEntry:(MTFatFileEntryDescriptor *)entry toURL:(NSURL *)url;

- (NSData *) dataForEntry:(MTFatFileEntryDescriptor *)entry;

- (BOOL) writeArchiveToStream:(NSOutputStream *)stream;

- (BOOL) writeArchiveToURL:(NSURL *)url;

- (NSData *) dataForArchive;

// Note: These methods will apply fixups to ensure this archive remains valid.
// Fixups will be applied as soon as changes are requested.
// If the archive was loaded from a URL, the changes will be written back IN PLACE. Be careful.
// As such, dealing with large files may not be very efficient.
// Additionally, these may invalidate previously access MTFatFileEntryDescriptor objects for this archive.

- (BOOL) setDataForEntry:(MTFatFileEntryDescriptor *)entry fromStream:(NSInputStream *)stream;

- (BOOL) setDataForEntry:(MTFatFileEntryDescriptor *)entry fromData:(NSData *)data;

- (BOOL) setDataForEntry:(MTFatFileEntryDescriptor *)entry fromURL:(NSURL *)url;

- (BOOL) deleteEntries:(NSArray<MTFatFileEntryDescriptor *> *)entries;

- (BOOL) deleteEntry:(MTFatFileEntryDescriptor *)entry;

// Add multiple entries. Each dictionary in the provided array should have the following keys/values:
// Note: Where "url" and "data" are valid keys, exactly one of the two should be provided.
//   Providing both will not error, but which one is used in undefined.
// 1. Type + Subtype; no entry data (create empty entry at end of archive)
//  - "type" : the MTMachineType as an NSNumber for the new entry
//  - "subtype" : the MTMachineSubtype as an NSNumber for the new entry
// 2. Type + Subtype + Data; include entry data (add entry data to end of archive)
//  - "type" : the MTMachineType as an NSNumber for the new entry
//  - "subtype" : the MTMachineSubtype as an NSNumber for the new entry
//  - "url" : the URL to load the data from (this must be a file URL)
//  - "data" : an NSData object to load the data from.
// 3. Data only; attempt to deduce type and subtype from provided data (add entry data to end of archive; currently supported data formats are <none>.)
//  - "url" : the URL to load the data from (this must be a file URL)
//  - "data" : an NSData object to load the data from.
// TODO: Allow adding from mach-o, ar archives.
- (NSArray<MTFatFileEntryDescriptor *> *) addEntries:(NSArray<NSDictionary<NSString *, id> *> *) entryDescriptions;

// Add a single entry. The format of the description dictionary is discussed above.
- (MTFatFileEntryDescriptor *) addEntry:(NSDictionary<NSString *, id> *)description;

@end

NS_ASSUME_NONNULL_END
