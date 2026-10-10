//
// j2me_ui.m — Native UI bridge for J2ME LCDUI Forms/Lists/Alerts
//
// Java classes serialize their state via sequential native calls.
// Native side accumulates data and creates UIKit views on main thread.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "j2me_ui.h"
#include "j2me_input.h"
#include "jvm.h"
#include "jvm_util.h"
#include <stdio.h>

// ============================================================
// Form builder state — accumulated by Java calls, flushed on show
// ============================================================

#define MAX_FORM_ITEMS 64
#define MAX_COMMANDS 8

typedef struct {
    int type;           // 0=string, 1=textfield, 2=choice, 3=image, 4=spacer, 5=gauge
    char label[256];
    char text[1024];
    int intParam1;      // appearance/maxSize/choiceType
    int intParam2;      // constraints
} FormItem;

typedef struct {
    char label[128];
    int type;           // Command.SCREEN, BACK, OK, EXIT, etc.
    int priority;
    int id;             // sequential ID for event matching
} FormCommand;

static char g_form_title[256] = "";
static FormItem g_form_items[MAX_FORM_ITEMS];
static int g_form_item_count = 0;
static FormCommand g_form_commands[MAX_COMMANDS];
static int g_form_command_count = 0;
static int g_form_type = 0; // 0=form, 1=list, 2=alert, 3=textbox

// List items
static char g_list_items[MAX_FORM_ITEMS][256];
static int g_list_item_count = 0;
static int g_list_type = 0; // IMPLICIT=3, EXCLUSIVE=1, MULTIPLE=2

// Alert
static char g_alert_text[1024] = "";
static int g_alert_timeout = -2; // FOREVER

static j2me_ui_callback g_ui_callback = NULL;

void j2me_ui_set_callback(j2me_ui_callback callback) {
    g_ui_callback = callback;
}

// ============================================================
// Public getters for Swift side
// ============================================================

const char *j2me_ui_get_form_title(void) { return g_form_title; }
int j2me_ui_get_form_item_count(void) { return g_form_item_count; }
int j2me_ui_get_form_item_type(int index) { return index < g_form_item_count ? g_form_items[index].type : -1; }
const char *j2me_ui_get_form_item_label(int index) { return index < g_form_item_count ? g_form_items[index].label : ""; }
const char *j2me_ui_get_form_item_text(int index) { return index < g_form_item_count ? g_form_items[index].text : ""; }
int j2me_ui_get_form_item_param1(int index) { return index < g_form_item_count ? g_form_items[index].intParam1 : 0; }

int j2me_ui_get_command_count(void) { return g_form_command_count; }
const char *j2me_ui_get_command_label(int index) { return index < g_form_command_count ? g_form_commands[index].label : ""; }
int j2me_ui_get_command_type(int index) { return index < g_form_command_count ? g_form_commands[index].type : 0; }
int j2me_ui_get_command_id(int index) { return index < g_form_command_count ? g_form_commands[index].id : -1; }

int j2me_ui_get_list_item_count(void) { return g_list_item_count; }
const char *j2me_ui_get_list_item(int index) { return index < g_list_item_count ? g_list_items[index] : ""; }
int j2me_ui_get_list_type(void) { return g_list_type; }

const char *j2me_ui_get_alert_text(void) { return g_alert_text; }
int j2me_ui_get_alert_timeout(void) { return g_alert_timeout; }

// ============================================================
// Native methods — called from Java to build UI
// ============================================================

