/*
 * GLES/gl.h compatibility — redirects to iOS OpenGL ES 1.1 headers.
 * M3G engine includes <GLES/gl.h> (Android path); on iOS the path is
 * <OpenGLES/ES1/gl.h>. This shim bridges the difference.
 */

#ifndef GLES_GL_H_COMPAT
#define GLES_GL_H_COMPAT

#include <OpenGLES/ES1/gl.h>
#include <OpenGLES/ES1/glext.h>

#endif /* GLES_GL_H_COMPAT */
