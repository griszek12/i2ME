/*
 * JNI compatibility layer for miniJVM — allows M3G .inl files to compile
 * with minimal changes.
 *
 * Maps JNI types and macros to miniJVM equivalents.
 * The .inl files use standard JNI signatures; we redefine them here
 * so the same code works with our miniJVM native registration.
 *
 * Strategy: We do NOT use the .inl files directly. Instead we create
 * wrapper functions that extract parameters from miniJVM local vars
 * and call the m3g C engine functions directly. This file provides
 * the type definitions shared between the wrapper and registration code.
 */

#ifndef M3G_JNI_COMPAT_H
#define M3G_JNI_COMPAT_H

#include "jvm.h"
#include "jvm_util.h"
#include "m3g_core.h"
#include "m3g_defs.h"

/* miniJVM environment shortcut */
#define ENV (runtime->jnienv)

/* Helper: get local variable as specific type */
static inline s64 m3g_getlong(LocalVarItem *lv, int idx) {
    return lv[idx].lvalue;
}
static inline s32 m3g_getint(LocalVarItem *lv, int idx) {
    return lv[idx].ivalue;
}
static inline float m3g_getfloat(LocalVarItem *lv, int idx) {
    s32 bits = lv[idx].ivalue;
    float f;
    memcpy(&f, &bits, sizeof(float));
    return f;
}
static inline Instance* m3g_getref(LocalVarItem *lv, int idx) {
    return (Instance*)lv[idx].rvalue;
}

/* Array body access */
static inline void* m3g_arraybody(Instance *arr) {
    return arr ? arr->arr_body : NULL;
}
static inline s32 m3g_arraylen(Instance *arr) {
    return arr ? arr->arr_length : 0;
}

/* Push return values */
static inline void m3g_pushlong(RuntimeStack *stack, s64 val) {
    stack->sp->lvalue = val;
    stack->sp++;
}
static inline void m3g_pushint(RuntimeStack *stack, s32 val) {
    stack->sp->ivalue = val;
    stack->sp++;
}

#endif /* M3G_JNI_COMPAT_H */
