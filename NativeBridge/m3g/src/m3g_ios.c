/*
 * M3G iOS platform layer — replaces m3g_android.cpp
 * Provides: zlib inflate, logging, assertions
 */

#include "m3g_defs.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <zlib.h>

/* zlib inflate — identical to Android/Symbian version */
M3Gsizei m3gSymbianInflateBlock(M3Gsizei srcLength,
                                 const M3Gubyte *src,
                                 M3Gsizei dstLength,
                                 M3Gubyte *dst) {
    uLongf len = (uLongf)dstLength;
    if (uncompress((Bytef *)dst, &len, (const Bytef *)src, (uLong)srcLength) != Z_OK) {
        return 0;
    }
    return (M3Gsizei)len;
}

/* Profiling stubs */
void m3gBeginProfile(int stat) { (void)stat; }
void m3gEndProfile(int stat) { (void)stat; }
void m3gCleanupProfile(void) {}

/* Logging */
#if defined(M3G_LOGLEVEL)
void m3gLogMessage(const char *format, ...) {
    va_list args;
    va_start(args, format);
    printf("[M3G] ");
    vprintf(format, args);
    printf("\n");
    va_end(args);
}

void m3gBeginLog(void) {
    /* no-op on iOS */
}

void m3gEndLog(void) {
    /* no-op on iOS */
}
#endif /* M3G_LOGLEVEL */

/* Assertions */
#if defined(M3G_DEBUG)
void m3gAssertFailed(const char *filename, int line) {
    printf("[M3G] ASSERT FAILED: %s:%d\n", filename, line);
    abort();
}
#endif
