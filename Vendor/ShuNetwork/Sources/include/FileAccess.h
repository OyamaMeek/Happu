#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface ShuFileAccess : NSObject
- (nullable instancetype)initWithWorkspaceURL:(NSURL *)workspaceURL sharedDirectoryURL:(NSURL *)directoryURL error:(NSError **)error;
- (nullable NSArray<NSDictionary *> *)listAtRelativePath:(NSString *)path error:(NSError **)error;
- (int)openRegularFileAtRelativePath:(NSString *)path error:(NSError **)error;
- (BOOL)createDirectoryAtRelativePath:(NSString *)path error:(NSError **)error;
- (BOOL)removeItemAtRelativePath:(NSString *)path error:(NSError **)error;
- (BOOL)copyItemAtRelativePath:(NSString *)source toRelativePath:(NSString *)destination move:(BOOL)move error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
