#include "stdwrap.h"

// These functions might look stupid, but it's necessary because zig treat stdout macro differently in macOS and Linux
FILE* getstdin() {
    return stdin;
}

FILE* getstderr() {
    return stderr;
}