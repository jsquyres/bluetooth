#ifndef ARGV_H
#define ARGV_H

char **opal_argv_split_inter(const char *src_string, int delimiter,
			     int include_empty);

#endif
