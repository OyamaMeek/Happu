#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, ShuHTTPServerMode) { ShuHTTPServerModeBrowser, ShuHTTPServerModeWebDAV };
@interface ShuHTTPServer : NSObject
@property(nonatomic, readonly) uint16_t port;
- (nullable instancetype)initWithWorkspaceURL:(NSURL *)workspaceURL sharedDirectoryURL:(NSURL *)directoryURL error:(NSError **)error;
- (BOOL)startWithMode:(ShuHTTPServerMode)mode error:(NSError **)error;
- (void)stopWithCompletion:(void (^)(NSError * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
