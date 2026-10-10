#ifndef J2ME_RENDER_H
#define J2ME_RENDER_H

#include "jvm.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Register all J2ME rendering native methods with the JVM.
void j2me_render_reg_natives(MiniJVM *jvm);

/// Callback type for pixel flush — called when a frame is ready to display.
/// @param cgImage A CGImageRef containing the rendered frame. Caller must CFRelease.
/// @param width   Image width
/// @param height  Image height
typedef void (*j2me_flush_callback)(void *cgImage, int width, int height);

/// Set the callback for receiving rendered frames.
void j2me_render_set_flush_callback(j2me_flush_callback callback);

/// Signal render subsystem to stop (all acquire calls return NULL).
/// Must be called before cleanup to protect against zombie threads.
void j2me_render_stop(void);

/// Clean up all render resources. Call between game sessions (after j2me_render_stop).
void j2me_render_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* J2ME_RENDER_H */
