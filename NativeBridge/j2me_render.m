//
// j2me_render.m — Core Graphics rendering bridge for J2ME LCDUI
//
// Maps J2ME Graphics operations to iOS Core Graphics (CGContext).
// Analogous to J2ME-Loader's mapping of Graphics → Android Canvas (Skia).
//

#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <ImageIO/ImageIO.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#include "j2me_render.h"
#include "jvm.h"
#include "jvm_util.h"
#include <stdio.h>
#include <stdatomic.h>

// ============================================================
// Internal structures
// ============================================================
// Thread safety is provided by three complementary mechanisms:
//
// 1. Refcounting (rc_acquire/rc_release, img_acquire/img_release):
//    Prevents use-after-free of CF resources. GC finalize() releases
//    the owner reference; struct stays alive while native code uses it.
//
// 2. paintLock (Java synchronized in Canvas.doPaint/flushBuffer/destroyContext):
//    Prevents concurrent CGContext access on the same Canvas.
//    CGContext is NOT thread-safe; concurrent Save/RestoreGState corrupts it.
//
// 3. Two-generation deferred shell free (process_dead_shells):
//    When refcount reaches 0, CF resources are released immediately but
//    the struct shell is kept for one frame to prevent ABA in acquire.

typedef struct RenderContext {
    CGContextRef ctx;
    int width;
    int height;
    CTFontRef font;
    float fontSize;
    int fontStyle;
    int clipSaved;
    int ownsPixels;
    int32_t refcount;
    struct RenderContext *next_dead;
} RenderContext;

typedef struct RenderImage {
    CGContextRef ctx;
    int width;
    int height;
    int isMutable;
    int32_t refcount;
    struct RenderImage *next_dead;
} RenderImage;

static j2me_flush_callback g_flush_callback = NULL;
static CGColorSpaceRef g_colorSpace = NULL;

// Set by jvm_bridge before native cleanup. All acquire functions
// check this and return NULL, so zombie threads can't touch freed resources.
static volatile int g_render_stopped = 0;

// Global tracking arrays for forced cleanup between game sessions.
// Protected by g_track_lock. Entries are added on create, removed on release (refcount→0).
#define TRACK_MAX 8192
static RenderContext *g_live_rc[TRACK_MAX];
static int            g_live_rc_count = 0;
static RenderImage   *g_live_img[TRACK_MAX];
static int            g_live_img_count = 0;
static spinlock_t     g_track_lock = {0, 0, 0};

static void track_rc(RenderContext *rc) {
    spin_lock(&g_track_lock);
    if (g_live_rc_count < TRACK_MAX) g_live_rc[g_live_rc_count++] = rc;
    spin_unlock(&g_track_lock);
}
static void untrack_rc(RenderContext *rc) {
    spin_lock(&g_track_lock);
    for (int i = 0; i < g_live_rc_count; i++) {
        if (g_live_rc[i] == rc) {
            g_live_rc[i] = g_live_rc[--g_live_rc_count];
            break;
        }
    }
    spin_unlock(&g_track_lock);
}
static void track_img(RenderImage *img) {
    spin_lock(&g_track_lock);
    if (g_live_img_count < TRACK_MAX) g_live_img[g_live_img_count++] = img;
    spin_unlock(&g_track_lock);
}
static void untrack_img(RenderImage *img) {
    spin_lock(&g_track_lock);
    for (int i = 0; i < g_live_img_count; i++) {
        if (g_live_img[i] == img) {
            g_live_img[i] = g_live_img[--g_live_img_count];
            break;
        }
    }
    spin_unlock(&g_track_lock);
}

// ============================================================
// Native memory counter — visible to miniJVM GC via gc_sum_heap()
// ============================================================
extern s64 g_native_extra_heap;

static inline void native_heap_add(s32 bytes) {
    __atomic_fetch_add(&g_native_extra_heap, (s64)bytes, __ATOMIC_RELAXED);
}
static inline void native_heap_sub(s32 bytes) {
    __atomic_fetch_sub(&g_native_extra_heap, (s64)bytes, __ATOMIC_RELAXED);
}

// ============================================================
// Dead shell reclamation (two-generation)
// ============================================================
// When refcount reaches 0, CF resources are released immediately but
// the struct shell is kept alive (ABA prevention). Dead shells are
// pushed onto gen0 (atomic, any thread). Each flushToScreen call:
//   1. free(gen1) — shells dead for 1+ frames, safe to free
//   2. gen1 = gen0; gen0 = NULL — promote current to previous
// This bounds the leak to at most 2 frames' worth of shells.

static RenderContext * g_dead_rc_gen0 = NULL;
static RenderContext            *g_dead_rc_gen1 = NULL;
static RenderImage *   g_dead_img_gen0 = NULL;
static RenderImage              *g_dead_img_gen1 = NULL;

static void enqueue_dead_rc(RenderContext *rc) {
    RenderContext *old;
    do {
        old = atomic_load_explicit(&g_dead_rc_gen0, memory_order_relaxed);
        rc->next_dead = old;
    } while (!atomic_compare_exchange_weak_explicit(
        &g_dead_rc_gen0, &old, rc,
        memory_order_release, memory_order_relaxed));
}

static void enqueue_dead_img(RenderImage *img) {
    RenderImage *old;
    do {
        old = atomic_load_explicit(&g_dead_img_gen0, memory_order_relaxed);
        img->next_dead = old;
    } while (!atomic_compare_exchange_weak_explicit(
        &g_dead_img_gen0, &old, img,
        memory_order_release, memory_order_relaxed));
}

static void process_dead_shells(void) {
    // Free gen1 (dead for 1+ frames — all in-flight acquires have completed)
    RenderContext *rc = g_dead_rc_gen1;
    while (rc) { RenderContext *next = rc->next_dead; free(rc); rc = next; }
    RenderImage *img = g_dead_img_gen1;
    while (img) { RenderImage *next = img->next_dead; free(img); img = next; }
    // Promote gen0 → gen1
    g_dead_rc_gen1 = atomic_exchange_explicit(&g_dead_rc_gen0, NULL, memory_order_acquire);
    g_dead_img_gen1 = atomic_exchange_explicit(&g_dead_img_gen0, NULL, memory_order_acquire);
}

