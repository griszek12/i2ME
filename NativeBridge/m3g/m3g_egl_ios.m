/*
 * EGL → EAGL compatibility implementation for iOS.
 * Maps EGL API calls to EAGLContext + offscreen FBO.
 *
 * M3G C engine uses OpenGL ES 1.1 (fixed-function pipeline).
 * This creates a separate EAGLContext from MascotCapsule (which uses ES 2.0).
 *
 * Approach:
 * - One global EAGLContext (ES 1.1) shared across all M3G rendering
 * - Each "EGLSurface" is an offscreen FBO with color + depth renderbuffers
 * - EGLConfig is a dummy pointer (iOS auto-selects format)
 * - EGLDisplay is a dummy singleton
 */

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <Foundation/Foundation.h>
#include "EGL/egl.h"
#include <stdio.h>

/* ============================================================
 * Internal state
 * ============================================================ */

static EAGLContext *g_m3g_eagl_context = nil;
static int g_m3g_egl_initialized = 0;
static EGLint g_m3g_egl_error = EGL_SUCCESS;

/* Context save/restore stack for nested eglMakeCurrent calls.
 * M3G engine's m3gSelectGLContext may call makeCurrent in a loop. */
#define M3G_PREV_CTX_STACK_SIZE 4
static EAGLContext *g_m3g_prev_ctx_stack[M3G_PREV_CTX_STACK_SIZE];
static int g_m3g_prev_ctx_sp = 0;

/* Dummy display/config singletons */
static int g_display_sentinel = 1;
static int g_config_sentinel  = 1;

#define DISPLAY_PTR ((EGLDisplay)&g_display_sentinel)
#define CONFIG_PTR  ((EGLConfig)&g_config_sentinel)

/* ============================================================
 * FBO surface — represents an EGLSurface
 * ============================================================ */

typedef struct {
    GLuint fbo;
    GLuint colorRB;
    GLuint depthRB;
    int width;
    int height;
} M3G_FBOSurface;

/* ============================================================
 * FBO surface tracking (for forced cleanup in eglTerminate)
 * ============================================================ */
#define M3G_MAX_SURFACES 64
static M3G_FBOSurface *g_m3g_surfaces[M3G_MAX_SURFACES];
static int g_m3g_surface_count = 0;

static void track_surface(M3G_FBOSurface *surf) {
    if (g_m3g_surface_count < M3G_MAX_SURFACES)
        g_m3g_surfaces[g_m3g_surface_count++] = surf;
}
static void untrack_surface(M3G_FBOSurface *surf) {
    for (int i = 0; i < g_m3g_surface_count; i++) {
        if (g_m3g_surfaces[i] == surf) {
            g_m3g_surfaces[i] = g_m3g_surfaces[--g_m3g_surface_count];
            return;
        }
    }
}

/* ============================================================
 * EGL Display / Init / Terminate
 * ============================================================ */

EGLDisplay eglGetDisplay(EGLNativeDisplayType display_id) {
    (void)display_id;
    return DISPLAY_PTR;
}

EGLBoolean eglInitialize(EGLDisplay dpy, EGLint *major, EGLint *minor) {
    (void)dpy;
    if (!g_m3g_egl_initialized) {
        g_m3g_eagl_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        if (!g_m3g_eagl_context) {
            printf("[M3G-EGL] ERROR: Failed to create OpenGL ES 1.1 context\n");
            return EGL_FALSE;
        }
        g_m3g_egl_initialized = 1;
    }
    if (major) *major = 1;
    if (minor) *minor = 1;
    return EGL_TRUE;
}

EGLBoolean eglTerminate(EGLDisplay dpy) {
    (void)dpy;
    if (g_m3g_eagl_context) {
        /* Destroy all tracked FBO surfaces before releasing context */
        [EAGLContext setCurrentContext:g_m3g_eagl_context];
        for (int i = 0; i < g_m3g_surface_count; i++) {
            M3G_FBOSurface *surf = g_m3g_surfaces[i];
            if (surf->fbo) glDeleteFramebuffersOES(1, &surf->fbo);
            if (surf->colorRB) glDeleteRenderbuffersOES(1, &surf->colorRB);
            if (surf->depthRB) glDeleteRenderbuffersOES(1, &surf->depthRB);
            free(surf);
        }
        printf("[M3G-EGL] Terminated: freed %d FBO surfaces\n", g_m3g_surface_count);
        g_m3g_surface_count = 0;

        [EAGLContext setCurrentContext:nil];
        g_m3g_eagl_context = nil;
        g_m3g_egl_initialized = 0;
        g_m3g_prev_ctx_sp = 0;
    }
    return EGL_TRUE;
}

EGLint eglGetError(void) {
    EGLint err = g_m3g_egl_error;
    g_m3g_egl_error = EGL_SUCCESS;
    return err;
}

EGLDisplay eglGetCurrentDisplay(void) {
    return DISPLAY_PTR;
}

/* ============================================================
 * EGL Config — dummy (iOS auto-selects)
 * ============================================================ */

