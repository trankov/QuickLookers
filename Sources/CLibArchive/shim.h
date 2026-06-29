#ifndef CLIBARCHIVE_SHIM_H
#define CLIBARCHIVE_SHIM_H
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>   /* ssize_t */

struct archive;
struct archive_entry;

struct archive *archive_read_new(void);
int archive_read_support_format_all(struct archive *);
int archive_read_support_filter_all(struct archive *);
int archive_read_support_format_zip(struct archive *);
int archive_read_support_filter_none(struct archive *);
int archive_read_open_memory(struct archive *, const void *buff, size_t size);
int archive_read_next_header(struct archive *, struct archive_entry **);
const char *archive_entry_pathname(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);
ssize_t archive_read_data(struct archive *, void *buff, size_t size);
int archive_read_data_skip(struct archive *);
int archive_read_free(struct archive *);
#endif
