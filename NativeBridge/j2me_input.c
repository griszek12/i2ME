//
// j2me_input.c — Thread-safe input event bridge between iOS and miniJVM
//
// Uses a lock-free ring buffer for single-producer (iOS main thread)
// single-consumer (JVM thread) communication.
//

#include "j2me_input.h"
#include "jvm_bridge.h"
#include "jvm.h"
#include "jvm_util.h"
#include <stdio.h>
#include <stdatomic.h>

// ============================================================
// Ring buffer
// ============================================================

#define INPUT_QUEUE_SIZE 256
#define INPUT_QUEUE_MASK (INPUT_QUEUE_SIZE - 1)

typedef struct {
    int type;
    int x, y;
    int keyCode;
} InputEvent;

static InputEvent g_queue[INPUT_QUEUE_SIZE];
static atomic_int g_write_pos = 0;
static atomic_int g_read_pos = 0;

static int g_canvas_width = 240;
static int g_canvas_height = 320;

void j2me_input_set_canvas_size(int width, int height) {
    g_canvas_width = width;
    g_canvas_height = height;
}

static void enqueue_event(int type, int x, int y, int keyCode) {
    int wp = atomic_load_explicit(&g_write_pos, memory_order_relaxed);
    int next_wp = (wp + 1) & INPUT_QUEUE_MASK;
    int rp = atomic_load_explicit(&g_read_pos, memory_order_acquire);

    if (next_wp == rp) {
        // Queue full — drop event
        return;
    }

    g_queue[wp].type = type;
    g_queue[wp].x = x;
    g_queue[wp].y = y;
    g_queue[wp].keyCode = keyCode;

    atomic_store_explicit(&g_write_pos, next_wp, memory_order_release);
}

static int dequeue_event(InputEvent *out) {
    int rp = atomic_load_explicit(&g_read_pos, memory_order_relaxed);
    int wp = atomic_load_explicit(&g_write_pos, memory_order_acquire);

    if (rp == wp) {
        return 0; // Empty
    }

    *out = g_queue[rp];
    atomic_store_explicit(&g_read_pos, (rp + 1) & INPUT_QUEUE_MASK, memory_order_release);
    return 1;
}

// ============================================================
// Public API (called from Swift/main thread)
// ============================================================

void j2me_input_post_touch(int type, int x, int y) {
    enqueue_event(type, x, y, 0);
}

void j2me_input_post_key(int type, int keyCode) {
    enqueue_event(type, 0, 0, keyCode);
}

// ============================================================
// Native method: NativeBridge.pollInputEvent() → int[] or null
// Returns int[4]: {type, x, y, keyCode}
// ============================================================

static s32 n_pollInputEvent(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    InputEvent evt;

    if (!dequeue_event(&evt)) {
        env->push_ref(runtime->stack, NULL);
        return RUNTIME_STATUS_NORMAL;
    }

    // Create int[4] array
    Utf8String *type_name = utf8_create_c("[I");
    Instance *arr = jarray_create_by_type_index(runtime, 4, DATATYPE_INT);
    if (!arr) {
        utf8_destroy(type_name);
        env->push_ref(runtime->stack, NULL);
        return RUNTIME_STATUS_NORMAL;
    }
    utf8_destroy(type_name);

    // Fill array
    s32 *body = (s32 *)arr->arr_body;
    body[0] = evt.type;
    body[1] = evt.x;
    body[2] = evt.y;
    body[3] = evt.keyCode;

    env->push_ref(runtime->stack, arr);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Native method: NativeBridge.isStopRequested() → boolean
// ============================================================

static s32 n_isStopRequested(Runtime *runtime, JClass *clazz) {
    push_int(runtime->stack, jvm_bridge_is_stop_requested() ? 1 : 0);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Reset (call between game sessions)
// ============================================================

void j2me_input_reset(void) {
    atomic_store_explicit(&g_write_pos, 0, memory_order_relaxed);
    atomic_store_explicit(&g_read_pos, 0, memory_order_relaxed);
    printf("[J2ME Input] Ring buffer reset\n");
}

// ============================================================
// Native method table
// ============================================================

#define CLS "javax/microedition/lcdui/NativeBridge"

static java_native_method j2me_input_methods[] = {
    {CLS, "pollInputEvent", "()[I", n_pollInputEvent},
    {CLS, "isStopRequested", "()Z", n_isStopRequested},
};

#undef CLS

void j2me_input_reg_natives(MiniJVM *jvm) {
    native_reg_lib(jvm, j2me_input_methods,
                   sizeof(j2me_input_methods) / sizeof(java_native_method));
    printf("[J2ME Input] Registered %lu native methods\n",
           sizeof(j2me_input_methods) / sizeof(java_native_method));
}