EGLBoolean eglChooseConfig(EGLDisplay dpy, const EGLint *attrib_list,
                            EGLConfig *configs, EGLint config_size,
                            EGLint *num_config) {
    (void)dpy; (void)attrib_list;
    if (configs && config_size > 0) {
        configs[0] = CONFIG_PTR;
    }
    if (num_config) *num_config = 1;
    return EGL_TRUE;
}

EGLBoolean eglGetConfigs(EGLDisplay dpy, EGLConfig *configs,
                          EGLint config_size, EGLint *num_config) {
    (void)dpy;
    if (configs && config_size > 0) {
        configs[0] = CONFIG_PTR;
    }
    if (num_config) *num_config = 1;
    return EGL_TRUE;
}

EGLBoolean eglGetConfigAttrib(EGLDisplay dpy, EGLConfig config,
                               EGLint attribute, EGLint *value) {
    (void)dpy; (void)config;
    if (!value) return EGL_FALSE;
    switch (attribute) {
        case EGL_RED_SIZE:   *value = 8; break;
        case EGL_GREEN_SIZE: *value = 8; break;
        case EGL_BLUE_SIZE:  *value = 8; break;
        case EGL_ALPHA_SIZE: *value = 8; break;
        case EGL_DEPTH_SIZE: *value = 24; break;
        case EGL_STENCIL_SIZE: *value = 0; break;
        case EGL_SAMPLES:    *value = 0; break;
        case EGL_SURFACE_TYPE: *value = EGL_PBUFFER_BIT | EGL_WINDOW_BIT | EGL_PIXMAP_BIT; break;
        case EGL_CONFIG_ID:  *value = 1; break;
        case EGL_CONFIG_CAVEAT: *value = EGL_NONE; break;
        case EGL_NATIVE_VISUAL_ID: *value = 0; break;
        default: *value = 0; break;
    }
    return EGL_TRUE;
}

/* ============================================================
 * EGL Context
 * ============================================================ */

EGLContext eglCreateContext(EGLDisplay dpy, EGLConfig config,
                             EGLContext share_context,
                             const EGLint *attrib_list) {
    (void)dpy; (void)config; (void)share_context; (void)attrib_list;
    /* Return the singleton EAGL context as an opaque pointer */
    return (EGLContext)(__bridge void *)g_m3g_eagl_context;
}

EGLBoolean eglDestroyContext(EGLDisplay dpy, EGLContext ctx) {
    (void)dpy; (void)ctx;
    /* Don't actually destroy — singleton managed by init/terminate */
    return EGL_TRUE;
}

EGLBoolean eglQueryContext(EGLDisplay dpy, EGLContext ctx,
                            EGLint attribute, EGLint *value) {
    (void)dpy; (void)ctx;
    if (!value) return EGL_FALSE;
    if (attribute == EGL_CONFIG_ID) *value = 1;
    else *value = 0;
    return EGL_TRUE;
}

/* ============================================================
 * EGL Surface — creates FBO with renderbuffers
 * ============================================================ */

static EGLSurface createFBOSurface(int width, int height) {
    /* Auto-initialize if needed */
    if (!g_m3g_eagl_context) {
        eglInitialize(DISPLAY_PTR, NULL, NULL);
    }
    if (!g_m3g_eagl_context) {
        printf("[M3G-EGL] ERROR: No GL context for FBO creation\n");
        return EGL_NO_SURFACE;
    }
    /* Must have GL context current to create FBO */
    EAGLContext *prev = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:g_m3g_eagl_context];

    M3G_FBOSurface *surf = (M3G_FBOSurface *)calloc(1, sizeof(M3G_FBOSurface));
    if (!surf) {
        g_m3g_egl_error = EGL_BAD_ALLOC;
        [EAGLContext setCurrentContext:prev];
        return EGL_NO_SURFACE;
    }
    surf->width = width;
    surf->height = height;

    while (glGetError() != GL_NO_ERROR) {}

    glGenFramebuffersOES(1, &surf->fbo);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, surf->fbo);

    glGenRenderbuffersOES(1, &surf->colorRB);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, surf->colorRB);
    glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_RGBA8_OES, width, height);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES,
                                  GL_RENDERBUFFER_OES, surf->colorRB);

    glGenRenderbuffersOES(1, &surf->depthRB);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, surf->depthRB);
    glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT24_OES, width, height);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES,
                                  GL_RENDERBUFFER_OES, surf->depthRB);

    GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
    if (status != GL_FRAMEBUFFER_COMPLETE_OES) {
        printf("[M3G-EGL] FBO incomplete: status=0x%X size=%dx%d\n", status, width, height);
        if (surf->fbo) glDeleteFramebuffersOES(1, &surf->fbo);
        if (surf->colorRB) glDeleteRenderbuffersOES(1, &surf->colorRB);
        if (surf->depthRB) glDeleteRenderbuffersOES(1, &surf->depthRB);
        free(surf);
        g_m3g_egl_error = EGL_BAD_ALLOC;
        [EAGLContext setCurrentContext:prev];
        return EGL_NO_SURFACE;
    }

    track_surface(surf);
    [EAGLContext setCurrentContext:prev];
    return (EGLSurface)surf;
}

