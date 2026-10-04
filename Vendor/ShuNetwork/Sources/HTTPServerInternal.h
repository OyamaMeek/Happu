#import "FileAccessInternal.h"
@import GCDWebServer;
GCDWebServerResponse *ShuErrorResponse(NSError *error);
NSString *ShuRelativePath(NSURL *url, NSString *prefix, NSError **error);
BOOL ShuMatchesServerURL(NSURLComponents *components, GCDWebServerRequest *request);
GCDWebServerResponse *ShuDAVResponse(GCDWebServerRequest *request, ShuFileAccess *access, NSString *path, NSData *body);
