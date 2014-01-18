#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "argv.h"

#define OPAL_ERR_OUT_OF_RESOURCE -1
#define OPAL_SUCCESS 0
#define ARGSIZE 4096

static int opal_argv_count(char **argv)
{
  char **p;
  int i;

  if (NULL == argv)
    return 0;

  for (i = 0, p = argv; *p; i++, p++)
    continue;

  return i;
}


static int opal_argv_append_nosize(char ***argv, const char *arg)
{
  int argc;
    
  /* Create new argv. */

  if (NULL == *argv) {
    *argv = (char**) malloc(2 * sizeof(char *));
    if (NULL == *argv) {
      return OPAL_ERR_OUT_OF_RESOURCE;
    }
    argc = 0;
    (*argv)[0] = NULL;
    (*argv)[1] = NULL;
  }

  /* Extend existing argv. */
  else {
    /* count how many entries currently exist */
    argc = opal_argv_count(*argv);
        
    *argv = (char**) realloc(*argv, (argc + 2) * sizeof(char *));
    if (NULL == *argv) {
      return OPAL_ERR_OUT_OF_RESOURCE;
    }
  }

  /* Set the newest element to point to a copy of the arg string */

  (*argv)[argc] = strdup(arg);
  if (NULL == (*argv)[argc]) {
    return OPAL_ERR_OUT_OF_RESOURCE;
  }

  argc = argc + 1;
  (*argv)[argc] = NULL;

  return OPAL_SUCCESS;
}


/*
 * Append a string to the end of a new or existing argv array.
 */
int opal_argv_append(int *argc, char ***argv, const char *arg)
{
  int rc;
    
  /* add the new element */
  if (OPAL_SUCCESS != (rc = opal_argv_append_nosize(argv, arg))) {
    return rc;
  }
    
  *argc = opal_argv_count(*argv);
    
  return OPAL_SUCCESS;
}



/*
 * Split a string into a NULL-terminated argv array.
 */
char **opal_argv_split_inter(const char *src_string, int delimiter,
				    int include_empty)
{
  char arg[ARGSIZE];
  char **argv = NULL;
  const char *p;
  char *argtemp;
  int argc = 0;
  size_t arglen;

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
        if (OPAL_SUCCESS != opal_argv_append(&argc, &argv, arg))
          return NULL;
      }
    }

    /* tail argument, add straight from the original string */

    else if ('\0' == *p) {
      if (OPAL_SUCCESS != opal_argv_append(&argc, &argv, src_string))
	return NULL;
      src_string = p;
      continue;
    }

    /* long argument, malloc buffer, copy and add */

    else if (arglen > (ARGSIZE - 1)) {
      argtemp = (char*) malloc(arglen + 1);
      if (NULL == argtemp)
	return NULL;

      strncpy(argtemp, src_string, arglen);
      argtemp[arglen] = '\0';

      if (OPAL_SUCCESS != opal_argv_append(&argc, &argv, argtemp)) {
	free(argtemp);
	return NULL;
      }

      free(argtemp);
    }

    /* short argument, copy to buffer and add */

    else {
      strncpy(arg, src_string, arglen);
      arg[arglen] = '\0';

      if (OPAL_SUCCESS != opal_argv_append(&argc, &argv, arg))
	return NULL;
    }

    src_string = p + 1;
  }

  /* All done */

  return argv;
}