// ============================================================
// Reference counting: acquire / release
// ============================================================

static inline RenderContext *rc_acquire(s64 handle) {
    if (g_render_stopped || handle == 0) return NULL;
    RenderContext *rc = (RenderContext *)(intptr_t)handle;
    int32_t old = atomic_load_explicit(&rc->refcount, memory_order_relaxed);
    do {
        if (old <= 0) return NULL;
    } while (!atomic_compare_exchange_weak_explicit(
        &rc->refcount, &old, old + 1,
        memory_order_acquire, memory_order_relaxed));
    return rc;
}

static inline void rc_release(RenderContext *rc) {
    if (!rc) return;
    if (atomic_fetch_sub_explicit(&rc->refcount, 1, memory_order_release) == 1) {
        atomic_thread_fence(memory_order_acquire);
        untrack_rc(rc); // remove from live tracking before freeing resources
        int pixels = rc->ownsPixels ? rc->width * rc->height * 4 : 0;
        CGContextRef ctx = rc->ctx;
        CTFontRef font = __atomic_exchange_n(&rc->font, NULL, __ATOMIC_ACQ_REL);
        rc->ctx = NULL;
        rc->ownsPixels = 0;
        if (ctx) CGContextRelease(ctx);
        if (font) CFRelease(font);
        if (pixels > 0) native_heap_sub(pixels);
        enqueue_dead_rc(rc);
    }
}

static inline RenderImage *img_acquire(s64 handle) {
    if (g_render_stopped || handle == 0) return NULL;
    RenderImage *img = (RenderImage *)(intptr_t)handle;
    int32_t old = atomic_load_explicit(&img->refcount, memory_order_relaxed);
    do {
        if (old <= 0) return NULL;
    } while (!atomic_compare_exchange_weak_explicit(
        &img->refcount, &old, old + 1,
        memory_order_acquire, memory_order_relaxed));
    return img;
}

static inline void img_release(RenderImage *img) {
    if (!img) return;
    if (atomic_fetch_sub_explicit(&img->refcount, 1, memory_order_release) == 1) {
        atomic_thread_fence(memory_order_acquire);
        untrack_img(img); // remove from live tracking before freeing resources
        int pixels = img->width * img->height * 4;
        CGContextRef ctx = img->ctx;
        img->ctx = NULL;
        if (ctx) CGContextRelease(ctx);
        if (pixels > 0) native_heap_sub(pixels);
        enqueue_dead_img(img);
    }
}

// ============================================================

