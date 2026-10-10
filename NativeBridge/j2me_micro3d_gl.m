//
// j2me_micro3d_gl.m — OpenGL ES 2.0 bridge for MascotCapsule micro3D on iOS
//
// Provides native method implementations for GLES20.java and Utils.java.
// Creates an offscreen OpenGL ES 2.0 context (EAGLContext + FBO) for rendering.
// All GL functions are proxied 1:1 from Java static native calls.
//

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#include "j2me_micro3d_gl.h"
#include "jvm.h"
#include "jvm_util.h"
#include <stdio.h>
#include <string.h>

// ============================================================
// Offscreen GL context (replaces EGL PBuffer)
// ============================================================

static EAGLContext *g_mc3d_context = nil;
static EAGLContext *g_mc3d_prev_context = nil; // saved context during bind
static GLuint g_mc3d_fbo = 0;
static GLuint g_mc3d_colorRB = 0;
static GLuint g_mc3d_depthRB = 0;
static int g_mc3d_width = 0;
static int g_mc3d_height = 0;

// ============================================================
// Helper macros
// ============================================================

#define GLES20_CLS "com/mascotcapsule/micro3d/v3/GLES20"
#define UTILS_CLS  "com/mascotcapsule/micro3d/v3/Utils"
#define BRIDGE_CLS "javax/microedition/lcdui/NativeBridge"

// Get JniEnv from runtime
#define ENV (runtime->jnienv)

// miniJVM has no localvar_getFloat — float is stored as int bits in localvar slot
static inline float getFloat(JniEnv *env, LocalVarItem *lv, s32 idx) {
    s32 bits = env->localvar_getInt(lv, idx);
    float f;
    memcpy(&f, &bits, sizeof(float));
    return f;
}

// miniJVM string helpers — extract C string from Java String
static inline const char *jstr_to_cstr(JniEnv *env, Instance *jstr, Runtime *rt, Utf8String **out_utf) {
    Utf8String *ustr = utf8_create();
    env->jstring_2_utf8(jstr, ustr, rt);
    *out_utf = ustr;
    return utf8_cstr(ustr);
}

// ============================================================
// Context management native methods
// ============================================================

