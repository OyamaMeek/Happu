#import "../Sources/FileAccessInternal.h"
#import <fcntl.h>
#import <unistd.h>

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc != 2) return 2;
        int fd = open(argv[1], O_CREAT | O_EXCL | O_RDWR, 0600);
        if (fd < 0) return 3;
        close(fd);
        NSError *error;
        if (ShuWriteAll(fd, [@"data" dataUsingEncoding:NSUTF8StringEncoding], &error) || !error) return 4;
        error = nil;
        if (ShuFinishFile(&fd, &error) || !error || fd != -1) return 5;
        int savedInput = dup(STDIN_FILENO);
        fd = open(argv[1], O_RDWR);
        if (fd < 0 || dup2(fd, STDIN_FILENO) < 0) return 6;
        if (fd != STDIN_FILENO) close(fd);
        fd = STDIN_FILENO;
        error = nil;
        BOOL success = ShuWriteAll(fd, [@"descriptor zero" dataUsingEncoding:NSUTF8StringEncoding], &error) && ShuFinishFile(&fd, &error);
        if (savedInput >= 0) { dup2(savedInput, STDIN_FILENO); close(savedInput); }
        if (!success || fd != -1) return 7;
        NSData *bytes = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        if (![bytes isEqual:[@"descriptor zero" dataUsingEncoding:NSUTF8StringEncoding]]) return 8;
        NSFileManager *manager = NSFileManager.defaultManager;
        NSURL *workspace = [NSURL fileURLWithPath:[[NSString stringWithUTF8String:argv[1]] stringByAppendingString:@".workspace"]];
        NSURL *relocated = [NSURL fileURLWithPath:[workspace.path stringByAppendingString:@".relocated"]];
        if (![manager createDirectoryAtURL:workspace withIntermediateDirectories:YES attributes:nil error:&error]) return 9;
        ShuFileAccess *access = [[ShuFileAccess alloc] initWithWorkspaceURL:workspace sharedDirectoryURL:workspace error:&error];
        if (!access || ![manager moveItemAtURL:workspace toURL:relocated error:&error] || ![manager createSymbolicLinkAtURL:workspace withDestinationURL:relocated error:&error]) return 10;
        error = nil;
        BOOL rejected = [access listAtRelativePath:@"" error:&error] == nil && error.code == 403;
        if (![access cleanup:NULL]) return 11;
        if (!rejected) { puts("ASSERTION: workspace replacement by symlink must be rejected"); return 12; }
        puts("NETWORK_NATIVE_IO_RESULT {\"passed\":4,\"failed\":0,\"skipped\":0}");
    }
    return 0;
}
