#import "ShuNetwork.h"
#import "FileAccessInternal.h"
@import GCDWebServer;
#import <sys/socket.h>
#import <netdb.h>

static GCDWebServerResponse *ErrorResponse(NSError *error) {
    GCDWebServerDataResponse *response = [GCDWebServerDataResponse responseWithJSONObject:@{@"error": error.localizedDescription ?: @"请求失败。"}];
    response.statusCode = [error.domain isEqual:@"ShuNetwork"] ? error.code : 500;
    return response;
}
static NSString *RelativePath(NSURL *url, NSError **error) {
    NSString *raw = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO].percentEncodedPath;
    if (![raw hasPrefix:@"/files/"]) { if (error) *error = ShuError(404, @"未找到文件接口。"); return nil; }
    NSMutableArray *parts = [NSMutableArray new];
    NSString *tail = [raw substringFromIndex:7];
    if (!tail.length) return @"";
    for (NSString *part in [tail componentsSeparatedByString:@"/"]) {
        NSString *decoded = part.stringByRemovingPercentEncoding;
        if (!decoded.length || [decoded hasPrefix:@"."] || [decoded containsString:@"/"] || [decoded containsString:@"\\"] || [decoded rangeOfString:[NSString stringWithFormat:@"%C", (unichar)0]].location != NSNotFound) {
            if (error) *error = ShuError(403, @"路径含禁止访问的项目或编码分隔符。"); return nil;
        }
        [parts addObject:decoded];
    }
    return [parts componentsJoinedByString:@"/"];
}
static BOOL CheckSource(GCDWebServerRequest *request, NSError **error) {
    char host[NI_MAXHOST], service[NI_MAXSERV];
    const struct sockaddr *address = request.localAddressData.bytes;
    if (!address || getnameinfo(address, (socklen_t)request.localAddressData.length, host, sizeof(host), service, sizeof(service), NI_NUMERICHOST | NI_NUMERICSERV)) {
        if (error) *error = ShuError(500, @"无法读取监听地址。"); return NO;
    }
    NSString *authority = address->sa_family == AF_INET6 ? [NSString stringWithFormat:@"[%s]:%s", host, service] : [NSString stringWithFormat:@"%s:%s", host, service];
    NSString *origin = request.headers[@"Origin"];
    if (![request.headers[@"Host"] isEqualToString:authority] || (origin && ![origin isEqualToString:[@"http://" stringByAppendingString:authority]])) {
        if (error) *error = ShuError(403, @"请求来源与当前共享服务不一致。"); return NO;
    }
    return YES;
}

@interface ShuHTTPRequest : GCDWebServerRequest
@property(nonatomic) ShuFileAccess *access;
@property(nonatomic) NSString *relativePath;
@property(nonatomic) NSError *failure;
@property(nonatomic) ShuUpload *upload;
@property(nonatomic) NSMutableData *body;
@end
@implementation ShuHTTPRequest
- (BOOL)open:(NSError **)error {
    NSError *failure = self.failure;
    if (!failure) CheckSource(self, &failure);
    if (!failure && [self.method isEqual:@"PUT"]) self.upload = [self.access beginUpload:self.relativePath error:&failure];
    self.failure = failure;
    self.body = [NSMutableData new];
    return YES;
}
- (BOOL)writeData:(NSData *)data error:(NSError **)error {
    if (self.failure) return YES;
    if (self.upload) {
        NSError *failure;
        if (![self.access writeUpload:self.upload data:data error:&failure]) self.failure = failure;
    } else if (self.body.length + data.length <= 65536) {
        [self.body appendData:data];
    } else { self.failure = ShuError(400, @"目录请求体超过允许大小。"); }
    return YES;
}
- (BOOL)close:(NSError **)error {
    if (self.upload && !self.failure) {
        NSError *failure;
        if (![self.access finishUpload:self.upload error:&failure]) self.failure = failure;
    }
    return YES;
}
- (void)dealloc { if (_upload) [_access discardUpload:_upload]; }
@end

