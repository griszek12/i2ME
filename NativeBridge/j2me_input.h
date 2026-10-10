#ifndef J2ME_INPUT_H
#define J2ME_INPUT_H

#include "jvm.h"

#ifdef __cplusplus
extern "C" {
#endif

// Input event types
#define J2ME_INPUT_POINTER_PRESSED  0
#define J2ME_INPUT_POINTER_DRAGGED  1
#define J2ME_INPUT_POINTER_RELEASED 2
#define J2ME_INPUT_KEY_PRESSED      3
#define J2ME_INPUT_KEY_RELEASED     4
#define J2ME_INPUT_KEY_REPEATED     5

/// Register input-related native methods with the JVM.
void j2me_input_reg_natives(MiniJVM *jvm);

/// Post a touch event from iOS (called from main thread).
/// @param type  J2ME_INPUT_POINTER_PRESSED/DRAGGED/RELEASED
/// @param x     Virtual canvas X coordinate
/// @param y     Virtual canvas Y coordinate
void j2me_input_post_touch(int type, int x, int y);

/// Post a key event from iOS (called from main thread).
/// @param type    J2ME_INPUT_KEY_PRESSED/RELEASED/REPEATED
/// @param keyCode J2ME key code
void j2me_input_post_key(int type, int keyCode);

/// Set virtual canvas size for coordinate conversion.
void j2me_input_set_canvas_size(int width, int height);

/// Reset input state (clear ring buffer). Call between game sessions.
void j2me_input_reset(void);

#ifdef __cplusplus
}
#endif

#endif /* J2ME_INPUT_H */
