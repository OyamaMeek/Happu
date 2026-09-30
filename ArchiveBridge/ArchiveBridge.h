#ifndef SHU_ARCHIVE_BRIDGE_H
#define SHU_ARCHIVE_BRIDGE_H

#import <ZipArchive.h>

// ZipArchive 2.6.0 的 umbrella 未导出这些 minizip/mz_compat.h 公共函数。
// 声明保持与固定版本官方头文件一致，实现仍来自 ZipArchive。
void *unzOpen(const char *path);
int unzClose(void *file);
int unzGetGlobalInfo64(void *file, unz_global_info64 *info);
int unzGetCurrentFileInfo64(void *file, unz_file_info64 *info, char *filename,
    unsigned long filenameSize, void *extra, unsigned long extraSize,
    char *comment, unsigned long commentSize);
int unzGoToFirstFile(void *file);
int unzGoToNextFile(void *file);
int unzOpenCurrentFilePassword(void *file, const char *password);
int unzReadCurrentFile(void *file, void *buffer, uint32_t length);
int unzCloseCurrentFile(void *file);

#endif