static s32 n_mc3dInit(Runtime *runtime, JClass *clazz) {
    s32 w = ENV->localvar_getInt(runtime->localvar, 0);
    s32 h = ENV->localvar_getInt(runtime->localvar, 1);

    if (g_mc3d_context == nil) {
        g_mc3d_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!g_mc3d_context) {
            printf("[micro3d] ERROR: Failed to create OpenGL ES 2.0 context\n");
            return RUNTIME_STATUS_NORMAL;
        }
        printf("[micro3d] Created OpenGL ES 2.0 context\n");
    }

    EAGLContext *prev = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:g_mc3d_context];

    // Destroy old FBO if resizing
    if (g_mc3d_fbo) {
        glDeleteFramebuffers(1, &g_mc3d_fbo);
        glDeleteRenderbuffers(1, &g_mc3d_colorRB);
        glDeleteRenderbuffers(1, &g_mc3d_depthRB);
    }

    // Create offscreen FBO
    glGenFramebuffers(1, &g_mc3d_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, g_mc3d_fbo);

    glGenRenderbuffers(1, &g_mc3d_colorRB);
    glBindRenderbuffer(GL_RENDERBUFFER, g_mc3d_colorRB);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, w, h);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, g_mc3d_colorRB);

    glGenRenderbuffers(1, &g_mc3d_depthRB);
    glBindRenderbuffer(GL_RENDERBUFFER, g_mc3d_depthRB);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, w, h);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, g_mc3d_depthRB);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        printf("[micro3d] ERROR: FBO incomplete, status=0x%X\n", status);
    }

    g_mc3d_width = w;
    g_mc3d_height = h;
    printf("[micro3d] Initialized FBO %dx%d\n", w, h);

    [EAGLContext setCurrentContext:prev];
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_mc3dBind(Runtime *runtime, JClass *clazz) {
    g_mc3d_prev_context = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:g_mc3d_context];
    glBindFramebuffer(GL_FRAMEBUFFER, g_mc3d_fbo);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_mc3dRelease(Runtime *runtime, JClass *clazz) {
    glFlush();
    [EAGLContext setCurrentContext:g_mc3d_prev_context];
    g_mc3d_prev_context = nil;
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_mc3dDestroy(Runtime *runtime, JClass *clazz) {
    if (g_mc3d_context) {
        [EAGLContext setCurrentContext:g_mc3d_context];
        if (g_mc3d_fbo) {
            glDeleteFramebuffers(1, &g_mc3d_fbo);
            glDeleteRenderbuffers(1, &g_mc3d_colorRB);
            glDeleteRenderbuffers(1, &g_mc3d_depthRB);
            g_mc3d_fbo = 0;
        }
        [EAGLContext setCurrentContext:nil];
        g_mc3d_context = nil;
        printf("[micro3d] GL context destroyed\n");
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_mc3dResize(Runtime *runtime, JClass *clazz) {
    // Resize is handled by mc3dInit (destroy + recreate)
    return n_mc3dInit(runtime, clazz);
}

// ============================================================
// GL State
// ============================================================

static s32 n_glEnable(Runtime *runtime, JClass *clazz) {
    glEnable((GLenum)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDisable(Runtime *runtime, JClass *clazz) {
    glDisable((GLenum)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glViewport(Runtime *runtime, JClass *clazz) {
    s32 x = ENV->localvar_getInt(runtime->localvar, 0);
    s32 y = ENV->localvar_getInt(runtime->localvar, 1);
    s32 w = ENV->localvar_getInt(runtime->localvar, 2);
    s32 h = ENV->localvar_getInt(runtime->localvar, 3);
    glViewport(x, y, w, h);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glScissor(Runtime *runtime, JClass *clazz) {
    s32 x = ENV->localvar_getInt(runtime->localvar, 0);
    s32 y = ENV->localvar_getInt(runtime->localvar, 1);
    s32 w = ENV->localvar_getInt(runtime->localvar, 2);
    s32 h = ENV->localvar_getInt(runtime->localvar, 3);
    glScissor(x, y, w, h);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glClearColor(Runtime *runtime, JClass *clazz) {
    float r = getFloat(ENV, runtime->localvar, 0);
    float g = getFloat(ENV, runtime->localvar, 1);
    float b = getFloat(ENV, runtime->localvar, 2);
    float a = getFloat(ENV, runtime->localvar, 3);
    glClearColor(r, g, b, a);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glClear(Runtime *runtime, JClass *clazz) {
    glClear((GLbitfield)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDepthMask(Runtime *runtime, JClass *clazz) {
    s32 flag = ENV->localvar_getInt(runtime->localvar, 0);
    glDepthMask(flag ? GL_TRUE : GL_FALSE);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDepthFunc(Runtime *runtime, JClass *clazz) {
    glDepthFunc((GLenum)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glGetError(Runtime *runtime, JClass *clazz) {
    ENV->push_int(runtime->stack, (s32)glGetError());
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glFlush(Runtime *runtime, JClass *clazz) {
    glFlush();
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Blend
// ============================================================

static s32 n_glBlendFunc(Runtime *runtime, JClass *clazz) {
    GLenum sf = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    GLenum df = (GLenum)ENV->localvar_getInt(runtime->localvar, 1);
    glBlendFunc(sf, df);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glBlendFuncSeparate(Runtime *runtime, JClass *clazz) {
    GLenum sRGB = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    GLenum dRGB = (GLenum)ENV->localvar_getInt(runtime->localvar, 1);
    GLenum sA   = (GLenum)ENV->localvar_getInt(runtime->localvar, 2);
    GLenum dA   = (GLenum)ENV->localvar_getInt(runtime->localvar, 3);
    glBlendFuncSeparate(sRGB, dRGB, sA, dA);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glBlendEquation(Runtime *runtime, JClass *clazz) {
    glBlendEquation((GLenum)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glBlendColor(Runtime *runtime, JClass *clazz) {
    float r = getFloat(ENV, runtime->localvar, 0);
    float g = getFloat(ENV, runtime->localvar, 1);
    float b = getFloat(ENV, runtime->localvar, 2);
    float a = getFloat(ENV, runtime->localvar, 3);
    glBlendColor(r, g, b, a);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Cull
// ============================================================

static s32 n_glCullFace(Runtime *runtime, JClass *clazz) {
    glCullFace((GLenum)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glFrontFace(Runtime *runtime, JClass *clazz) {
    glFrontFace((GLenum)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Shaders
// ============================================================

static s32 n_glCreateShader(Runtime *runtime, JClass *clazz) {
    GLenum type = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    ENV->push_int(runtime->stack, (s32)glCreateShader(type));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glShaderSource(Runtime *runtime, JClass *clazz) {
    s32 shader = ENV->localvar_getInt(runtime->localvar, 0);
    Instance *jstr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 1);
    Utf8String *utf;
    const char *src = jstr_to_cstr(ENV, jstr, runtime, &utf);
    GLint len = (GLint)strlen(src);
    glShaderSource(shader, 1, &src, &len);
    utf8_destroy(utf);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glCompileShader(Runtime *runtime, JClass *clazz) {
    glCompileShader((GLuint)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glGetShaderiv(Runtime *runtime, JClass *clazz) {
    GLuint shader = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    GLenum pname  = (GLenum)ENV->localvar_getInt(runtime->localvar, 1);
    Instance *arr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 2);
    s32 offset    = ENV->localvar_getInt(runtime->localvar, 3);
    GLint val = 0;
    glGetShaderiv(shader, pname, &val);
    if (arr) {
        s32 *data = (s32 *)arr->arr_body;
        data[offset] = val;
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glGetShaderInfoLog(Runtime *runtime, JClass *clazz) {
    GLuint shader = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    GLint len = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &len);
    if (len <= 0) {
        ENV->push_ref(runtime->stack, NULL);
        return RUNTIME_STATUS_NORMAL;
    }
    char *buf = malloc(len + 1);
    glGetShaderInfoLog(shader, len, NULL, buf);
    buf[len] = '\0';
    Instance *jstr = ENV->jstring_create_cstr(buf, runtime);
    free(buf);
    ENV->push_ref(runtime->stack, jstr);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDeleteShader(Runtime *runtime, JClass *clazz) {
    glDeleteShader((GLuint)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Programs
// ============================================================

static s32 n_glCreateProgram(Runtime *runtime, JClass *clazz) {
    ENV->push_int(runtime->stack, (s32)glCreateProgram());
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glAttachShader(Runtime *runtime, JClass *clazz) {
    GLuint prog = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    GLuint shdr = (GLuint)ENV->localvar_getInt(runtime->localvar, 1);
    glAttachShader(prog, shdr);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDetachShader(Runtime *runtime, JClass *clazz) {
    GLuint prog = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    GLuint shdr = (GLuint)ENV->localvar_getInt(runtime->localvar, 1);
    glDetachShader(prog, shdr);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glLinkProgram(Runtime *runtime, JClass *clazz) {
    glLinkProgram((GLuint)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glGetProgramiv(Runtime *runtime, JClass *clazz) {
    GLuint prog = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    GLenum pname = (GLenum)ENV->localvar_getInt(runtime->localvar, 1);
    Instance *arr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 2);
    s32 offset = ENV->localvar_getInt(runtime->localvar, 3);
    GLint val = 0;
    glGetProgramiv(prog, pname, &val);
    if (arr) {
        s32 *data = (s32 *)arr->arr_body;
        data[offset] = val;
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glGetProgramInfoLog(Runtime *runtime, JClass *clazz) {
    GLuint prog = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    GLint len = 0;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &len);
    if (len <= 0) {
        ENV->push_ref(runtime->stack, NULL);
        return RUNTIME_STATUS_NORMAL;
    }
    char *buf = malloc(len + 1);
    glGetProgramInfoLog(prog, len, NULL, buf);
    buf[len] = '\0';
    Instance *jstr = ENV->jstring_create_cstr(buf, runtime);
    free(buf);
    ENV->push_ref(runtime->stack, jstr);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glUseProgram(Runtime *runtime, JClass *clazz) {
    glUseProgram((GLuint)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDeleteProgram(Runtime *runtime, JClass *clazz) {
    glDeleteProgram((GLuint)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glReleaseShaderCompiler(Runtime *runtime, JClass *clazz) {
    glReleaseShaderCompiler();
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Attributes
// ============================================================

static s32 n_glGetAttribLocation(Runtime *runtime, JClass *clazz) {
    GLuint prog = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    Instance *jstr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 1);
    Utf8String *utf;
    const char *name = jstr_to_cstr(ENV, jstr, runtime, &utf);
    GLint loc = glGetAttribLocation(prog, name);
    utf8_destroy(utf);
    ENV->push_int(runtime->stack, loc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glEnableVertexAttribArray(Runtime *runtime, JClass *clazz) {
    glEnableVertexAttribArray((GLuint)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDisableVertexAttribArray(Runtime *runtime, JClass *clazz) {
    glDisableVertexAttribArray((GLuint)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

// VBO offset version
static s32 n_glVertexAttribPointer(Runtime *runtime, JClass *clazz) {
    GLuint idx   = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    GLint size   = ENV->localvar_getInt(runtime->localvar, 1);
    GLenum type  = (GLenum)ENV->localvar_getInt(runtime->localvar, 2);
    s32 norm     = ENV->localvar_getInt(runtime->localvar, 3);
    GLsizei stride = (GLsizei)ENV->localvar_getInt(runtime->localvar, 4);
    s32 offset   = ENV->localvar_getInt(runtime->localvar, 5);
    glVertexAttribPointer(idx, size, type, norm ? GL_TRUE : GL_FALSE, stride, (const void *)(intptr_t)offset);
    return RUNTIME_STATUS_NORMAL;
}

// Address version — receives Buffer.address (long) directly from Java
static s32 n_glVertexAttribPointerAddr(Runtime *runtime, JClass *clazz) {
    GLuint idx     = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    GLint size     = ENV->localvar_getInt(runtime->localvar, 1);
    GLenum type    = (GLenum)ENV->localvar_getInt(runtime->localvar, 2);
    s32 norm       = ENV->localvar_getInt(runtime->localvar, 3);
    GLsizei stride = (GLsizei)ENV->localvar_getInt(runtime->localvar, 4);
    // boolean takes 1 slot, so long starts at slot 5
    s64 addr       = ENV->localvar_getLong_2slot(runtime->localvar, 5);
    if (addr == 0) {
        printf("[micro3d] WARNING: glVertexAttribPointer idx=%d with NULL address\n", idx);
    }
    glVertexAttribPointer(idx, size, type, norm ? GL_TRUE : GL_FALSE, stride, (const void *)(intptr_t)addr);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Uniforms
// ============================================================

static s32 n_glGetUniformLocation(Runtime *runtime, JClass *clazz) {
    GLuint prog = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    Instance *jstr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 1);
    Utf8String *utf;
    const char *name = jstr_to_cstr(ENV, jstr, runtime, &utf);
    GLint loc = glGetUniformLocation(prog, name);
    utf8_destroy(utf);
    ENV->push_int(runtime->stack, loc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glUniform1i(Runtime *runtime, JClass *clazz) {
    GLint loc = ENV->localvar_getInt(runtime->localvar, 0);
    GLint v0  = ENV->localvar_getInt(runtime->localvar, 1);
    glUniform1i(loc, v0);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glUniform1f(Runtime *runtime, JClass *clazz) {
    GLint loc = ENV->localvar_getInt(runtime->localvar, 0);
    float v0 = getFloat(ENV, runtime->localvar, 1);
    glUniform1f(loc, v0);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glUniform2f(Runtime *runtime, JClass *clazz) {
    GLint loc = ENV->localvar_getInt(runtime->localvar, 0);
    float v0  = getFloat(ENV, runtime->localvar, 1);
    float v1  = getFloat(ENV, runtime->localvar, 2);
    glUniform2f(loc, v0, v1);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glUniform3f(Runtime *runtime, JClass *clazz) {
    GLint loc = ENV->localvar_getInt(runtime->localvar, 0);
    float v0  = getFloat(ENV, runtime->localvar, 1);
    float v1  = getFloat(ENV, runtime->localvar, 2);
    float v2  = getFloat(ENV, runtime->localvar, 3);
    glUniform3f(loc, v0, v1, v2);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glUniform3fvAddr(Runtime *runtime, JClass *clazz) {
    GLint loc   = ENV->localvar_getInt(runtime->localvar, 0);
    GLsizei cnt = ENV->localvar_getInt(runtime->localvar, 1);
    s64 addr    = ENV->localvar_getLong_2slot(runtime->localvar, 2);
    if (addr) glUniform3fv(loc, cnt, (const float *)(intptr_t)addr);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glUniformMatrix4fv(Runtime *runtime, JClass *clazz) {
    GLint loc      = ENV->localvar_getInt(runtime->localvar, 0);
    GLsizei cnt    = ENV->localvar_getInt(runtime->localvar, 1);
    s32 transpose  = ENV->localvar_getInt(runtime->localvar, 2);
    Instance *arr  = (Instance *)ENV->localvar_getRefer(runtime->localvar, 3);
    s32 offset     = ENV->localvar_getInt(runtime->localvar, 4);
    float *data = arr ? (float *)arr->arr_body : NULL;
    if (data) glUniformMatrix4fv(loc, cnt, transpose ? GL_TRUE : GL_FALSE, data + offset);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Textures
// ============================================================

static s32 n_glGenTextures(Runtime *runtime, JClass *clazz) {
    GLsizei n     = ENV->localvar_getInt(runtime->localvar, 0);
    Instance *arr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 1);
    s32 offset    = ENV->localvar_getInt(runtime->localvar, 2);
    GLuint *ids   = (GLuint *)(arr ? (s32 *)arr->arr_body + offset : NULL);
    if (ids) glGenTextures(n, ids);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDeleteTextures(Runtime *runtime, JClass *clazz) {
    GLsizei n     = ENV->localvar_getInt(runtime->localvar, 0);
    Instance *arr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 1);
    s32 offset    = ENV->localvar_getInt(runtime->localvar, 2);
    GLuint *ids   = (GLuint *)(arr ? (s32 *)arr->arr_body + offset : NULL);
    if (ids) glDeleteTextures(n, ids);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glBindTexture(Runtime *runtime, JClass *clazz) {
    GLenum target  = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    GLuint texture = (GLuint)ENV->localvar_getInt(runtime->localvar, 1);
    glBindTexture(target, texture);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glActiveTexture(Runtime *runtime, JClass *clazz) {
    glActiveTexture((GLenum)ENV->localvar_getInt(runtime->localvar, 0));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glTexParameteri(Runtime *runtime, JClass *clazz) {
    GLenum target = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    GLenum pname  = (GLenum)ENV->localvar_getInt(runtime->localvar, 1);
    GLint param   = ENV->localvar_getInt(runtime->localvar, 2);
    glTexParameteri(target, pname, param);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glIsTexture(Runtime *runtime, JClass *clazz) {
    GLuint tex = (GLuint)ENV->localvar_getInt(runtime->localvar, 0);
    ENV->push_int(runtime->stack, glIsTexture(tex) ? 1 : 0);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glTexImage2DAddr(Runtime *runtime, JClass *clazz) {
    GLenum target = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    GLint level   = ENV->localvar_getInt(runtime->localvar, 1);
    GLint ifmt    = ENV->localvar_getInt(runtime->localvar, 2);
    GLsizei w     = ENV->localvar_getInt(runtime->localvar, 3);
    GLsizei h     = ENV->localvar_getInt(runtime->localvar, 4);
    GLint border  = ENV->localvar_getInt(runtime->localvar, 5);
    GLenum fmt    = (GLenum)ENV->localvar_getInt(runtime->localvar, 6);
    GLenum type   = (GLenum)ENV->localvar_getInt(runtime->localvar, 7);
    s64 addr      = ENV->localvar_getLong_2slot(runtime->localvar, 8);
    glTexImage2D(target, level, ifmt, w, h, border, fmt, type, (const void *)(intptr_t)addr);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Buffer Objects (VBO)
// ============================================================

static s32 n_glGenBuffers(Runtime *runtime, JClass *clazz) {
    GLsizei n     = ENV->localvar_getInt(runtime->localvar, 0);
    Instance *arr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 1);
    s32 offset    = ENV->localvar_getInt(runtime->localvar, 2);
    GLuint *ids   = (GLuint *)(arr ? (s32 *)arr->arr_body + offset : NULL);
    if (ids) glGenBuffers(n, ids);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glDeleteBuffers(Runtime *runtime, JClass *clazz) {
    GLsizei n     = ENV->localvar_getInt(runtime->localvar, 0);
    Instance *arr = (Instance *)ENV->localvar_getRefer(runtime->localvar, 1);
    s32 offset    = ENV->localvar_getInt(runtime->localvar, 2);
    GLuint *ids   = (GLuint *)(arr ? (s32 *)arr->arr_body + offset : NULL);
    if (ids) glDeleteBuffers(n, ids);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glBindBuffer(Runtime *runtime, JClass *clazz) {
    GLenum target = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    GLuint buffer = (GLuint)ENV->localvar_getInt(runtime->localvar, 1);
    glBindBuffer(target, buffer);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_glBufferDataAddr(Runtime *runtime, JClass *clazz) {
    GLenum target  = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    GLsizeiptr sz  = (GLsizeiptr)ENV->localvar_getInt(runtime->localvar, 1);
    s64 addr       = ENV->localvar_getLong_2slot(runtime->localvar, 2);
    GLenum usage   = (GLenum)ENV->localvar_getInt(runtime->localvar, 4); // long takes 2 slots
    glBufferData(target, sz, (const void *)(intptr_t)addr, usage);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Draw
// ============================================================

static s32 n_glDrawArrays(Runtime *runtime, JClass *clazz) {
    GLenum mode = (GLenum)ENV->localvar_getInt(runtime->localvar, 0);
    GLint first = ENV->localvar_getInt(runtime->localvar, 1);
    GLsizei count = ENV->localvar_getInt(runtime->localvar, 2);
    if (count <= 0) return RUNTIME_STATUS_NORMAL;
    // Validate GL state before draw
    GLenum preErr = glGetError(); // clear any pending errors
    glDrawArrays(mode, first, count);
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        printf("[micro3d] glDrawArrays(mode=0x%X, first=%d, count=%d) error=0x%X\n",
               mode, first, count, err);
    }
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Read pixels
// ============================================================

static s32 n_glReadPixelsAddr(Runtime *runtime, JClass *clazz) {
    s32 x  = ENV->localvar_getInt(runtime->localvar, 0);
    s32 y  = ENV->localvar_getInt(runtime->localvar, 1);
    s32 w  = ENV->localvar_getInt(runtime->localvar, 2);
    s32 h  = ENV->localvar_getInt(runtime->localvar, 3);
    GLenum fmt  = (GLenum)ENV->localvar_getInt(runtime->localvar, 4);
    GLenum type = (GLenum)ENV->localvar_getInt(runtime->localvar, 5);
    s64 addr    = ENV->localvar_getLong_2slot(runtime->localvar, 6);
    if (addr) glReadPixels(x, y, w, h, fmt, type, (void *)(intptr_t)addr);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// mc3dBlitToGraphics — copy GL pixels to CGBitmapContext
// ============================================================
// GL framebuffer is RGBA bottom-to-top. CGBitmapContext is BGRA top-to-bottom.
// This method reads the GL buffer and writes it into the Canvas's context.

extern s64 g_native_extra_heap; // from j2me_render.m

static s32 n_mc3dBlitToGraphics(Runtime *runtime, JClass *clazz) {
    s64 ctxHandle = ENV->localvar_getLong_2slot(runtime->localvar, 0);
    s64 pixAddr   = ENV->localvar_getLong_2slot(runtime->localvar, 2);
    s32 w = ENV->localvar_getInt(runtime->localvar, 4);
    s32 h = ENV->localvar_getInt(runtime->localvar, 5);

    if (!ctxHandle || !pixAddr) return RUNTIME_STATUS_NORMAL;

    // The ctxHandle points to our RenderContext struct (from j2me_render.m)
    // RenderContext.ctx is a CGContextRef to a CGBitmapContext
    CGContextRef *ctxPtr = (CGContextRef *)(intptr_t)ctxHandle;
    CGContextRef ctx = *ctxPtr;
    if (!ctx) return RUNTIME_STATUS_NORMAL;

    uint8_t *glPixels = (uint8_t *)(intptr_t)pixAddr;
    uint8_t *canvasPixels = (uint8_t *)CGBitmapContextGetData(ctx);
    size_t canvasW = CGBitmapContextGetWidth(ctx);
    size_t canvasH = CGBitmapContextGetHeight(ctx);
    size_t canvasBPR = CGBitmapContextGetBytesPerRow(ctx);

    if (!canvasPixels || !glPixels) return RUNTIME_STATUS_NORMAL;

    // Blit: GL RGBA → Canvas BGRA
    // NO Y-flip: MascotCapsule projection renders scene upside-down in GL
    // (J2ME Y-down mapped to GL NDC). glReadPixels without flip = correct orientation.
    if (w == (int)canvasW && h == (int)canvasH) {
        // 1:1 copy — no scaling, direct pixel conversion RGBA→BGRA
        int copyW = (w < (int)canvasW) ? w : (int)canvasW;
        int copyH = (h < (int)canvasH) ? h : (int)canvasH;
        for (int y = 0; y < copyH; y++) {
            uint8_t *src = glPixels + y * w * 4;
            uint8_t *dst = canvasPixels + y * canvasBPR;
            for (int x = 0; x < copyW; x++) {
                dst[0] = src[2];  // B
                dst[1] = src[1];  // G
                dst[2] = src[0];  // R
                dst[3] = src[3];  // A
                src += 4;
                dst += 4;
            }
        }
    } else {
        // High-quality downscale via Core Graphics (Lanczos-like interpolation).
        // Create CGImage from GL RGBA pixels, draw scaled into canvas CGContext.
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGContextRef tmpCtx = CGBitmapContextCreate(
            glPixels, w, h, 8, w * 4, cs,
            kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault);
        // GL pixels are RGBA — kCGImageAlphaNoneSkipLast treats byte 3 as skip (close enough)
        // and byte order default = RGBA on ARM = correct channel mapping
        if (tmpCtx) {
            CGImageRef img = CGBitmapContextCreateImage(tmpCtx);
            if (img) {
                // Canvas has Y-flip transform (translate+scale from creation).
                // Undo it so CGContextDrawImage doesn't flip the already-correct pixels.
                CGContextSaveGState(ctx);
                CGContextTranslateCTM(ctx, 0, canvasH);
                CGContextScaleCTM(ctx, 1.0, -1.0);
                CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
                CGContextDrawImage(ctx, CGRectMake(0, 0, canvasW, canvasH), img);
                CGContextRestoreGState(ctx);
                CGImageRelease(img);
            }
            CGContextRelease(tmpCtx);
        }
        CGColorSpaceRelease(cs);
    }

    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// mc3dReadCanvasPixels — read CGBitmapContext pixels as RGBA for GL
// ============================================================
// Canvas CGBitmapContext is BGRA (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little).
// GL needs RGBA. This method converts and flips Y (Canvas is top-down, GL is bottom-up).

static s32 n_mc3dReadCanvasPixels(Runtime *runtime, JClass *clazz) {
    s64 ctxHandle = ENV->localvar_getLong_2slot(runtime->localvar, 0);
    s64 dstAddr   = ENV->localvar_getLong_2slot(runtime->localvar, 2);
    s32 w = ENV->localvar_getInt(runtime->localvar, 4);
    s32 h = ENV->localvar_getInt(runtime->localvar, 5);

    if (!ctxHandle || !dstAddr) return RUNTIME_STATUS_NORMAL;

    CGContextRef *ctxPtr = (CGContextRef *)(intptr_t)ctxHandle;
    CGContextRef ctx = *ctxPtr;
    if (!ctx) return RUNTIME_STATUS_NORMAL;

    uint8_t *canvasPixels = (uint8_t *)CGBitmapContextGetData(ctx);
    size_t canvasW = CGBitmapContextGetWidth(ctx);
    size_t canvasH = CGBitmapContextGetHeight(ctx);
    size_t canvasBPR = CGBitmapContextGetBytesPerRow(ctx);

    if (!canvasPixels) return RUNTIME_STATUS_NORMAL;

    uint8_t *dst = (uint8_t *)(intptr_t)dstAddr;
    int copyW = (w < (int)canvasW) ? w : (int)canvasW;
    int copyH = (h < (int)canvasH) ? h : (int)canvasH;

    // Convert BGRA → RGBA, NO Y-flip (MascotCapsule uses inverted projection)
    for (int y = 0; y < copyH; y++) {
        uint8_t *src = canvasPixels + y * canvasBPR;
        uint8_t *dstRow = dst + y * copyW * 4;
        for (int x = 0; x < copyW; x++) {
            dstRow[0] = src[2]; // R (from Canvas offset 2)
            dstRow[1] = src[1]; // G
            dstRow[2] = src[0]; // B
            dstRow[3] = src[3]; // A
            src += 4;
            dstRow += 4;
        }
    }

    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Utils native methods (fillBuffer, transform)
// ============================================================

// fillBuffer(long bufAddr, int bufLen, long vertAddr, int vertLen, int[] indices)
static s32 n_fillBuffer(Runtime *runtime, JClass *clazz) {
    s64 bufAddr   = ENV->localvar_getLong_2slot(runtime->localvar, 0);
    s32 bufLen    = ENV->localvar_getInt(runtime->localvar, 2);
    s64 vertAddr  = ENV->localvar_getLong_2slot(runtime->localvar, 3);
    s32 vertLen   = ENV->localvar_getInt(runtime->localvar, 5);
    Instance *idxInst = (Instance *)ENV->localvar_getRefer(runtime->localvar, 6);

    if (!bufAddr || !vertAddr || !idxInst) return RUNTIME_STATUS_NORMAL;

    float *bufPtr = (float *)(intptr_t)bufAddr;
    float *vertPtr = (float *)(intptr_t)vertAddr;
    s32 *idxPtr = (s32 *)idxInst->arr_body;
    s32 idxLen = idxInst->arr_length;

    // Bounds check: bufPtr needs idxLen*3 floats, vertPtr accessed at idx*3+2
    if (idxLen * 3 > bufLen) {
        printf("[micro3d] fillBuffer: idxLen*3=%d > bufLen=%d, clamping\n", idxLen*3, bufLen);
        idxLen = bufLen / 3;
    }

    for (int i = 0; i < idxLen; i++) {
        int idx = idxPtr[i] * 3;
        if (idx >= 0 && idx + 2 < vertLen) {
            *bufPtr++ = vertPtr[idx];
            *bufPtr++ = vertPtr[idx + 1];
            *bufPtr++ = vertPtr[idx + 2];
        } else {
            // OOB index: write zeros (degenerate vertex) to maintain vertex order
            *bufPtr++ = 0.0f;
            *bufPtr++ = 0.0f;
            *bufPtr++ = 0.0f;
        }
    }
    return RUNTIME_STATUS_NORMAL;
}

// Skeletal transform
typedef struct { float m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23; } MC3DMat;
typedef struct { float x, y, z; } MC3DVec;
typedef struct { MC3DMat matrix; s32 parent; s32 length; } MC3DBone;

// transform(long srcVertAddr, long dstVertAddr, long srcNormAddr, long dstNormAddr, long bonesAddr, int bonesLen, float[] actionMatrices)
static s32 n_transform(Runtime *runtime, JClass *clazz) {
    s64 srcVertAddr = ENV->localvar_getLong_2slot(runtime->localvar, 0);
    s64 dstVertAddr = ENV->localvar_getLong_2slot(runtime->localvar, 2);
    s64 srcNormAddr = ENV->localvar_getLong_2slot(runtime->localvar, 4);
    s64 dstNormAddr = ENV->localvar_getLong_2slot(runtime->localvar, 6);
    s64 bonesAddr   = ENV->localvar_getLong_2slot(runtime->localvar, 8);
    s32 bonesCount  = ENV->localvar_getInt(runtime->localvar, 10);
    Instance *actionsInst = (Instance *)ENV->localvar_getRefer(runtime->localvar, 11);

    if (!srcVertAddr || !dstVertAddr || !bonesAddr || bonesCount <= 0) return RUNTIME_STATUS_NORMAL;

    MC3DVec *srcVert = (MC3DVec *)(intptr_t)srcVertAddr;
    MC3DVec *dstVert = (MC3DVec *)(intptr_t)dstVertAddr;
    MC3DVec *srcNorm = srcNormAddr ? (MC3DVec *)(intptr_t)srcNormAddr : NULL;
    MC3DVec *dstNorm = dstNormAddr ? (MC3DVec *)(intptr_t)dstNormAddr : NULL;
    float *actions = actionsInst ? (float *)actionsInst->arr_body : NULL;
    s32 actionsLen = actionsInst ? actionsInst->arr_length / 12 : 0;

    // Bone data in ByteBuffer: 12 floats (matrix) + 2 ints (parent, length) = 14 words = 56 bytes per bone
    // Read bones manually to avoid struct padding issues
    uint8_t *boneData = (uint8_t *)(intptr_t)bonesAddr;
    s64 bonesLen = bonesCount;

    MC3DMat *tmp = malloc(sizeof(MC3DMat) * bonesLen);
    // Bone layout in ByteBuffer (from Loader.java):
    //   offset 0:  int vertexCount   (putInt)
    //   offset 4:  int parent        (putInt)
    //   offset 8:  12 floats matrix  (putFloat x12)
    // = (2 + 12) * 4 = 56 bytes per bone
    #define BONE_STRIDE 56
    for (int i = 0; i < bonesLen; i++) {
        int32_t *bi = (int32_t *)(boneData + i * BONE_STRIDE);     // ints at offset 0
        float *bf = (float *)(boneData + i * BONE_STRIDE + 8);     // matrix at offset 8
        int32_t boneVertCount = bi[0];
        int32_t parent = bi[1];
        MC3DMat r;
        memcpy(&r, bf, sizeof(MC3DMat));

        MC3DMat *mat = &tmp[i];
        if (parent == -1) {
            *mat = r;
        } else {
            if (parent < 0 || parent >= i) {
                // Invalid parent — use identity-like to avoid crash
                *mat = r;
            } else {
                MC3DMat *p = &tmp[parent];
                mat->m00 = p->m00*r.m00 + p->m01*r.m10 + p->m02*r.m20;
                mat->m01 = p->m00*r.m01 + p->m01*r.m11 + p->m02*r.m21;
                mat->m02 = p->m00*r.m02 + p->m01*r.m12 + p->m02*r.m22;
                mat->m03 = p->m00*r.m03 + p->m01*r.m13 + p->m02*r.m23 + p->m03;
                mat->m10 = p->m10*r.m00 + p->m11*r.m10 + p->m12*r.m20;
                mat->m11 = p->m10*r.m01 + p->m11*r.m11 + p->m12*r.m21;
                mat->m12 = p->m10*r.m02 + p->m11*r.m12 + p->m12*r.m22;
                mat->m13 = p->m10*r.m03 + p->m11*r.m13 + p->m12*r.m23 + p->m13;
                mat->m20 = p->m20*r.m00 + p->m21*r.m10 + p->m22*r.m20;
                mat->m21 = p->m20*r.m01 + p->m21*r.m11 + p->m22*r.m21;
                mat->m22 = p->m20*r.m02 + p->m21*r.m12 + p->m22*r.m22;
                mat->m23 = p->m20*r.m03 + p->m21*r.m13 + p->m22*r.m23 + p->m23;
            }
        }
        if (i < actionsLen && actions) {
            MC3DMat *a = (MC3DMat *)(actions + i * 12);
            MC3DMat result;
            result.m00 = mat->m00*a->m00 + mat->m01*a->m10 + mat->m02*a->m20;
            result.m01 = mat->m00*a->m01 + mat->m01*a->m11 + mat->m02*a->m21;
            result.m02 = mat->m00*a->m02 + mat->m01*a->m12 + mat->m02*a->m22;
            result.m03 = mat->m00*a->m03 + mat->m01*a->m13 + mat->m02*a->m23 + mat->m03;
            result.m10 = mat->m10*a->m00 + mat->m11*a->m10 + mat->m12*a->m20;
            result.m11 = mat->m10*a->m01 + mat->m11*a->m11 + mat->m12*a->m21;
            result.m12 = mat->m10*a->m02 + mat->m11*a->m12 + mat->m12*a->m22;
            result.m13 = mat->m10*a->m03 + mat->m11*a->m13 + mat->m12*a->m23 + mat->m13;
            result.m20 = mat->m20*a->m00 + mat->m21*a->m10 + mat->m22*a->m20;
            result.m21 = mat->m20*a->m01 + mat->m21*a->m11 + mat->m22*a->m21;
            result.m22 = mat->m20*a->m02 + mat->m21*a->m12 + mat->m22*a->m22;
            result.m23 = mat->m20*a->m03 + mat->m21*a->m13 + mat->m22*a->m23 + mat->m23;
            *mat = result;
        }
        for (int j = 0; j < boneVertCount; j++) {
            float x = srcVert->x, y = srcVert->y, z = srcVert->z;
            dstVert->x = x * mat->m00 + y * mat->m01 + z * mat->m02 + mat->m03;
            dstVert->y = x * mat->m10 + y * mat->m11 + z * mat->m12 + mat->m13;
            dstVert->z = x * mat->m20 + y * mat->m21 + z * mat->m22 + mat->m23;
            srcVert++;
            dstVert++;
            if (srcNorm && dstNorm) {
                float nx = srcNorm->x, ny = srcNorm->y, nz = srcNorm->z;
                dstNorm->x = nx * mat->m00 + ny * mat->m01 + nz * mat->m02;
                dstNorm->y = nx * mat->m10 + ny * mat->m11 + nz * mat->m12;
                dstNorm->z = nx * mat->m20 + ny * mat->m21 + nz * mat->m22;
                srcNorm++;
                dstNorm++;
            }
        }
    }
    free(tmp);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Native method registration table
// ============================================================

static java_native_method mc3d_methods[] = {
    // Context management
    {GLES20_CLS, "mc3dInit",    "(II)V",  n_mc3dInit},
    {GLES20_CLS, "mc3dBind",    "()V",    n_mc3dBind},
    {GLES20_CLS, "mc3dRelease", "()V",    n_mc3dRelease},
    {GLES20_CLS, "mc3dDestroy", "()V",    n_mc3dDestroy},
    {GLES20_CLS, "mc3dResize",  "(II)V",  n_mc3dResize},

    // GL State
    {GLES20_CLS, "glEnable",     "(I)V",    n_glEnable},
    {GLES20_CLS, "glDisable",    "(I)V",    n_glDisable},
    {GLES20_CLS, "glViewport",   "(IIII)V", n_glViewport},
    {GLES20_CLS, "glScissor",    "(IIII)V", n_glScissor},
    {GLES20_CLS, "glClearColor", "(FFFF)V", n_glClearColor},
    {GLES20_CLS, "glClear",      "(I)V",    n_glClear},
    {GLES20_CLS, "glDepthMask",  "(Z)V",    n_glDepthMask},
    {GLES20_CLS, "glDepthFunc",  "(I)V",    n_glDepthFunc},
    {GLES20_CLS, "glGetError",   "()I",     n_glGetError},
    {GLES20_CLS, "glFlush",      "()V",     n_glFlush},

    // Blend
    {GLES20_CLS, "glBlendFunc",          "(II)V",   n_glBlendFunc},
    {GLES20_CLS, "glBlendFuncSeparate",  "(IIII)V", n_glBlendFuncSeparate},
    {GLES20_CLS, "glBlendEquation",      "(I)V",    n_glBlendEquation},
    {GLES20_CLS, "glBlendColor",         "(FFFF)V", n_glBlendColor},
    {GLES20_CLS, "glCullFace",           "(I)V",    n_glCullFace},
    {GLES20_CLS, "glFrontFace",          "(I)V",    n_glFrontFace},

    // Shaders
    {GLES20_CLS, "glCreateShader",       "(I)I",                            n_glCreateShader},
    {GLES20_CLS, "glShaderSource",       "(ILjava/lang/String;)V",          n_glShaderSource},
    {GLES20_CLS, "glCompileShader",      "(I)V",                            n_glCompileShader},
    {GLES20_CLS, "glGetShaderiv",        "(II[II)V",                        n_glGetShaderiv},
    {GLES20_CLS, "glGetShaderInfoLog",   "(I)Ljava/lang/String;",           n_glGetShaderInfoLog},
    {GLES20_CLS, "glDeleteShader",       "(I)V",                            n_glDeleteShader},

    // Programs
    {GLES20_CLS, "glCreateProgram",       "()I",                            n_glCreateProgram},
    {GLES20_CLS, "glAttachShader",        "(II)V",                          n_glAttachShader},
    {GLES20_CLS, "glDetachShader",        "(II)V",                          n_glDetachShader},
    {GLES20_CLS, "glLinkProgram",         "(I)V",                           n_glLinkProgram},
    {GLES20_CLS, "glGetProgramiv",        "(II[II)V",                       n_glGetProgramiv},
    {GLES20_CLS, "glGetProgramInfoLog",   "(I)Ljava/lang/String;",          n_glGetProgramInfoLog},
    {GLES20_CLS, "glUseProgram",          "(I)V",                           n_glUseProgram},
    {GLES20_CLS, "glDeleteProgram",       "(I)V",                           n_glDeleteProgram},
    {GLES20_CLS, "glReleaseShaderCompiler", "()V",                          n_glReleaseShaderCompiler},

    // Attributes
    {GLES20_CLS, "glGetAttribLocation",        "(ILjava/lang/String;)I",    n_glGetAttribLocation},
    {GLES20_CLS, "glEnableVertexAttribArray",   "(I)V",                     n_glEnableVertexAttribArray},
    {GLES20_CLS, "glDisableVertexAttribArray",  "(I)V",                     n_glDisableVertexAttribArray},
    {GLES20_CLS, "glVertexAttribPointer",       "(IIIZII)V",                n_glVertexAttribPointer},
    {GLES20_CLS, "glVertexAttribPointerAddr",    "(IIIZIJ)V",                 n_glVertexAttribPointerAddr},

    // Uniforms
    {GLES20_CLS, "glGetUniformLocation",  "(ILjava/lang/String;)I",         n_glGetUniformLocation},
    {GLES20_CLS, "glUniform1i",           "(II)V",                          n_glUniform1i},
    {GLES20_CLS, "glUniform1f",           "(IF)V",                          n_glUniform1f},
    {GLES20_CLS, "glUniform2f",           "(IFF)V",                         n_glUniform2f},
    {GLES20_CLS, "glUniform3f",           "(IFFF)V",                        n_glUniform3f},
    {GLES20_CLS, "glUniform3fvAddr",      "(IIJ)V",                         n_glUniform3fvAddr},
    {GLES20_CLS, "glUniformMatrix4fv",    "(IIZ[FI)V",                      n_glUniformMatrix4fv},

    // Textures
    {GLES20_CLS, "glGenTextures",    "(I[II)V",                             n_glGenTextures},
    {GLES20_CLS, "glDeleteTextures", "(I[II)V",                             n_glDeleteTextures},
    {GLES20_CLS, "glBindTexture",    "(II)V",                               n_glBindTexture},
    {GLES20_CLS, "glActiveTexture",  "(I)V",                                n_glActiveTexture},
    {GLES20_CLS, "glTexParameteri",  "(III)V",                              n_glTexParameteri},
    {GLES20_CLS, "glIsTexture",      "(I)Z",                                n_glIsTexture},
    {GLES20_CLS, "glTexImage2DAddr", "(IIIIIIIIJ)V",                        n_glTexImage2DAddr},

    // Buffers
    {GLES20_CLS, "glGenBuffers",     "(I[II)V",                             n_glGenBuffers},
    {GLES20_CLS, "glDeleteBuffers",  "(I[II)V",                             n_glDeleteBuffers},
    {GLES20_CLS, "glBindBuffer",     "(II)V",                               n_glBindBuffer},
    {GLES20_CLS, "glBufferDataAddr", "(IIJI)V",                             n_glBufferDataAddr},

    // Draw
    {GLES20_CLS, "glDrawArrays",    "(III)V",                               n_glDrawArrays},

    // Read
    {GLES20_CLS, "glReadPixelsAddr", "(IIIIIIJ)V",                          n_glReadPixelsAddr},

    // Utils native methods
    {UTILS_CLS,  "fillBuffer",   "(JIJI[I)V",                                         n_fillBuffer},
    {UTILS_CLS,  "transform",    "(JJJJJI[F)V",                                     n_transform},

    // Blit to Graphics
    {BRIDGE_CLS, "mc3dBlitToGraphics",    "(JJII)V",                         n_mc3dBlitToGraphics},
    {BRIDGE_CLS, "mc3dReadCanvasPixels", "(JJII)V",                         n_mc3dReadCanvasPixels},
};

void j2me_micro3d_gl_reg_natives(MiniJVM *jvm) {
    s32 count = sizeof(mc3d_methods) / sizeof(java_native_method);
    native_reg_lib(jvm, mc3d_methods, count);
    printf("[micro3d] Registered %d native methods (GLES20 + Utils)\n", count);
}

void j2me_micro3d_gl_cleanup(void) {
    if (g_mc3d_context) {
        [EAGLContext setCurrentContext:g_mc3d_context];
        if (g_mc3d_fbo) {
            glDeleteFramebuffers(1, &g_mc3d_fbo);
            g_mc3d_fbo = 0;
        }
        if (g_mc3d_colorRB) { glDeleteRenderbuffers(1, &g_mc3d_colorRB); g_mc3d_colorRB = 0; }
        if (g_mc3d_depthRB) { glDeleteRenderbuffers(1, &g_mc3d_depthRB); g_mc3d_depthRB = 0; }
        [EAGLContext setCurrentContext:nil];
        g_mc3d_context = nil;
        g_mc3d_prev_context = nil;
        g_mc3d_width = 0;
        g_mc3d_height = 0;
        printf("[micro3d] GL context cleaned up\n");
    }
}
