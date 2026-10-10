#ifndef J2ME_UI_H
#define J2ME_UI_H

#include "jvm.h"

#ifdef __cplusplus
extern "C" {
#endif

// UI event types (added to input queue alongside touch/key events)
#define J2ME_UI_COMMAND_ACTION   10
#define J2ME_UI_LIST_SELECT      11
#define J2ME_UI_ALERT_DISMISSED  12

/// Register UI-related native methods with the JVM.
void j2me_ui_reg_natives(MiniJVM *jvm);

/// Callback for creating/showing native iOS views.
/// Called from JVM thread — implementations must dispatch to main thread.
typedef void (*j2me_ui_callback)(int action, const char *data);

/// Set the UI callback.
void j2me_ui_set_callback(j2me_ui_callback callback);

// UI actions for the callback
#define J2ME_UI_ACTION_SHOW_CANVAS    1
#define J2ME_UI_ACTION_SHOW_FORM      2
#define J2ME_UI_ACTION_SHOW_LIST      3
#define J2ME_UI_ACTION_SHOW_ALERT     4
#define J2ME_UI_ACTION_SHOW_TEXTBOX   5

#ifdef __cplusplus
}
#endif

#endif /* J2ME_UI_H */
