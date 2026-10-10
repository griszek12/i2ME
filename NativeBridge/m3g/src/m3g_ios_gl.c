/*
 * M3G iOS GL platform layer — replaces m3g_android_gl.cpp
 * Provides: bitmap lock/release stubs, native window params
 *
 * Note: These are STUBS — same as on Android. The GL context (EAGL)
 * is managed at the Java/native bridge level, not here.
 */

#include "m3g_defs.h"

/* Bitmap/window stubs — return FALSE so callers handle the error
 * instead of using uninitialized output parameters. iOS uses only
 * SURFACE_MEMORY targets; these are never reached in normal operation. */
M3Gbool m3gglLockNativeBitmap(M3GNativeBitmap bitmap,
                                M3Gubyte **ptr,
                                M3Gsizei *stride) {
    (void)bitmap; (void)ptr; (void)stride;
    return M3G_FALSE;
}

void m3gglReleaseNativeBitmap(M3GNativeBitmap bitmap) {
    (void)bitmap;
}

M3Gbool m3gglGetNativeBitmapParams(M3GNativeBitmap bitmap,
                                     M3GPixelFormat *format,
                                     M3Gint *width, M3Gint *height,
                                     M3Gint *pixels) {
    (void)bitmap; (void)format; (void)width; (void)height; (void)pixels;
    return M3G_FALSE;
}

M3Gbool m3gglGetNativeWindowParams(M3GNativeWindow window,
                                     M3GPixelFormat *format,
                                     M3Gint *width, M3Gint *height) {
    (void)window; (void)format; (void)width; (void)height;
    return M3G_FALSE;
}
