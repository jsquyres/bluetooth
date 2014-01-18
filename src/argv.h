#ifndef ARGV_H
#define ARGV_H

#include <list>
#include <string>

std::list<std::string> opal_argv_split_inter(const char *src_string,
                                             int delimiter,
                                             int include_empty);

#endif