static s32 n_formBegin(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *jtitle = env->localvar_getRefer(runtime->localvar, 0);
    s32 type = env->localvar_getInt(runtime->localvar, 1);

    g_form_item_count = 0;
    g_form_command_count = 0;
    g_list_item_count = 0;
    g_form_type = type;

    if (jtitle) {
        Utf8String *ustr = utf8_create();
        env->jstring_2_utf8(jtitle, ustr, runtime);
        strncpy(g_form_title, utf8_cstr(ustr), sizeof(g_form_title) - 1);
        utf8_destroy(ustr);
    } else {
        g_form_title[0] = '\0';
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_formAddStringItem(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *jlabel = env->localvar_getRefer(runtime->localvar, 0);
    Instance *jtext = env->localvar_getRefer(runtime->localvar, 1);
    s32 appearance = env->localvar_getInt(runtime->localvar, 2);

    if (g_form_item_count >= MAX_FORM_ITEMS) return RUNTIME_STATUS_NORMAL;
    FormItem *item = &g_form_items[g_form_item_count++];
    item->type = 0; // string
    item->intParam1 = appearance;
    item->label[0] = '\0';
    item->text[0] = '\0';

    if (jlabel) {
        Utf8String *u = utf8_create();
        env->jstring_2_utf8(jlabel, u, runtime);
        strncpy(item->label, utf8_cstr(u), sizeof(item->label) - 1);
        utf8_destroy(u);
    }
    if (jtext) {
        Utf8String *u = utf8_create();
        env->jstring_2_utf8(jtext, u, runtime);
        strncpy(item->text, utf8_cstr(u), sizeof(item->text) - 1);
        utf8_destroy(u);
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_formAddTextField(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *jlabel = env->localvar_getRefer(runtime->localvar, 0);
    Instance *jtext = env->localvar_getRefer(runtime->localvar, 1);
    s32 maxSize = env->localvar_getInt(runtime->localvar, 2);
    s32 constraints = env->localvar_getInt(runtime->localvar, 3);

    if (g_form_item_count >= MAX_FORM_ITEMS) return RUNTIME_STATUS_NORMAL;
    FormItem *item = &g_form_items[g_form_item_count++];
    item->type = 1; // textfield
    item->intParam1 = maxSize;
    item->intParam2 = constraints;
    item->label[0] = '\0';
    item->text[0] = '\0';

    if (jlabel) {
        Utf8String *u = utf8_create();
        env->jstring_2_utf8(jlabel, u, runtime);
        strncpy(item->label, utf8_cstr(u), sizeof(item->label) - 1);
        utf8_destroy(u);
    }
    if (jtext) {
        Utf8String *u = utf8_create();
        env->jstring_2_utf8(jtext, u, runtime);
        strncpy(item->text, utf8_cstr(u), sizeof(item->text) - 1);
        utf8_destroy(u);
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_formAddCommand(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *jlabel = env->localvar_getRefer(runtime->localvar, 0);
    s32 cmdType = env->localvar_getInt(runtime->localvar, 1);
    s32 priority = env->localvar_getInt(runtime->localvar, 2);
    s32 cmdId = env->localvar_getInt(runtime->localvar, 3);

    if (g_form_command_count >= MAX_COMMANDS) return RUNTIME_STATUS_NORMAL;
    FormCommand *cmd = &g_form_commands[g_form_command_count++];
    cmd->type = cmdType;
    cmd->priority = priority;
    cmd->id = cmdId;
    cmd->label[0] = '\0';

    if (jlabel) {
        Utf8String *u = utf8_create();
        env->jstring_2_utf8(jlabel, u, runtime);
        strncpy(cmd->label, utf8_cstr(u), sizeof(cmd->label) - 1);
        utf8_destroy(u);
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_formShow(Runtime *runtime, JClass *clazz) {
    printf("[J2ME UI] formShow: type=%d title='%s' items=%d commands=%d\n",
           g_form_type, g_form_title, g_form_item_count, g_form_command_count);
    if (g_ui_callback) {
        int action;
        switch (g_form_type) {
            case 0: action = J2ME_UI_ACTION_SHOW_FORM; break;
            case 1: action = J2ME_UI_ACTION_SHOW_LIST; break;
            case 2: action = J2ME_UI_ACTION_SHOW_ALERT; break;
            case 3: action = J2ME_UI_ACTION_SHOW_TEXTBOX; break;
            default: action = J2ME_UI_ACTION_SHOW_FORM; break;
        }
        g_ui_callback(action, g_form_title);
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_showCanvas(Runtime *runtime, JClass *clazz) {
    printf("[J2ME UI] showCanvas\n");
    if (g_ui_callback) {
        g_ui_callback(J2ME_UI_ACTION_SHOW_CANVAS, NULL);
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_listAddItem(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *jtext = env->localvar_getRefer(runtime->localvar, 0);

    if (g_list_item_count >= MAX_FORM_ITEMS) return RUNTIME_STATUS_NORMAL;
    g_list_items[g_list_item_count][0] = '\0';
    if (jtext) {
        Utf8String *u = utf8_create();
        env->jstring_2_utf8(jtext, u, runtime);
        strncpy(g_list_items[g_list_item_count], utf8_cstr(u), 255);
        utf8_destroy(u);
    }
    g_list_item_count++;
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_setListType(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    g_list_type = env->localvar_getInt(runtime->localvar, 0);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_setAlertText(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *jtext = env->localvar_getRefer(runtime->localvar, 0);
    s32 timeout = env->localvar_getInt(runtime->localvar, 1);
    g_alert_timeout = timeout;
    g_alert_text[0] = '\0';
    if (jtext) {
        Utf8String *u = utf8_create();
        env->jstring_2_utf8(jtext, u, runtime);
        strncpy(g_alert_text, utf8_cstr(u), sizeof(g_alert_text) - 1);
        utf8_destroy(u);
    }
    return RUNTIME_STATUS_NORMAL;
}

// --- platformRequest: open URL in system browser ---

static s32 n_platformRequest(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *jurl = env->localvar_getRefer(runtime->localvar, 0);
    if (!jurl) return RUNTIME_STATUS_NORMAL;

    Utf8String *u = utf8_create();
    env->jstring_2_utf8(jurl, u, runtime);
    const char *urlStr = utf8_cstr(u);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:urlStr]];
        if (url) {
            [[UIApplication sharedApplication] openURL:url];
        }
    });

    utf8_destroy(u);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Native method table
// ============================================================

#define CLS "javax/microedition/lcdui/NativeBridge"

static java_native_method j2me_ui_methods[] = {
    {CLS, "formBegin",        "(Ljava/lang/String;I)V",                          n_formBegin},
    {CLS, "formAddStringItem","(Ljava/lang/String;Ljava/lang/String;I)V",        n_formAddStringItem},
    {CLS, "formAddTextField", "(Ljava/lang/String;Ljava/lang/String;II)V",       n_formAddTextField},
    {CLS, "formAddCommand",   "(Ljava/lang/String;III)V",                        n_formAddCommand},
    {CLS, "formShow",         "()V",                                             n_formShow},
    {CLS, "showCanvas",       "()V",                                             n_showCanvas},
    {CLS, "listAddItem",      "(Ljava/lang/String;)V",                           n_listAddItem},
    {CLS, "setListType",      "(I)V",                                            n_setListType},
    {CLS, "setAlertText",     "(Ljava/lang/String;I)V",                          n_setAlertText},
    {CLS, "platformRequest",  "(Ljava/lang/String;)V",                           n_platformRequest},
};

#undef CLS

void j2me_ui_reg_natives(MiniJVM *jvm) {
    native_reg_lib(jvm, j2me_ui_methods,
                   sizeof(j2me_ui_methods) / sizeof(java_native_method));
    printf("[J2ME UI] Registered %lu native methods\n",
           sizeof(j2me_ui_methods) / sizeof(java_native_method));
}
