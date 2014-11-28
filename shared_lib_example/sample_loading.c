#include <stdio.h>
#include <dlfcn.h>
#include <ctype.h>
#include <assert.h>
#include <stdlib.h>

#include "../ptp.h"

#define handleLoad(handle, funcPtr, funcKey) {\
    funcPtr = dlsym(handle, funcKey);\
    if ((error = dlerror()) != NULL) {\
        fputs(error, stderr);\
        exit(-1);\
    }\
}

// Get function pointers in like this:
// Later during load, refer to them by keyname / name used in the library.
const char*
ptp_prop_getvalbyname(PTPParams* params, char* name, uint16_t dpc) = NULL;

static char *error = NULL;
static void *handle = NULL;

int main() {
    handle = dlopen("../libchdkptp.so", RTLD_LAZY);
    if (handle == NULL) {
        fputs(dlerror(), stderr);
        exit(-1);
    }

    handleLoad(handle, ptp_prop_getvalbyname, "ptp_prop_getvalbyname");

    // Sanity check
    assert(ptp_prop_getvalbyname != NULL);

    printf("ptp_usb_write_func: %p\n", ptp_prop_getvalbyname);

    return 0;
}
