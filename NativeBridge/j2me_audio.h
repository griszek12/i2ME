#ifndef J2ME_AUDIO_H
#define J2ME_AUDIO_H

#include "jvm.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Register audio-related native methods with the JVM.
void j2me_audio_reg_natives(MiniJVM *jvm);

/// Stop and release all active audio players. Call between game sessions.
void j2me_audio_stop_all(void);

#ifdef __cplusplus
}
#endif

#endif /* J2ME_AUDIO_H */