EGLSurface eglCreatePbufferSurface(EGLDisplay dpy, EGLConfig config,
                                     const EGLint *attrib_list) {
    (void)dpy; (void)config;
    int w = 256, h = 256;
    if (attrib_list) {
        for (int i = 0; attrib_list[i] != EGL_NONE; i += 2) {
            if (attrib_list[i] == EGL_WIDTH) w = attrib_list[i + 1];
            if (attrib_list[i] == EGL_HEIGHT) h = attrib_list[i + 1];
        }
    }
    return createFBOSurface(w, h);
}

EGLSurface eglCreateWindowSurface(EGLDisplay dpy, EGLConfig config,
                                    EGLNativeWindowType win,
                                    const EGLint *attrib_list) {
    (void)dpy; (void)config; (void)win; (void)attrib_list;
    /* M3G doesn't really use window surfaces on mobile — create a default PBuffer */
    return createFBOSurface(240, 320);
}

EGLSurface eglCreatePixmapSurface(EGLDisplay dpy, EGLConfig config,
                                    EGLNativePixmapType pixmap,
                                    const EGLint *attrib_list) {
    (void)dpy; (void)config; (void)pixmap; (void)attrib_list;
    return createFBOSurface(240, 320);
}

EGLBoolean eglDestroySurface(EGLDisplay dpy, EGLSurface surface) {
    (void)dpy;
    if (!surface) return EGL_TRUE;
    M3G_FBOSurface *surf = (M3G_FBOSurface *)surface;

    untrack_surface(surf);

    if (g_m3g_eagl_context) {
        EAGLContext *prev = [EAGLContext currentContext];
        [EAGLContext setCurrentContext:g_m3g_eagl_context];

        if (surf->fbo) glDeleteFramebuffersOES(1, &surf->fbo);
        if (surf->colorRB) glDeleteRenderbuffersOES(1, &surf->colorRB);
        if (surf->depthRB) glDeleteRenderbuffersOES(1, &surf->depthRB);

        [EAGLContext setCurrentContext:prev];
    }
    free(surf);
    return EGL_TRUE;
}

EGLBoolean eglQuerySurface(EGLDisplay dpy, EGLSurface surface,
                            EGLint attribute, EGLint *value) {
    (void)dpy;
    if (!surface || !value) return EGL_FALSE;
    M3G_FBOSurface *surf = (M3G_FBOSurface *)surface;
    switch (attribute) {
        case EGL_WIDTH:  *value = surf->width; break;
        case EGL_HEIGHT: *value = surf->height; break;
        case EGL_RENDER_BUFFER: *value = EGL_BACK_BUFFER; break;
        case EGL_CONFIG_ID: *value = 1; break;
        default: *value = 0; break;
    }
    return EGL_TRUE;
}

/* ============================================================
 * EGL Make Current / Swap
 * ============================================================ */

EGLBoolean eglMakeCurrent(EGLDisplay dpy, EGLSurface draw,
                            EGLSurface read, EGLContext ctx) {
    (void)dpy; (void)read;

    if (!ctx || ctx == EGL_NO_CONTEXT) {
        /* Unbind — pop previous context from stack */
        EAGLContext *prev = nil;
        if (g_m3g_prev_ctx_sp > 0) {
            prev = g_m3g_prev_ctx_stack[--g_m3g_prev_ctx_sp];
        }
        [EAGLContext setCurrentContext:prev];
        return EGL_TRUE;
    }

    /* Push current context onto stack before switching */
    if (g_m3g_prev_ctx_sp < M3G_PREV_CTX_STACK_SIZE) {
        g_m3g_prev_ctx_stack[g_m3g_prev_ctx_sp++] = [EAGLContext currentContext];
    }
    [EAGLContext setCurrentContext:g_m3g_eagl_context];

    if (draw && draw != EGL_NO_SURFACE) {
        M3G_FBOSurface *surf = (M3G_FBOSurface *)draw;
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, surf->fbo);
    }

    return EGL_TRUE;
}

EGLBoolean eglSwapBuffers(EGLDisplay dpy, EGLSurface surface) {
    (void)dpy; (void)surface;
    glFlush();
    return EGL_TRUE;
}

EGLBoolean eglCopyBuffers(EGLDisplay dpy, EGLSurface surface,
                            EGLNativePixmapType target) {
    (void)dpy; (void)surface; (void)target;
    /* Not implemented — return FALSE so callers use the fallback
     * (glReadPixels) path instead of silently discarding pixels. */
    return EGL_FALSE;
}

const char *eglQueryString(EGLDisplay dpy, EGLint name) {
    (void)dpy;
    switch (name) {
        case EGL_VERSION: return "1.1 (EAGL compat)";
        case EGL_VENDOR:  return "Apple (EAGL)";
        case EGL_EXTENSIONS: return "";
        default: return "";
    }
}
