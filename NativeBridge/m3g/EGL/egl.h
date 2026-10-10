/*
 * EGL compatibility layer for iOS — maps EGL API to EAGL + FBO.
 * Allows M3G C engine (m3g_rendercontext.inl) to compile unchanged.
 *
 * EGL types are opaque pointers. The actual implementation uses:
 * - EAGLContext (OpenGL ES 1.1) for GL context
 * - GLuint FBO + renderbuffers for surfaces
 */

#ifndef EGL_EGL_H
#define EGL_EGL_H

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================
 * EGL types — opaque pointers
 * ============================================================ */

typedef void *EGLDisplay;
typedef void *EGLConfig;
typedef void *EGLSurface;
typedef void *EGLContext;
typedef void *EGLNativeDisplayType;
typedef void *EGLNativeWindowType;
typedef void *EGLNativePixmapType;
typedef EGLNativeWindowType NativeWindowType;
typedef EGLNativePixmapType NativePixmapType;
typedef int EGLint;
typedef unsigned int EGLBoolean;

/* ============================================================
 * EGL constants
 * ============================================================ */

#define EGL_DEFAULT_DISPLAY ((EGLNativeDisplayType)0)
#define EGL_NO_CONTEXT      ((EGLContext)0)
#define EGL_NO_SURFACE      ((EGLSurface)0)
#define EGL_NO_DISPLAY      ((EGLDisplay)0)

#define EGL_TRUE            1
#define EGL_FALSE           0
#define EGL_SUCCESS         0x3000
#define EGL_BAD_MATCH       0x3009
#define EGL_NONE            0x3038

/* Config attributes */
#define EGL_RED_SIZE        0x3024
#define EGL_GREEN_SIZE      0x3025
#define EGL_BLUE_SIZE       0x3026
#define EGL_ALPHA_SIZE      0x3021
#define EGL_DEPTH_SIZE      0x3030
#define EGL_STENCIL_SIZE    0x3036
#define EGL_SAMPLES         0x3031
#define EGL_SAMPLE_BUFFERS  0x3032
#define EGL_SURFACE_TYPE    0x3033
#define EGL_CONFIG_ID       0x3028
#define EGL_NATIVE_VISUAL_ID 0x302E
#define EGL_MATCH_NATIVE_PIXMAP 0x3041

/* Surface types */
#define EGL_WINDOW_BIT      0x0004
#define EGL_PBUFFER_BIT     0x0001
#define EGL_PIXMAP_BIT      0x0002

/* Surface attributes */
#define EGL_WIDTH           0x3057
#define EGL_HEIGHT          0x3056

/* Context attributes */
#define EGL_CONTEXT_CLIENT_VERSION 0x3098

/* Query */
#define EGL_RENDER_BUFFER   0x3086
#define EGL_BACK_BUFFER     0x3084
#define EGL_CONFIG_CAVEAT   0x3027
#define EGL_BAD_ALLOC       0x3003
#define EGL_VERSION         0x3054
#define EGL_VENDOR          0x3053
#define EGL_EXTENSIONS      0x3055

/* ============================================================
 * EGL functions — implemented in m3g_egl_ios.m
 * ============================================================ */

EGLDisplay eglGetDisplay(EGLNativeDisplayType display_id);
EGLBoolean eglInitialize(EGLDisplay dpy, EGLint *major, EGLint *minor);
EGLBoolean eglTerminate(EGLDisplay dpy);
EGLint     eglGetError(void);

EGLBoolean eglChooseConfig(EGLDisplay dpy, const EGLint *attrib_list,
                            EGLConfig *configs, EGLint config_size,
                            EGLint *num_config);
EGLBoolean eglGetConfigs(EGLDisplay dpy, EGLConfig *configs,
                          EGLint config_size, EGLint *num_config);
EGLBoolean eglGetConfigAttrib(EGLDisplay dpy, EGLConfig config,
                               EGLint attribute, EGLint *value);

EGLContext eglCreateContext(EGLDisplay dpy, EGLConfig config,
                             EGLContext share_context,
                             const EGLint *attrib_list);
EGLBoolean eglDestroyContext(EGLDisplay dpy, EGLContext ctx);
EGLBoolean eglQueryContext(EGLDisplay dpy, EGLContext ctx,
                            EGLint attribute, EGLint *value);

EGLSurface eglCreateWindowSurface(EGLDisplay dpy, EGLConfig config,
                                    EGLNativeWindowType win,
                                    const EGLint *attrib_list);
EGLSurface eglCreatePbufferSurface(EGLDisplay dpy, EGLConfig config,
                                     const EGLint *attrib_list);
EGLSurface eglCreatePixmapSurface(EGLDisplay dpy, EGLConfig config,
                                    EGLNativePixmapType pixmap,
                                    const EGLint *attrib_list);
EGLBoolean eglDestroySurface(EGLDisplay dpy, EGLSurface surface);
EGLBoolean eglQuerySurface(EGLDisplay dpy, EGLSurface surface,
                            EGLint attribute, EGLint *value);

EGLBoolean eglMakeCurrent(EGLDisplay dpy, EGLSurface draw,
                            EGLSurface read, EGLContext ctx);
EGLBoolean eglSwapBuffers(EGLDisplay dpy, EGLSurface surface);
EGLBoolean eglCopyBuffers(EGLDisplay dpy, EGLSurface surface,
                            EGLNativePixmapType target);
EGLDisplay eglGetCurrentDisplay(void);
const char *eglQueryString(EGLDisplay dpy, EGLint name);

#ifdef __cplusplus
}
#endif

#endif /* EGL_EGL_H */