static CGColorSpaceRef getColorSpace(void) {
    if (!g_colorSpace) {
        g_colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    return g_colorSpace;
}

void j2me_render_set_flush_callback(j2me_flush_callback callback) {
    g_flush_callback = callback;
}

// ============================================================
// Helper
// ============================================================

static inline void setColorFromARGB(CGContextRef ctx, int argb) {
    CGFloat a = ((argb >> 24) & 0xFF) / 255.0;
    CGFloat r = ((argb >> 16) & 0xFF) / 255.0;
    CGFloat g = ((argb >> 8) & 0xFF) / 255.0;
    CGFloat b = (argb & 0xFF) / 255.0;
    CGContextSetRGBFillColor(ctx, r, g, b, a);
    CGContextSetRGBStrokeColor(ctx, r, g, b, a);
}

// ============================================================
// Context management
// ============================================================

static RenderContext *createRenderContext(int width, int height) {
    fprintf(stderr,"[i2ME render] Allocating context %dx%d\n",width,height);
    RenderContext *rc = (RenderContext *)calloc(1, sizeof(RenderContext));
    atomic_init(&rc->refcount, 1);
    rc->width = width;
    rc->height = height;

    CGColorSpaceRef cs = getColorSpace();
    fprintf(stderr,"[i2ME render] Color space ready\n");
    rc->ctx = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                                     cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    fprintf(stderr,"[i2ME render] Bitmap context=%p\n",rc->ctx);
    if(!rc->ctx){free(rc);return NULL;}
    CGContextTranslateCTM(rc->ctx, 0, height);
    CGContextScaleCTM(rc->ctx, 1.0, -1.0);

    CGContextSetLineWidth(rc->ctx, 1.0);
    CGContextSetLineCap(rc->ctx, kCGLineCapSquare);
    CGContextSetLineJoin(rc->ctx, kCGLineJoinMiter);

    rc->fontSize = 14.0;
    rc->fontStyle = 0;
    rc->font = CTFontCreateWithName(CFSTR("Helvetica"), rc->fontSize, NULL);
    fprintf(stderr,"[i2ME render] Font ready\n");
    rc->ownsPixels = 1;

    track_rc(rc);
    fprintf(stderr,"[i2ME render] Context tracked\n");
    native_heap_add(width * height * 4);
    fprintf(stderr,"[i2ME render] Context ready\n");
    return rc;
}

static void destroyRenderContext(RenderContext *rc) {
    if (!rc) return;
    rc_release(rc);
}

// ============================================================
// Image management
// ============================================================

static RenderImage *createMutableImage(int width, int height) {
    RenderImage *img = (RenderImage *)calloc(1, sizeof(RenderImage));
    atomic_init(&img->refcount, 1);
    img->width = width;
    img->height = height;
    img->isMutable = 1;

    CGColorSpaceRef cs = getColorSpace();
    img->ctx = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                                      cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGContextClearRect(img->ctx, CGRectMake(0, 0, width, height));
    CGContextTranslateCTM(img->ctx, 0, height);
    CGContextScaleCTM(img->ctx, 1.0, -1.0);

    track_img(img);
    native_heap_add(width * height * 4);
    return img;
}

static RenderImage *createImageFromData(const uint8_t *data, int length) {
    RenderImage *img = (RenderImage *)calloc(1, sizeof(RenderImage));
    atomic_init(&img->refcount, 1);
    img->isMutable = 0;

    CFDataRef cfData = CFDataCreate(NULL, data, length);
    CGImageSourceRef source = CGImageSourceCreateWithData(cfData, NULL);
    CFRelease(cfData);

    CGImageRef cgImage = NULL;
    if (source) {
        cgImage = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFRelease(source);
    }

    if (!cgImage) {
        free(img);
        return NULL;
    }

    img->width = (int)CGImageGetWidth(cgImage);
    img->height = (int)CGImageGetHeight(cgImage);

    CGColorSpaceRef cs = getColorSpace();
    img->ctx = CGBitmapContextCreate(NULL, img->width, img->height, 8, img->width * 4,
                                      cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGContextClearRect(img->ctx, CGRectMake(0, 0, img->width, img->height));
    CGContextDrawImage(img->ctx, CGRectMake(0, 0, img->width, img->height), cgImage);
    CGImageRelease(cgImage);


    track_img(img);
    native_heap_add(img->width * img->height * 4);
    return img;
}

static void destroyImage(RenderImage *img) {
    if (!img) return;
    img_release(img);
}

// ============================================================
// Native method implementations
// ============================================================

static s32 n_createContext(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s32 w = env->localvar_getInt(runtime->localvar, 0);
    s32 h = env->localvar_getInt(runtime->localvar, 1);
    RenderContext *rc = createRenderContext(w, h);
    env->push_long(runtime->stack, (s64)(intptr_t)rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_destroyContext(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    if (g_render_stopped || handle == 0) return RUNTIME_STATUS_NORMAL;
    destroyRenderContext((RenderContext *)(intptr_t)handle);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_flushToScreen(Runtime *runtime, JClass *clazz) {
    process_dead_shells();

    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    RenderContext *rc = rc_acquire(handle);
    if (rc && g_flush_callback) {
        CGImageRef image = CGBitmapContextCreateImage(rc->ctx);
        g_flush_callback(image, rc->width, rc->height);
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

// --- Color & State ---

static s32 n_setColor(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 argb = env->localvar_getInt(runtime->localvar, 2);
    RenderContext *rc = rc_acquire(handle);
    if (rc) setColorFromARGB(rc->ctx, argb);
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_setClip(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 x = env->localvar_getInt(runtime->localvar, 2);
    s32 y = env->localvar_getInt(runtime->localvar, 3);
    s32 w = env->localvar_getInt(runtime->localvar, 4);
    s32 h = env->localvar_getInt(runtime->localvar, 5);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        if (rc->clipSaved) {
            CGContextRestoreGState(rc->ctx);
        }
        CGContextSaveGState(rc->ctx);
        rc->clipSaved = 1;
        CGContextClipToRect(rc->ctx, CGRectMake(x, y, w, h));
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_setStrokeStyle(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 style = env->localvar_getInt(runtime->localvar, 2);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        if (style == 1) {
            CGFloat dash[] = {2.0, 2.0};
            CGContextSetLineDash(rc->ctx, 0, dash, 2);
        } else {
            CGContextSetLineDash(rc->ctx, 0, NULL, 0);
        }
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

// --- Drawing ---

static s32 n_drawLine(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 x1 = env->localvar_getInt(runtime->localvar, 2);
    s32 y1 = env->localvar_getInt(runtime->localvar, 3);
    s32 x2 = env->localvar_getInt(runtime->localvar, 4);
    s32 y2 = env->localvar_getInt(runtime->localvar, 5);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        CGContextBeginPath(rc->ctx);
        CGContextMoveToPoint(rc->ctx, x1 + 0.5, y1 + 0.5);
        CGContextAddLineToPoint(rc->ctx, x2 + 0.5, y2 + 0.5);
        CGContextStrokePath(rc->ctx);
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_fillRect(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 x = env->localvar_getInt(runtime->localvar, 2);
    s32 y = env->localvar_getInt(runtime->localvar, 3);
    s32 w = env->localvar_getInt(runtime->localvar, 4);
    s32 h = env->localvar_getInt(runtime->localvar, 5);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        CGContextFillRect(rc->ctx, CGRectMake(x, y, w, h));
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_drawRect(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 x = env->localvar_getInt(runtime->localvar, 2);
    s32 y = env->localvar_getInt(runtime->localvar, 3);
    s32 w = env->localvar_getInt(runtime->localvar, 4);
    s32 h = env->localvar_getInt(runtime->localvar, 5);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        CGContextStrokeRect(rc->ctx, CGRectMake(x + 0.5, y + 0.5, w, h));
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_fillArc(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 x = env->localvar_getInt(runtime->localvar, 2);
    s32 y = env->localvar_getInt(runtime->localvar, 3);
    s32 w = env->localvar_getInt(runtime->localvar, 4);
    s32 h = env->localvar_getInt(runtime->localvar, 5);
    s32 startAngle = env->localvar_getInt(runtime->localvar, 6);
    s32 arcAngle = env->localvar_getInt(runtime->localvar, 7);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        CGFloat cx = x + w / 2.0, cy = y + h / 2.0;
        CGFloat rx = w / 2.0, ry = h / 2.0;
        CGContextSaveGState(rc->ctx);
        CGContextTranslateCTM(rc->ctx, cx, cy);
        CGContextScaleCTM(rc->ctx, 1.0, ry / rx);
        CGContextBeginPath(rc->ctx);
        CGContextMoveToPoint(rc->ctx, 0, 0);
        CGFloat sa = -startAngle * M_PI / 180.0;
        CGFloat ea = -(startAngle + arcAngle) * M_PI / 180.0;
        CGContextAddArc(rc->ctx, 0, 0, rx, sa, ea, arcAngle > 0 ? 1 : 0);
        CGContextClosePath(rc->ctx);
        CGContextFillPath(rc->ctx);
        CGContextRestoreGState(rc->ctx);
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_drawArc(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 x = env->localvar_getInt(runtime->localvar, 2);
    s32 y = env->localvar_getInt(runtime->localvar, 3);
    s32 w = env->localvar_getInt(runtime->localvar, 4);
    s32 h = env->localvar_getInt(runtime->localvar, 5);
    s32 startAngle = env->localvar_getInt(runtime->localvar, 6);
    s32 arcAngle = env->localvar_getInt(runtime->localvar, 7);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        CGFloat cx = x + w / 2.0, cy = y + h / 2.0;
        CGFloat rx = w / 2.0, ry = h / 2.0;
        CGContextSaveGState(rc->ctx);
        CGContextTranslateCTM(rc->ctx, cx, cy);
        CGContextScaleCTM(rc->ctx, 1.0, ry / rx);
        CGContextBeginPath(rc->ctx);
        CGFloat sa = -startAngle * M_PI / 180.0;
        CGFloat ea = -(startAngle + arcAngle) * M_PI / 180.0;
        CGContextAddArc(rc->ctx, 0, 0, rx, sa, ea, arcAngle > 0 ? 1 : 0);
        CGContextStrokePath(rc->ctx);
        CGContextRestoreGState(rc->ctx);
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_fillRoundRect(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 x = env->localvar_getInt(runtime->localvar, 2);
    s32 y = env->localvar_getInt(runtime->localvar, 3);
    s32 w = env->localvar_getInt(runtime->localvar, 4);
    s32 h = env->localvar_getInt(runtime->localvar, 5);
    s32 aw = env->localvar_getInt(runtime->localvar, 6);
    s32 ah = env->localvar_getInt(runtime->localvar, 7);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        CGFloat radius = fmin(aw, ah) / 2.0;
        CGPathRef path = CGPathCreateWithRoundedRect(CGRectMake(x, y, w, h), radius, radius, NULL);
        CGContextAddPath(rc->ctx, path);
        CGContextFillPath(rc->ctx);
        CGPathRelease(path);
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_drawRoundRect(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 x = env->localvar_getInt(runtime->localvar, 2);
    s32 y = env->localvar_getInt(runtime->localvar, 3);
    s32 w = env->localvar_getInt(runtime->localvar, 4);
    s32 h = env->localvar_getInt(runtime->localvar, 5);
    s32 aw = env->localvar_getInt(runtime->localvar, 6);
    s32 ah = env->localvar_getInt(runtime->localvar, 7);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        CGFloat radius = fmin(aw, ah) / 2.0;
        CGPathRef path = CGPathCreateWithRoundedRect(CGRectMake(x + 0.5, y + 0.5, w, h), radius, radius, NULL);
        CGContextAddPath(rc->ctx, path);
        CGContextStrokePath(rc->ctx);
        CGPathRelease(path);
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

// --- Text ---

static s32 n_setFont(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 face = env->localvar_getInt(runtime->localvar, 2);
    s32 style = env->localvar_getInt(runtime->localvar, 3);
    s32 size = env->localvar_getInt(runtime->localvar, 4);
    RenderContext *rc = rc_acquire(handle);
    if (rc) {
        CGFloat ptSize;
        switch (size) {
            case 8:  ptSize = 10.0; break;
            case 0:  ptSize = 14.0; break;
            case 16: ptSize = 18.0; break;
            default: ptSize = 14.0; break;
        }

        CFStringRef fontName;
        if (style & 1) {
            if (style & 2) fontName = CFSTR("Helvetica-BoldOblique");
            else fontName = CFSTR("Helvetica-Bold");
        } else if (style & 2) {
            fontName = CFSTR("Helvetica-Oblique");
        } else {
            if (face == 32) fontName = CFSTR("Courier");
            else fontName = CFSTR("Helvetica");
        }

        CTFontRef newFont = CTFontCreateWithName(fontName, ptSize, NULL);
        CTFontRef oldFont = __atomic_exchange_n(&rc->font, newFont, __ATOMIC_ACQ_REL);
        rc->fontSize = ptSize;
        rc->fontStyle = style;
        if (oldFont) CFRelease(oldFont);
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_drawString(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    Instance *jstr = env->localvar_getRefer(runtime->localvar, 2);
    s32 x = env->localvar_getInt(runtime->localvar, 3);
    s32 y = env->localvar_getInt(runtime->localvar, 4);
    s32 anchor = env->localvar_getInt(runtime->localvar, 5);
    RenderContext *rc = rc_acquire(handle);

    if (!rc || !jstr) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }

    Utf8String *ustr = utf8_create();
    env->jstring_2_utf8(jstr, ustr, runtime);
    CFStringRef str = CFStringCreateWithCString(NULL, utf8_cstr(ustr), kCFStringEncodingUTF8);
    utf8_destroy(ustr);
    if (!str) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }

    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(NULL, 3,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attrs, kCTFontAttributeName, rc->font);
    CFDictionarySetValue(attrs, kCTForegroundColorFromContextAttributeName, kCFBooleanTrue);

    CFAttributedStringRef attrStr = CFAttributedStringCreate(NULL, str, attrs);
    CTLineRef line = CTLineCreateWithAttributedString(attrStr);

    CGFloat ascent, descent, leading;
    double textWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGFloat textHeight = ascent + descent;

    CGFloat dx = x, dy = y;
    if (anchor & 1) dx -= textWidth / 2;
    if (anchor & 8) dx -= textWidth;
    if (anchor & 4) dy -= 0;
    if (anchor & 32) dy -= textHeight;
    if (anchor == 0 || (anchor & 16)) dy += 0;

    CGContextSaveGState(rc->ctx);
    CGContextTranslateCTM(rc->ctx, dx, dy + ascent);
    CGContextScaleCTM(rc->ctx, 1.0, -1.0);
    CGContextSetTextPosition(rc->ctx, 0, 0);
    CTLineDraw(line, rc->ctx);
    CGContextRestoreGState(rc->ctx);

    CFRelease(line);
    CFRelease(attrStr);
    CFRelease(attrs);
    CFRelease(str);
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_getStringWidth(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    Instance *jstr = env->localvar_getRefer(runtime->localvar, 2);
    RenderContext *rc = rc_acquire(handle);

    if (!rc || !jstr) { rc_release(rc); env->push_int(runtime->stack, 0); return RUNTIME_STATUS_NORMAL; }

    Utf8String *ustr = utf8_create();
    env->jstring_2_utf8(jstr, ustr, runtime);
    CFStringRef str = CFStringCreateWithCString(NULL, utf8_cstr(ustr), kCFStringEncodingUTF8);
    utf8_destroy(ustr);
    if (!str) { rc_release(rc); env->push_int(runtime->stack, 0); return RUNTIME_STATUS_NORMAL; }

    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(NULL, 1,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attrs, kCTFontAttributeName, rc->font);
    CFAttributedStringRef attrStr = CFAttributedStringCreate(NULL, str, attrs);
    CTLineRef line = CTLineCreateWithAttributedString(attrStr);
    double w = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
    CFRelease(line); CFRelease(attrStr); CFRelease(attrs); CFRelease(str);
    rc_release(rc);
    env->push_int(runtime->stack, (s32)ceil(w));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_getFontHeight(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    RenderContext *rc = rc_acquire(handle);
    if (!rc) { env->push_int(runtime->stack, 14); return RUNTIME_STATUS_NORMAL; }
    CGFloat ascent = CTFontGetAscent(rc->font);
    CGFloat descent = CTFontGetDescent(rc->font);
    rc_release(rc);
    env->push_int(runtime->stack, (s32)ceil(ascent + descent));
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_getFontAscent(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    RenderContext *rc = rc_acquire(handle);
    if (!rc) { env->push_int(runtime->stack, 12); return RUNTIME_STATUS_NORMAL; }
    CGFloat ascent = CTFontGetAscent(rc->font);
    rc_release(rc);
    env->push_int(runtime->stack, (s32)ceil(ascent));
    return RUNTIME_STATUS_NORMAL;
}

// --- Image ---

static s32 n_createMutableImage(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s32 w = env->localvar_getInt(runtime->localvar, 0);
    s32 h = env->localvar_getInt(runtime->localvar, 1);
    RenderImage *img = createMutableImage(w, h);
    env->push_long(runtime->stack, (s64)(intptr_t)img);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_createImageFromData(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *arr = env->localvar_getRefer(runtime->localvar, 0);
    s32 offset = env->localvar_getInt(runtime->localvar, 1);
    s32 length = env->localvar_getInt(runtime->localvar, 2);
    if (!arr) { env->push_long(runtime->stack, 0); return RUNTIME_STATUS_NORMAL; }
    c8 *arrBody = arr->arr_body;
    RenderImage *img = createImageFromData((uint8_t *)arrBody + offset, length);
    env->push_long(runtime->stack, (s64)(intptr_t)img);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_destroyImage(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    if (g_render_stopped || handle == 0) return RUNTIME_STATUS_NORMAL;
    destroyImage((RenderImage *)(intptr_t)handle);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_getImageWidth(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    RenderImage *img = img_acquire(handle);
    env->push_int(runtime->stack, img ? img->width : 0);
    img_release(img);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_getImageHeight(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    RenderImage *img = img_acquire(handle);
    env->push_int(runtime->stack, img ? img->height : 0);
    img_release(img);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_getImageContext(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    RenderImage *img = img_acquire(handle);
    if (img && img->isMutable && img->ctx) {
        RenderContext *rc = (RenderContext *)calloc(1, sizeof(RenderContext));
        atomic_init(&rc->refcount, 1);
        rc->ctx = img->ctx;
        CGContextRetain(rc->ctx);
        rc->width = img->width;
        rc->height = img->height;
        rc->fontSize = 14.0;
        rc->font = CTFontCreateWithName(CFSTR("Helvetica"), 14.0, NULL);
        rc->ownsPixels = 0; // pixels owned by the RenderImage, not this wrapper
        track_rc(rc);
        img_release(img);
        env->push_long(runtime->stack, (s64)(intptr_t)rc);
    } else {
        img_release(img);
        env->push_long(runtime->stack, 0);
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_drawImage(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 ctxHandle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s64 imgHandle = env->localvar_getLong_2slot(runtime->localvar, 2);
    s32 x = env->localvar_getInt(runtime->localvar, 4);
    s32 y = env->localvar_getInt(runtime->localvar, 5);
    s32 anchor = env->localvar_getInt(runtime->localvar, 6);

    RenderContext *rc = rc_acquire(ctxHandle);
    RenderImage *img = img_acquire(imgHandle);
    if (!rc || !img) { img_release(img); rc_release(rc); return RUNTIME_STATUS_NORMAL; }

    int imgW = img->width, imgH = img->height;
    if (anchor & 1) x -= imgW / 2;
    if (anchor & 8) x -= imgW;
    if (anchor & 2) y -= imgH / 2;
    if (anchor & 32) y -= imgH;

    CGImageRef cgImage = CGBitmapContextCreateImage(img->ctx);
    if (cgImage) {
        CGContextSaveGState(rc->ctx);
        CGContextTranslateCTM(rc->ctx, x, y + imgH);
        CGContextScaleCTM(rc->ctx, 1.0, -1.0);
        CGContextDrawImage(rc->ctx, CGRectMake(0, 0, imgW, imgH), cgImage);
        CGContextRestoreGState(rc->ctx);
        CGImageRelease(cgImage);
    }
    img_release(img);
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

// --- drawRegion ---

#define TRANS_NONE           0
#define TRANS_ROT90          5
#define TRANS_ROT180         3
#define TRANS_ROT270         6
#define TRANS_MIRROR         2
#define TRANS_MIRROR_ROT90   7
#define TRANS_MIRROR_ROT180  1
#define TRANS_MIRROR_ROT270  4

static s32 n_drawRegion(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 ctxHandle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s64 imgHandle = env->localvar_getLong_2slot(runtime->localvar, 2);
    s32 xSrc = env->localvar_getInt(runtime->localvar, 4);
    s32 ySrc = env->localvar_getInt(runtime->localvar, 5);
    s32 wSrc = env->localvar_getInt(runtime->localvar, 6);
    s32 hSrc = env->localvar_getInt(runtime->localvar, 7);
    s32 transform = env->localvar_getInt(runtime->localvar, 8);
    s32 xDst = env->localvar_getInt(runtime->localvar, 9);
    s32 yDst = env->localvar_getInt(runtime->localvar, 10);
    s32 anchor = env->localvar_getInt(runtime->localvar, 11);

    RenderContext *rc = rc_acquire(ctxHandle);
    RenderImage *img = img_acquire(imgHandle);
    if (!rc || !img) { img_release(img); rc_release(rc); return RUNTIME_STATUS_NORMAL; }
    CGContextRef rctx = rc->ctx;
    CGContextRef ictx = img->ctx;

    int outW = wSrc, outH = hSrc;
    if (transform == TRANS_ROT90 || transform == TRANS_ROT270 ||
        transform == TRANS_MIRROR_ROT90 || transform == TRANS_MIRROR_ROT270) {
        outW = hSrc; outH = wSrc;
    }

    if (anchor & 1) xDst -= outW / 2;
    if (anchor & 8) xDst -= outW;
    if (anchor & 2) yDst -= outH / 2;
    if (anchor & 32) yDst -= outH;

    CGImageRef fullImage = CGBitmapContextCreateImage(ictx);
    if (!fullImage) { img_release(img); rc_release(rc); return RUNTIME_STATUS_NORMAL; }
    CGImageRef subImage = CGImageCreateWithImageInRect(fullImage, CGRectMake(xSrc, ySrc, wSrc, hSrc));
    CGImageRelease(fullImage);
    if (!subImage) { img_release(img); rc_release(rc); return RUNTIME_STATUS_NORMAL; }

    CGContextSaveGState(rctx);
    CGContextTranslateCTM(rctx, xDst, yDst);

    /* CTM transforms for J2ME drawRegion on a bottom-up CGContext.
     *
     * CGContextDrawImage maps source pixel (sx, sy) to draw-rect position
     * (sx, hSrc - sy) because CG draws top of image at higher Y.
     * We need the final CG position to match the J2ME output position.
     *
     * For each J2ME transform T, source pixel (sx, sy) should appear at
     * J2ME output position T(sx, sy) offset by (xDst, yDst).
     * The CTM must satisfy: CTM * (sx, hSrc-sy) = desired CG position.
     *
     * All operations below are relative to the initial translate(xDst, yDst). */
    switch (transform) {
        case TRANS_NONE:
            CGContextTranslateCTM(rctx, 0, hSrc);
            CGContextScaleCTM(rctx, 1, -1);
            break;
        case TRANS_MIRROR_ROT180: /* = vertical flip, cancels CG's Y-flip */
            break;
        case TRANS_MIRROR:
            CGContextTranslateCTM(rctx, wSrc, hSrc);
            CGContextScaleCTM(rctx, -1, -1);
            break;
        case TRANS_ROT180:
            CGContextTranslateCTM(rctx, wSrc, 0);
            CGContextScaleCTM(rctx, -1, 1);
            break;
        case TRANS_ROT90:
            CGContextRotateCTM(rctx, M_PI_2);
            CGContextScaleCTM(rctx, 1, -1);
            break;
        case TRANS_ROT270:
            CGContextTranslateCTM(rctx, hSrc, wSrc);
            CGContextRotateCTM(rctx, -M_PI_2);
            CGContextScaleCTM(rctx, 1, -1);
            break;
        case TRANS_MIRROR_ROT90:
            CGContextTranslateCTM(rctx, 0, wSrc);
            CGContextRotateCTM(rctx, -M_PI_2);
            break;
        case TRANS_MIRROR_ROT270:
            CGContextTranslateCTM(rctx, hSrc, 0);
            CGContextRotateCTM(rctx, M_PI_2);
            break;
    }

    CGContextDrawImage(rctx, CGRectMake(0, 0, wSrc, hSrc), subImage);
    CGContextRestoreGState(rctx);
    CGImageRelease(subImage);
    img_release(img);
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

// --- drawRGB ---

static s32 n_drawRGB(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 ctxHandle = env->localvar_getLong_2slot(runtime->localvar, 0);
    Instance *arr = env->localvar_getRefer(runtime->localvar, 2);
    s32 offset = env->localvar_getInt(runtime->localvar, 3);
    s32 scanlength = env->localvar_getInt(runtime->localvar, 4);
    s32 x = env->localvar_getInt(runtime->localvar, 5);
    s32 y = env->localvar_getInt(runtime->localvar, 6);
    s32 w = env->localvar_getInt(runtime->localvar, 7);
    s32 h = env->localvar_getInt(runtime->localvar, 8);
    s32 processAlpha = env->localvar_getInt(runtime->localvar, 9);

    RenderContext *rc = rc_acquire(ctxHandle);
    if (!rc || !arr || w <= 0 || h <= 0) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }

    s32 arrLen = arr->arr_length;
    s32 *srcData = (s32 *)arr->arr_body;
    CGColorSpaceRef cs = getColorSpace();
    CGContextRef tmpCtx = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    if (!tmpCtx) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }

    uint8_t *dst = (uint8_t *)CGBitmapContextGetData(tmpCtx);
    for (int row = 0; row < h; row++) {
        for (int col = 0; col < w; col++) {
            int srcIdx = offset + row * scanlength + col;
            if (srcIdx < 0 || srcIdx >= arrLen) continue;
            s32 argb = srcData[srcIdx];
            int dstIdx = (row * w + col) * 4;
            uint8_t a = processAlpha ? ((argb >> 24) & 0xFF) : 0xFF;
            uint8_t r = (argb >> 16) & 0xFF;
            uint8_t g = (argb >> 8) & 0xFF;
            uint8_t b = argb & 0xFF;
            if (a < 255 && a > 0) {
                r = (uint8_t)(r * a / 255);
                g = (uint8_t)(g * a / 255);
                b = (uint8_t)(b * a / 255);
            } else if (a == 0) {
                r = g = b = 0;
            }
            dst[dstIdx + 0] = b;
            dst[dstIdx + 1] = g;
            dst[dstIdx + 2] = r;
            dst[dstIdx + 3] = a;
        }
    }

    CGImageRef img = CGBitmapContextCreateImage(tmpCtx);
    CGContextRelease(tmpCtx);

    if (img) {
        CGContextSaveGState(rc->ctx);
        CGContextTranslateCTM(rc->ctx, x, y + h);
        CGContextScaleCTM(rc->ctx, 1, -1);
        CGContextDrawImage(rc->ctx, CGRectMake(0, 0, w, h), img);
        CGContextRestoreGState(rc->ctx);
        CGImageRelease(img);
    }
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

// --- getImageRGB ---

static s32 n_getImageRGB(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 imgHandle = env->localvar_getLong_2slot(runtime->localvar, 0);
    Instance *arr = env->localvar_getRefer(runtime->localvar, 2);
    s32 offset = env->localvar_getInt(runtime->localvar, 3);
    s32 scanlength = env->localvar_getInt(runtime->localvar, 4);
    s32 x = env->localvar_getInt(runtime->localvar, 5);
    s32 y = env->localvar_getInt(runtime->localvar, 6);
    s32 w = env->localvar_getInt(runtime->localvar, 7);
    s32 h = env->localvar_getInt(runtime->localvar, 8);

    RenderImage *img = img_acquire(imgHandle);
    if (!img || !arr) { img_release(img); return RUNTIME_STATUS_NORMAL; }

    s32 *dstData = (s32 *)arr->arr_body;
    uint8_t *srcData = (uint8_t *)CGBitmapContextGetData(img->ctx);
    int imgW = img->width;

    for (int row = 0; row < h; row++) {
        for (int col = 0; col < w; col++) {
            int srcIdx = ((y + row) * imgW + (x + col)) * 4;
            uint8_t b = srcData[srcIdx + 0];
            uint8_t g = srcData[srcIdx + 1];
            uint8_t r = srcData[srcIdx + 2];
            uint8_t a = srcData[srcIdx + 3];
            s32 argb = (a << 24) | (r << 16) | (g << 8) | b;
            dstData[offset + row * scanlength + col] = argb;
        }
    }
    img_release(img);
    return RUNTIME_STATUS_NORMAL;
}

// --- fillPolygon / drawPolygon ---

static s32 n_fillPolygon(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    Instance *xArr = env->localvar_getRefer(runtime->localvar, 2);
    Instance *yArr = env->localvar_getRefer(runtime->localvar, 3);
    s32 nPoints = env->localvar_getInt(runtime->localvar, 4);
    RenderContext *rc = rc_acquire(handle);
    if (!rc || !xArr || !yArr || nPoints < 3) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }
    s32 *xPts = (s32 *)xArr->arr_body;
    s32 *yPts = (s32 *)yArr->arr_body;
    CGContextBeginPath(rc->ctx);
    CGContextMoveToPoint(rc->ctx, xPts[0], yPts[0]);
    for (int i = 1; i < nPoints; i++) {
        CGContextAddLineToPoint(rc->ctx, xPts[i], yPts[i]);
    }
    CGContextClosePath(rc->ctx);
    CGContextFillPath(rc->ctx);
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_drawPolygon(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    Instance *xArr = env->localvar_getRefer(runtime->localvar, 2);
    Instance *yArr = env->localvar_getRefer(runtime->localvar, 3);
    s32 nPoints = env->localvar_getInt(runtime->localvar, 4);
    RenderContext *rc = rc_acquire(handle);
    if (!rc || !xArr || !yArr || nPoints < 3) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }
    s32 *xPts = (s32 *)xArr->arr_body;
    s32 *yPts = (s32 *)yArr->arr_body;
    CGContextBeginPath(rc->ctx);
    CGContextMoveToPoint(rc->ctx, xPts[0] + 0.5, yPts[0] + 0.5);
    for (int i = 1; i < nPoints; i++) {
        CGContextAddLineToPoint(rc->ctx, xPts[i] + 0.5, yPts[i] + 0.5);
    }
    CGContextClosePath(rc->ctx);
    CGContextStrokePath(rc->ctx);
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

// --- copyArea ---

static s32 n_copyArea(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 xSrc = env->localvar_getInt(runtime->localvar, 2);
    s32 ySrc = env->localvar_getInt(runtime->localvar, 3);
    s32 w = env->localvar_getInt(runtime->localvar, 4);
    s32 h = env->localvar_getInt(runtime->localvar, 5);
    s32 xDst = env->localvar_getInt(runtime->localvar, 6);
    s32 yDst = env->localvar_getInt(runtime->localvar, 7);
    RenderContext *rc = rc_acquire(handle);
    if (!rc || w <= 0 || h <= 0) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }
    CGImageRef fullImg = CGBitmapContextCreateImage(rc->ctx);
    if (!fullImg) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }
    CGImageRef subImg = CGImageCreateWithImageInRect(fullImg, CGRectMake(xSrc, ySrc, w, h));
    CGImageRelease(fullImg);
    if (!subImg) { rc_release(rc); return RUNTIME_STATUS_NORMAL; }
    CGContextSaveGState(rc->ctx);
    CGContextTranslateCTM(rc->ctx, xDst, yDst + h);
    CGContextScaleCTM(rc->ctx, 1, -1);
    CGContextDrawImage(rc->ctx, CGRectMake(0, 0, w, h), subImg);
    CGContextRestoreGState(rc->ctx);
    CGImageRelease(subImg);
    rc_release(rc);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Native method table
// ============================================================
// Haptics
// ============================================================

static s32 n_vibrate(Runtime *runtime, JClass *clazz) {
    s32 duration = runtime->jnienv->localvar_getInt(runtime->localvar, 0);
    if (duration > 0) AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    return RUNTIME_STATUS_NORMAL;
}

#define CLS "javax/microedition/lcdui/NativeBridge"

static java_native_method j2me_render_methods[] = {
    // Context
    {CLS, "createContext",    "(II)J",                                   n_createContext},
    {CLS, "destroyContext",   "(J)V",                                    n_destroyContext},
    {CLS, "flushToScreen",    "(J)V",                                    n_flushToScreen},

    // Color & State
    {CLS, "setColor",         "(JI)V",                                   n_setColor},
    {CLS, "setClip",          "(JIIII)V",                                n_setClip},
    {CLS, "setStrokeStyle",   "(JI)V",                                   n_setStrokeStyle},

    // Drawing
    {CLS, "drawLine",         "(JIIII)V",                                n_drawLine},
    {CLS, "fillRect",         "(JIIII)V",                                n_fillRect},
    {CLS, "drawRect",         "(JIIII)V",                                n_drawRect},
    {CLS, "fillArc",          "(JIIIIII)V",                              n_fillArc},
    {CLS, "drawArc",          "(JIIIIII)V",                              n_drawArc},
    {CLS, "fillRoundRect",    "(JIIIIII)V",                              n_fillRoundRect},
    {CLS, "drawRoundRect",    "(JIIIIII)V",                              n_drawRoundRect},

    // Text
    {CLS, "setFont",          "(JIII)V",                                 n_setFont},
    {CLS, "drawString",       "(JLjava/lang/String;III)V",               n_drawString},
    {CLS, "getStringWidth",   "(JLjava/lang/String;)I",                  n_getStringWidth},
    {CLS, "getFontHeight",    "(J)I",                                    n_getFontHeight},
    {CLS, "getFontAscent",    "(J)I",                                    n_getFontAscent},

    // Image
    {CLS, "createMutableImage",  "(II)J",                                n_createMutableImage},
    {CLS, "createImageFromData", "([BII)J",                              n_createImageFromData},
    {CLS, "destroyImage",        "(J)V",                                 n_destroyImage},
    {CLS, "getImageWidth",       "(J)I",                                 n_getImageWidth},
    {CLS, "getImageHeight",      "(J)I",                                 n_getImageHeight},
    {CLS, "getImageContext",     "(J)J",                                 n_getImageContext},
    {CLS, "drawImage",           "(JJIII)V",                             n_drawImage},
    {CLS, "drawRegion",          "(JJIIIIIIII)V",                        n_drawRegion},
    {CLS, "drawRGB",             "(J[IIIIIIII)V",                        n_drawRGB},
    {CLS, "getImageRGB",         "(J[IIIIIII)V",                         n_getImageRGB},
    {CLS, "fillPolygon",         "(J[I[II)V",                            n_fillPolygon},
    {CLS, "drawPolygon",         "(J[I[II)V",                            n_drawPolygon},
    {CLS, "copyArea",            "(JIIIIII)V",                           n_copyArea},

    // Haptics
    {CLS, "vibrate",             "(I)V",                                 n_vibrate},
};

#undef CLS

void j2me_render_reg_natives(MiniJVM *jvm) {
    native_reg_lib(jvm, j2me_render_methods,
                   sizeof(j2me_render_methods) / sizeof(java_native_method));
    printf("[J2ME Render] Registered %lu native methods\n",
           sizeof(j2me_render_methods) / sizeof(java_native_method));
}

void j2me_render_stop(void) {
    g_render_stopped = 1;
}

void j2me_render_cleanup(void) {
    // g_render_stopped must already be set (via j2me_render_stop).
    // Two passes needed: first frees gen1 and promotes gen0→gen1,
    // second frees promoted gen1 (was gen0). After both, all dead shells are freed.
    process_dead_shells();
    process_dead_shells();

    // Force-release all still-live RenderContexts (never destroyed by Java).
    // These are guaranteed valid: untrack_rc removed freed ones from the array.
    spin_lock(&g_track_lock);
    int rc_count = g_live_rc_count;
    for (int i = 0; i < g_live_rc_count; i++) {
        RenderContext *rc = g_live_rc[i];
        if (rc->ctx) { CGContextRelease(rc->ctx); rc->ctx = NULL; }
        CTFontRef font = rc->font;
        rc->font = NULL;
        if (font) CFRelease(font);
        free(rc);
    }
    g_live_rc_count = 0;

    // Force-release all still-live RenderImages
    int img_count = g_live_img_count;
    for (int i = 0; i < g_live_img_count; i++) {
        RenderImage *img = g_live_img[i];
        if (img->ctx) { CGContextRelease(img->ctx); img->ctx = NULL; }
        free(img);
    }
    g_live_img_count = 0;
    spin_unlock(&g_track_lock);

    // Clear dead queues
    atomic_store_explicit(&g_dead_rc_gen0, NULL, memory_order_relaxed);
    g_dead_rc_gen1 = NULL;
    atomic_store_explicit(&g_dead_img_gen0, NULL, memory_order_relaxed);
    g_dead_img_gen1 = NULL;

    // Reset native heap counter
    __atomic_store_n(&g_native_extra_heap, 0, __ATOMIC_RELAXED);

    g_render_stopped = 0; // ready for next game session
    printf("[J2ME Render] Cleanup: %d contexts, %d images released\n", rc_count, img_count);
}
