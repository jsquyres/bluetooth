/*
 * Strongly influenced by Open MPI (www.open-mpi.org)
 *
 * See Open MPI license file (Open-MPI-license.txt)
 */

#include <list>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "argv.h"

using namespace std;


#define OPAL_ERR_OUT_OF_RESOURCE -1
#define OPAL_SUCCESS 0
#define ARGSIZE 4096


/*
 * Split a string into a std::list<string>
 */
list<string> opal_argv_split_inter(const char *src_string, int delimiter,
                                   int include_empty)
{
    char arg[ARGSIZE];
    const char *p;
    char *argtemp;
    size_t arglen;
    list<string> ret;

    while (src_string && *src_string) {
        p = src_string;
        arglen = 0;

        while (('\0' != *p) && (*p != delimiter)) {
            ++p;
            ++arglen;
        }

        /* zero length argument, skip */

        if (src_string == p) {
            if (include_empty) {
                arg[0] = '\0';
                ret.push_back(arg);
            }
        }

        /* tail argument, add straight from the original string */

        else if ('\0' == *p) {
            ret.push_back(src_string);
            src_string = p;
            continue;
        }

        /* long argument, malloc buffer, copy and add */

        else if (arglen > (ARGSIZE - 1)) {
            argtemp = (char*) malloc(arglen + 1);

            strncpy(argtemp, src_string, arglen);
            argtemp[arglen] = '\0';

            ret.push_back(argtemp);
            free(argtemp);
        }

        /* short argument, copy to buffer and add */

        else {
            strncpy(arg, src_string, arglen);
            arg[arglen] = '\0';

            ret.push_back(arg);
        }

        src_string = p + 1;
    }

    /* All done */

    return ret;
}
