#ifndef J2ME_MICRO3D_GL_H
#define J2ME_MICRO3D_GL_H

#include "jvm.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Register all MascotCapsule micro3D OpenGL ES 2.0 native methods with the JVM.
void j2me_micro3d_gl_reg_natives(MiniJVM *jvm);

/// Release MascotCapsule GL context and resources. Call between game sessions.
void j2me_micro3d_gl_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* J2ME_MICRO3D_GL_H */
