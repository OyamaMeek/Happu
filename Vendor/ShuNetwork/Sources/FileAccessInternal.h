#import "include/FileAccess.h"
NS_ASSUME_NONNULL_BEGIN
NSError *ShuError(NSInteger code, NSString *message);
BOOL ShuWriteAll(int descriptor, NSData *data, NSError **error);
BOOL ShuFinishFile(int *descriptor, NSError **error);
@interface ShuUpload : NSObject
@end
@interface ShuFileAccess (Session)
- (nullable NSDictionary *)metadataAtRelativePath:(NSString *)path error:(NSError **)error;
- (nullable ShuUpload *)beginUpload:(NSString *)path error:(NSError **)error;
- (BOOL)writeUpload:(ShuUpload *)upload data:(NSData *)data error:(NSError **)error;
- (BOOL)finishUpload:(ShuUpload *)upload error:(NSError **)error;
- (BOOL)publishUpload:(ShuUpload *)upload error:(NSError **)error;
- (void)discardUpload:(ShuUpload *)upload;
- (void)invalidate;
- (BOOL)cleanup:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
