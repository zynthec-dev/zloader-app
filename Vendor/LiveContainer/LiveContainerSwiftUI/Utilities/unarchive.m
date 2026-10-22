#import "unarchive.h"

#include "archive.h"
#include "archive_entry.h"

static BOOL safeRelativePath(NSString *path) {
    if (!path.length || path.isAbsolutePath || [path containsString:@"\\"]) return NO;
    return ![path.pathComponents containsObject:@".."];
}

static BOOL safeEntry(struct archive_entry *entry) {
    const char *raw = archive_entry_pathname(entry);
    if (!raw || !safeRelativePath([NSString stringWithUTF8String:raw])) return NO;
    mode_t type = archive_entry_filetype(entry);
    if (type != AE_IFREG && type != AE_IFDIR && type != AE_IFLNK) return NO;
    // ZIP/IPAs do not need hard links, device nodes, ACLs or special files.
    if (archive_entry_hardlink(entry)) return NO;
    const char *link = archive_entry_symlink(entry);
    if (link && !safeRelativePath([NSString stringWithUTF8String:link])) return NO;
    return archive_entry_size(entry) >= 0 && archive_entry_size(entry) <= INT64_C(4294967296);
}

static int
copy_data(struct archive *ar, struct archive *aw, NSProgress *progress)
{
  int r;
  const void *buff;
  size_t size;
  la_int64_t offset;

  for (;;) {
    r = archive_read_data_block(ar, &buff, &size, &offset);
    if (r == ARCHIVE_EOF)
      return (ARCHIVE_OK);
    if (r < ARCHIVE_OK)
      return (r);
    r = archive_write_data_block(aw, buff, size, offset);
    if (r < ARCHIVE_OK) {
      fprintf(stderr, "%s\n", archive_error_string(aw));
      return (r);
    }
    progress.completedUnitCount += size;
  }
}

int extract(NSString* fileToExtract, NSString* extractionPath, NSProgress* progress)
{
    struct archive *a;
    struct archive *ext;
    struct archive_entry *entry;
    int flags;
    int r;

    /* Select which attributes we want to restore. */
    flags = ARCHIVE_EXTRACT_TIME;
    flags |= ARCHIVE_EXTRACT_PERM;
    flags |= ARCHIVE_EXTRACT_SECURE_SYMLINKS | ARCHIVE_EXTRACT_SECURE_NODOTDOT;
    char canonicalRoot[PATH_MAX];
    if (!realpath(extractionPath.fileSystemRepresentation, canonicalRoot)) return 1;
    NSString *root = [NSString stringWithUTF8String:canonicalRoot];
    uint64_t totalBytes = 0;
    size_t entryCount = 0;
    int failed = 0;

    // Calculate decompressed size
    a = archive_read_new();
    archive_read_support_format_zip(a);
    archive_read_support_filter_all(a);
    if ((r = archive_read_open_filename(a, fileToExtract.fileSystemRepresentation, 10240))) {
        archive_read_free(a);
        return 1;
    }
    while ((r = archive_read_next_header(a, &entry)) != ARCHIVE_EOF) {
        if (r < ARCHIVE_OK)
            fprintf(stderr, "%s\n", archive_error_string(a));
        if (r < ARCHIVE_OK || !safeEntry(entry) || ++entryCount > 200000 ||
            (totalBytes += archive_entry_size(entry)) > UINT64_C(8589934592)) {
            archive_read_close(a);
            archive_read_free(a);
            return 1;
        }
        progress.totalUnitCount += archive_entry_size(entry);
    }
    archive_read_close(a);
    archive_read_free(a);

    // Re-open the archive and extract
    a = archive_read_new();
    archive_read_support_format_zip(a);
    archive_read_support_filter_all(a);
    if ((r = archive_read_open_filename(a, fileToExtract.fileSystemRepresentation, 10240))) {
        archive_read_free(a);
        return 1;
    }
    ext = archive_write_disk_new();
    archive_write_disk_set_options(ext, flags);
    archive_write_disk_set_standard_lookup(ext);

    while ((r = archive_read_next_header(a, &entry)) != ARCHIVE_EOF) {
        if (r == ARCHIVE_EOF)
            break;
        if (r < ARCHIVE_OK)
            fprintf(stderr, "%s\n", archive_error_string(a));
        if (r < ARCHIVE_OK || !safeEntry(entry)) {
            failed = 1;
            break;
        }
        
        NSString* currentFile = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
        // NSString standardization can rewrite /private/var back to the /var
        // symlink on macOS. Keep the canonical absolute root for libarchive's
        // secure-symlink checks; entry components were validated above.
        NSString* fullOutputPath = [root stringByAppendingPathComponent:currentFile];
        if (![fullOutputPath hasPrefix:[root stringByAppendingString:@"/"]]) { failed = 1; break; }
        //printf("extracting %@ to %@\n", currentFile, fullOutputPath);
        archive_entry_set_pathname(entry, fullOutputPath.fileSystemRepresentation);
        archive_entry_set_perm(entry, archive_entry_perm(entry) & 0777);
        
        r = archive_write_header(ext, entry);
        if (r < ARCHIVE_OK) {
            fprintf(stderr, "%s\n", archive_error_string(ext));
            failed = 1;
            break;
        }
        else if (archive_entry_size(entry) > 0) {
            r = copy_data(a, ext, progress);
            if (r < ARCHIVE_OK)
                fprintf(stderr, "%s\n", archive_error_string(ext));
            if (r < ARCHIVE_OK) {
                failed = 1;
                break;
            }
        }
        r = archive_write_finish_entry(ext);
        if (r < ARCHIVE_OK)
            fprintf(stderr, "%s\n", archive_error_string(ext));
        if (r < ARCHIVE_OK) {
            failed = 1;
            break;
        }
    }
    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);
    
    return failed;
}
