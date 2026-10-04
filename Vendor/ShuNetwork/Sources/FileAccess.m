#import "FileAccessInternal.h"
#import <sys/stat.h>
#import <fcntl.h>
#import <dirent.h>
#import <unistd.h>
#import <stdio.h>

NSError *ShuError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"ShuNetwork" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}
static BOOL Fail(NSError **error, NSInteger code, NSString *message) {
    if (error) *error = ShuError(code, message);
    return NO;
}
static BOOL IOFail(NSError **error) {
    int code = errno;
    return Fail(error, code == EEXIST ? 409 : (code == ELOOP || code == ENOTDIR ? 403 : (code == ENOENT ? 404 : 500)), [NSString stringWithFormat:@"文件操作失败：%s (%d)", strerror(code), code]);
}
static NSArray<NSString *> *Parts(NSString *path, BOOL allowRoot, NSError **error) {
    if (path.length == 0 && allowRoot) return @[];
    NSArray *parts = [path componentsSeparatedByString:@"/"];
    for (NSString *part in parts) {
        if (!part.length || [part hasPrefix:@"."] || [part containsString:@"\\"] || [part rangeOfString:[NSString stringWithFormat:@"%C", (unichar)0]].location != NSNotFound) {
            Fail(error, 403, @"路径包含禁止访问的名称或分隔符。"); return nil;
        }
    }
    return parts;
}
static int OpenParts(int anchor, NSArray<NSString *> *parts, NSError **error) {
    int fd = openat(anchor, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    for (NSString *part in parts) {
        if (fd < 0) break;
        int child = openat(fd, part.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        int saved = errno; close(fd); errno = saved; fd = child;
    }
    if (fd < 0) IOFail(error);
    return fd;
}
static BOOL Same(int a, int b) {
    struct stat x, y;
    return a >= 0 && b >= 0 && fstat(a, &x) == 0 && fstat(b, &y) == 0 && x.st_dev == y.st_dev && x.st_ino == y.st_ino;
}
BOOL ShuWriteAll(int fd, NSData *data, NSError **error) {
    const uint8_t *bytes = data.bytes;
    size_t remaining = data.length;
    while (remaining) {
        ssize_t n = write(fd, bytes, remaining);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return IOFail(error);
        remaining -= n; bytes += n;
    }
    return YES;
}

BOOL ShuFinishFile(int *fd, NSError **error) {
    BOOL ok = fsync(*fd) == 0;
    if (!ok) IOFail(error);
    if (close(*fd) && ok) ok = IOFail(error);
    *fd = -1;
    return ok;
}

@implementation ShuUpload {
@public
    int fd;
    NSString *name;
    NSString *destination;
    BOOL finished;
}
- (instancetype)init { if ((self = [super init])) fd = -1; return self; }
- (void)dealloc { if (fd >= 0) close(fd); }
@end

@implementation ShuFileAccess {
    int _workspace, _root, _stage;
    NSURL *_workspaceURL;
    NSArray *_rootParts;
    NSString *_stageName;
    NSMutableSet<ShuUpload *> *_uploads;
    BOOL _valid;
}
- (instancetype)initWithWorkspaceURL:(NSURL *)workspaceURL sharedDirectoryURL:(NSURL *)directoryURL error:(NSError **)error {
    if ((self = [super init])) {
        _workspace = _root = _stage = -1;
        _uploads = [NSMutableSet new];
        NSArray *base = workspaceURL.standardizedURL.pathComponents;
        NSArray *folder = directoryURL.standardizedURL.pathComponents;
        if (folder.count < base.count || ![[folder subarrayWithRange:NSMakeRange(0, base.count)] isEqual:base]) {
            Fail(error, 403, @"共享目录必须位于工作区内。"); return nil;
        }
        NSString *relative = [[folder subarrayWithRange:NSMakeRange(base.count, folder.count - base.count)] componentsJoinedByString:@"/"];
        _rootParts = Parts(relative, YES, error);
        if (!_rootParts) return nil;
        _workspaceURL = workspaceURL.URLByResolvingSymlinksInPath;
        _workspace = open(_workspaceURL.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (_workspace < 0) { IOFail(error); return nil; }
        _root = OpenParts(_workspace, _rootParts, error);
        if (_root < 0) return nil;
        _stageName = [@".shu-network-" stringByAppendingString:NSUUID.UUID.UUIDString];
        if (mkdirat(_root, _stageName.fileSystemRepresentation, 0700)) { IOFail(error); return nil; }
        _stage = openat(_root, _stageName.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (_stage < 0) { IOFail(error); unlinkat(_root, _stageName.fileSystemRepresentation, AT_REMOVEDIR); return nil; }
        _valid = YES;
    }
    return self;
}
- (void)dealloc {
    if (_stage >= 0) {
        NSError *error;
        if (![self cleanup:&error]) NSLog(@"共享会话清理失败：%@", error);
    }
    if (_stage >= 0) close(_stage);
    if (_root >= 0) close(_root);
    if (_workspace >= 0) close(_workspace);
}
- (BOOL)validate:(NSError **)error {
    if (!_valid) return Fail(error, 503, @"共享会话已停止。");
    int workspace = open(_workspaceURL.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    BOOL same = Same(workspace, _workspace);
    if (workspace >= 0) close(workspace);
    int root = OpenParts(_workspace, _rootParts, error);
    same = same && Same(root, _root);
    if (root >= 0) close(root);
    return same || Fail(error, 403, @"共享根目录或其祖先已被替换。");
}
- (int)parent:(NSString *)path leaf:(NSString **)leaf error:(NSError **)error {
    NSArray *parts = Parts(path, NO, error);
    if (!parts || ![self validate:error]) return -1;
    *leaf = parts.lastObject;
    return OpenParts(_root, [parts subarrayWithRange:NSMakeRange(0, parts.count - 1)], error);
}
- (NSArray<NSDictionary *> *)listAtRelativePath:(NSString *)path error:(NSError **)error {
    @synchronized(self) {
        NSArray *parts = Parts(path, YES, error);
        if (!parts || ![self validate:error]) return nil;
        int fd = OpenParts(_root, parts, error);
        if (fd < 0) return nil;
        DIR *dir = fdopendir(fd);
        if (!dir) { IOFail(error); close(fd); return nil; }
        NSMutableArray *items = [NSMutableArray new];
        struct dirent *entry;
        errno = 0;
        while ((entry = readdir(dir))) {
            if (entry->d_name[0] == '.') continue;
            struct stat info;
            if (fstatat(fd, entry->d_name, &info, AT_SYMLINK_NOFOLLOW)) { IOFail(error); closedir(dir); return nil; }
            if (!S_ISREG(info.st_mode) && !S_ISDIR(info.st_mode)) continue;
            NSString *name = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:entry->d_name length:strlen(entry->d_name)];
            [items addObject:@{@"name": name, @"isDirectory": @(S_ISDIR(info.st_mode)), @"size": @(info.st_size), @"modified": @((double)info.st_mtimespec.tv_sec + info.st_mtimespec.tv_nsec / 1e9)}];
            errno = 0;
        }
        int saved = errno;
        if (closedir(dir) || saved) { if (saved) errno = saved; IOFail(error); return nil; }
        return [items sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    }
}
- (int)openRegularFileAtRelativePath:(NSString *)path error:(NSError **)error {
    @synchronized(self) {
        NSString *leaf; int parent = [self parent:path leaf:&leaf error:error];
        if (parent < 0) return -1;
        int fd = openat(parent, leaf.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
        int saved = errno; close(parent); errno = saved;
        if (fd < 0) { IOFail(error); return -1; }
        struct stat info;
        if (fstat(fd, &info) || !S_ISREG(info.st_mode)) { close(fd); Fail(error, 403, @"只允许读取普通文件。"); return -1; }
        return fd;
    }
}
- (BOOL)createDirectoryAtRelativePath:(NSString *)path error:(NSError **)error {
    @synchronized(self) {
        NSString *leaf; int parent = [self parent:path leaf:&leaf error:error];
        if (parent < 0) return NO;
        int result = mkdirat(parent, leaf.fileSystemRepresentation, 0755);
        int saved = errno; close(parent); errno = saved;
        return result == 0 || IOFail(error);
    }
}
static BOOL Remove(int parent, NSString *name, BOOL internal, NSError **error) {
    struct stat info;
    if (fstatat(parent, name.fileSystemRepresentation, &info, AT_SYMLINK_NOFOLLOW)) return IOFail(error);
    if (!S_ISDIR(info.st_mode)) {
        if (!internal && !S_ISREG(info.st_mode)) return Fail(error, 403, @"拒绝链接或特殊文件。");
        return unlinkat(parent, name.fileSystemRepresentation, 0) == 0 || IOFail(error);
    }
    int fd = openat(parent, name.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0) return IOFail(error);
    DIR *dir = fdopendir(fd);
    if (!dir) { close(fd); return IOFail(error); }
    BOOL ok = YES; struct dirent *entry; errno = 0;
    while ((entry = readdir(dir))) {
        if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
        NSString *child = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:entry->d_name length:strlen(entry->d_name)];
        if (!internal && entry->d_name[0] == '.') { ok = Fail(error, 403, @"目录含隐藏项目，拒绝删除。"); break; }
        if (!Remove(fd, child, internal, error)) { ok = NO; break; }
        errno = 0;
    }
    if (ok && errno) ok = IOFail(error);
    if (closedir(dir) && ok) ok = IOFail(error);
    if (ok) ok = unlinkat(parent, name.fileSystemRepresentation, AT_REMOVEDIR) == 0 || IOFail(error);
    return ok;
}
- (BOOL)removeItemAtRelativePath:(NSString *)path error:(NSError **)error {
    @synchronized(self) {
        NSString *leaf; int parent = [self parent:path leaf:&leaf error:error];
        if (parent < 0) return NO;
        BOOL ok = Remove(parent, leaf, NO, error); close(parent); return ok;
    }
}
- (ShuUpload *)beginUpload:(NSString *)path error:(NSError **)error {
    @synchronized(self) {
        NSString *leaf; int parent = [self parent:path leaf:&leaf error:error];
        if (parent < 0) return nil;
        struct stat info;
        int exists = fstatat(parent, leaf.fileSystemRepresentation, &info, AT_SYMLINK_NOFOLLOW);
        int saved = errno; close(parent); errno = saved;
        if (exists == 0) { Fail(error, S_ISLNK(info.st_mode) ? 403 : 409, @"目标已存在。"); return nil; }
        if (errno != ENOENT) { IOFail(error); return nil; }
        ShuUpload *upload = [ShuUpload new]; upload->name = NSUUID.UUID.UUIDString; upload->destination = path;
        upload->fd = openat(_stage, upload->name.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
        if (upload->fd < 0) { IOFail(error); return nil; }
        [_uploads addObject:upload]; return upload;
    }
}
- (BOOL)writeUpload:(ShuUpload *)upload data:(NSData *)data error:(NSError **)error {
    @synchronized(self) {
        if (![self validate:error]) return NO;
        if (![_uploads containsObject:upload] || upload->fd < 0) return Fail(error, 500, @"上传文件描述符已关闭。");
        return ShuWriteAll(upload->fd, data, error);
    }
}
- (BOOL)finishUpload:(ShuUpload *)upload error:(NSError **)error {
    @synchronized(self) {
        if (![_uploads containsObject:upload] || upload->fd < 0) return Fail(error, 500, @"上传已结束。");
        BOOL ok = ShuFinishFile(&upload->fd, error);
        upload->finished = ok;
        return ok;
    }
}
- (BOOL)publishUpload:(ShuUpload *)upload error:(NSError **)error {
    @synchronized(self) {
        if (!upload || !upload->finished || ![_uploads containsObject:upload]) return Fail(error, 400, @"上传请求尚未完整结束。");
        NSString *leaf; int parent = [self parent:upload->destination leaf:&leaf error:error];
        if (parent < 0) return NO;
        BOOL ok = renameatx_np(_stage, upload->name.fileSystemRepresentation, parent, leaf.fileSystemRepresentation, RENAME_EXCL) == 0;
        int saved = errno; close(parent); errno = saved;
        if (!ok) return IOFail(error);
        [_uploads removeObject:upload]; return YES;
    }
}
static BOOL Copy(int source, NSString *name, int destination, NSString *target, NSError **error) {
    struct stat info;
    if (fstatat(source, name.fileSystemRepresentation, &info, AT_SYMLINK_NOFOLLOW)) return IOFail(error);
    if (!S_ISREG(info.st_mode) && !S_ISDIR(info.st_mode)) return Fail(error, 403, @"复制包含链接或特殊文件。");
    int input = openat(source, name.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC | (S_ISDIR(info.st_mode) ? O_DIRECTORY : 0));
    if (input < 0) return IOFail(error);
    if (S_ISDIR(info.st_mode)) {
        if (mkdirat(destination, target.fileSystemRepresentation, 0700)) { close(input); return IOFail(error); }
        int output = openat(destination, target.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (output < 0) { close(input); return IOFail(error); }
        DIR *dir = fdopendir(input);
        if (!dir) { close(input); close(output); return IOFail(error); }
        BOOL ok = YES; struct dirent *entry; errno = 0;
        while ((entry = readdir(dir))) {
            if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
            if (entry->d_name[0] == '.') { ok = Fail(error, 403, @"复制目录包含隐藏项目。"); break; }
            NSString *child = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:entry->d_name length:strlen(entry->d_name)];
            if (!Copy(input, child, output, child, error)) { ok = NO; break; }
            errno = 0;
        }
        if (ok && errno) ok = IOFail(error);
        if (closedir(dir) && ok) ok = IOFail(error);
        if (close(output) && ok) ok = IOFail(error);
        return ok;
    }
    int output = openat(destination, target.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (output < 0) { close(input); return IOFail(error); }
    BOOL ok = YES; uint8_t buffer[65536]; ssize_t n;
    while ((n = read(input, buffer, sizeof(buffer))) != 0) {
        if (n < 0) { if (errno == EINTR) continue; ok = IOFail(error); break; }
        if (!ShuWriteAll(output, [NSData dataWithBytesNoCopy:buffer length:n freeWhenDone:NO], error)) { ok = NO; break; }
    }
    if (close(input) && ok) ok = IOFail(error);
    if (fsync(output) && ok) ok = IOFail(error);
    if (close(output) && ok) ok = IOFail(error);
    return ok;
}
- (BOOL)copyItemAtRelativePath:(NSString *)source toRelativePath:(NSString *)destination move:(BOOL)move error:(NSError **)error {
    @synchronized(self) {
        NSString *from, *to;
        int src = [self parent:source leaf:&from error:error]; if (src < 0) return NO;
        int dst = [self parent:destination leaf:&to error:error]; if (dst < 0) { close(src); return NO; }
        if ([destination hasPrefix:[source stringByAppendingString:@"/"]]) { close(src); close(dst); return Fail(error, 403, @"不能复制到源目录内部。"); }
        NSString *stage = NSUUID.UUID.UUIDString;
        struct stat sourceIdentity;
        if (fstatat(src, from.fileSystemRepresentation, &sourceIdentity, AT_SYMLINK_NOFOLLOW)) { close(src); close(dst); return IOFail(error); }
        BOOL ok = Copy(src, from, _stage, stage, error);
        if (ok) {
            close(dst); dst = [self parent:destination leaf:&to error:error];
            ok = dst >= 0 && [self validate:error];
        }
        if (ok && move) {
            struct stat current;
            if (fstatat(src, from.fileSystemRepresentation, &current, AT_SYMLINK_NOFOLLOW)) ok = IOFail(error);
            else if (current.st_ino != sourceIdentity.st_ino || current.st_dev != sourceIdentity.st_dev || current.st_mode != sourceIdentity.st_mode) ok = Fail(error, 403, @"移动源已被替换。");
            else if (renameatx_np(src, from.fileSystemRepresentation, dst, to.fileSystemRepresentation, RENAME_EXCL)) ok = IOFail(error);
        } else if (ok && renameatx_np(_stage, stage.fileSystemRepresentation, dst, to.fileSystemRepresentation, RENAME_EXCL)) ok = IOFail(error);
        if (!ok || move) {
            NSError *cleanupError;
            if (!Remove(_stage, stage, YES, &cleanupError) && cleanupError.code != 404) { if (error) *error = cleanupError; ok = NO; }
        }
        close(src); if (dst >= 0) close(dst); return ok;
    }
}
- (void)invalidate { @synchronized(self) { _valid = NO; } }
- (void)discardUpload:(ShuUpload *)upload {
    @synchronized(self) {
        if (![_uploads containsObject:upload]) return;
        if (upload->fd >= 0) { close(upload->fd); upload->fd = -1; }
        if (unlinkat(_stage, upload->name.fileSystemRepresentation, 0) == 0 || errno == ENOENT) [_uploads removeObject:upload];
    }
}
- (BOOL)cleanup:(NSError **)error {
    @synchronized(self) {
        _valid = NO;
        for (ShuUpload *upload in _uploads) {
            if (upload->fd >= 0) {
                int result = close(upload->fd); upload->fd = -1;
                if (result) return IOFail(error);
            }
        }
        if (_stageName && !Remove(_root, _stageName, YES, error)) return NO;
        _stageName = nil; [_uploads removeAllObjects];
        if (_stage >= 0) { int result = close(_stage); _stage = -1; if (result) return IOFail(error); }
        return YES;
    }
}
@end