@implementation ShuHTTPServer {
    GCDWebServer *_server;
    ShuFileAccess *_access;
    NSMutableArray *_stopCompletions;
    BOOL _stopping;
}
- (instancetype)initWithWorkspaceURL:(NSURL *)workspaceURL sharedDirectoryURL:(NSURL *)directoryURL error:(NSError **)error {
    if ((self = [super init])) {
        _access = [[ShuFileAccess alloc] initWithWorkspaceURL:workspaceURL sharedDirectoryURL:directoryURL error:error];
        if (!_access) return nil;
        _server = [GCDWebServer new];
        _stopCompletions = [NSMutableArray new];
        ShuFileAccess *access = _access;
        [_server addHandlerWithMatchBlock:^GCDWebServerRequest *(NSString *method, NSURL *url, NSDictionary *headers, NSString *path, NSDictionary *query) {
            ShuHTTPRequest *request = [[ShuHTTPRequest alloc] initWithMethod:method url:url headers:headers path:path query:query];
            request.access = access;
            if ([path hasPrefix:@"/files/"]) {
                NSError *error; request.relativePath = RelativePath(url, &error); request.failure = error;
            }
            return request;
        } processBlock:^GCDWebServerResponse *(GCDWebServerRequest *rawRequest) {
            ShuHTTPRequest *request = (ShuHTTPRequest *)rawRequest;
            NSError *error = request.failure;
            if (!error) CheckSource(request, &error);
            if (error) return ErrorResponse(error);
            if ([request.path isEqual:@"/api/list"] && [request.method isEqual:@"GET"]) {
                NSString *path = request.query[@"path"] ?: @"";
                NSArray *entries = [access listAtRelativePath:path error:&error];
                return entries ? [GCDWebServerDataResponse responseWithJSONObject:@{@"path": path, @"entries": entries}] : ErrorResponse(error);
            }
            if ([request.path isEqual:@"/api/directories"] && [request.method isEqual:@"POST"]) {
                id json = request.body ? [NSJSONSerialization JSONObjectWithData:request.body options:0 error:&error] : nil;
                if (![json isKindOfClass:NSDictionary.class] || ![json[@"path"] isKindOfClass:NSString.class]) return ErrorResponse(ShuError(400, @"目录请求必须包含字符串 path。"));
                return [access createDirectoryAtRelativePath:json[@"path"] error:&error] ? [GCDWebServerResponse responseWithStatusCode:201] : ErrorResponse(error);
            }
            if (!request.relativePath) return ErrorResponse(ShuError(404, @"接口不存在。"));
            if ([request.method isEqual:@"PUT"]) {
                return [access publishUpload:request.upload error:&error] ? [GCDWebServerResponse responseWithStatusCode:201] : ErrorResponse(error);
            }
            if ([request.method isEqual:@"DELETE"]) {
                return [access removeItemAtRelativePath:request.relativePath error:&error] ? [GCDWebServerResponse responseWithStatusCode:204] : ErrorResponse(error);
            }
            if ([request.method isEqual:@"GET"]) {
                if (request.headers[@"Range"] && !request.hasByteRange) return ErrorResponse(ShuError(416, @"下载范围无效。"));
                int fd = [access openRegularFileAtRelativePath:request.relativePath error:&error];
                if (fd < 0) return ErrorResponse(error);
                GCDWebServerFileResponse *response = [[GCDWebServerFileResponse alloc] initWithFileDescriptor:fd filename:request.relativePath byteRange:request.byteRange];
                return response ?: ErrorResponse(ShuError(416, @"下载范围超出文件。"));
            }
            return ErrorResponse(ShuError(405, @"此方法不受支持。"));
        }];
    }
    return self;
}
- (uint16_t)port { return (uint16_t)_server.port; }
- (BOOL)startWithMode:(ShuHTTPServerMode)mode error:(NSError **)error {
    if (mode != ShuHTTPServerModeBrowser) { if (error) *error = ShuError(501, @"WebDAV 尚未启用。"); return NO; }
    [GCDWebServer setLogLevel:4];
    NSMutableDictionary *options = [@{GCDWebServerOption_Port: @0, GCDWebServerOption_AutomaticallyMapHEADToGET: @YES, GCDWebServerOption_RequestNATPortMapping: @NO, GCDWebServerOption_ConnectedStateCoalescingInterval: @0} mutableCopy];
#if TARGET_OS_IPHONE
    options[GCDWebServerOption_AutomaticallySuspendInBackground] = @NO;
#endif
    return [_server startWithOptions:options error:error];
}
- (void)stopWithCompletion:(void (^)(NSError *))completion {
    [_stopCompletions addObject:[completion copy]];
    if (_stopping) return;
    _stopping = YES;
    [_access invalidate];
    [_server stopAndDrainWithCompletion:^{
        NSError *error;
        [self->_access cleanup:&error];
        NSArray *completions = [self->_stopCompletions copy];
        [self->_stopCompletions removeAllObjects]; self->_stopping = NO;
        for (void (^callback)(NSError *) in completions) callback(error);
    }];
}
@end
