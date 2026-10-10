#ifndef J2ME_M3G_H
#define J2ME_M3G_H

#include "jvm.h"

/* Register all M3G native methods with miniJVM */
void j2me_m3g_reg_natives(MiniJVM *jvm);

/* Release M3G resources (EGL context, pixel buffers). Call between game sessions. */
void j2me_m3g_cleanup(void);

#endif /* J2ME_M3G_H */
