//
// j2me_audio.m — Audio bridge: AVAudioPlayer (WAV/MP3) + LegacyMIDIPlayer (MIDI)
//
// Maps J2ME media API to iOS AVFoundation.
// Analogous to J2ME-Loader's mapping to Android MediaPlayer + MidiDriver.
//

#import <AVFoundation/AVFoundation.h>
#import "LegacyMIDIPlayer.h"
#include "j2me_audio.h"
#include "jvm.h"
#include "jvm_util.h"
#include <stdio.h>

// ============================================================
// Audio session setup
// ============================================================

static void ensureAudioSession(void) {
    static BOOL initialized = NO;
    if (!initialized) {
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (error) {
            printf("[J2ME Audio] Audio session error: %s\n",
                   [[error localizedDescription] UTF8String]);
        }
        initialized = YES;
    }
}

// ============================================================
// SoundFont path for MIDI
// ============================================================

static NSURL *getSoundFontURL(void) {
    static NSURL *url = nil;
    if (!url) {
        // Try various subdirectory locations
        url = [[NSBundle mainBundle] URLForResource:@"gs_instruments" withExtension:@"sf2"];
        if (!url) {
            url = [[NSBundle mainBundle] URLForResource:@"gs_instruments" withExtension:@"sf2"
                                           subdirectory:@"sound_fonts"];
        }
        if (!url) {
            url = [[NSBundle mainBundle] URLForResource:@"gs_instruments" withExtension:@"sf2"
                                           subdirectory:@"Resources/sound_fonts"];
        }
        if (!url) {
            // Brute-force search
            NSString *path = [[NSBundle mainBundle] pathForResource:@"gs_instruments" ofType:@"sf2"];
            if (path) url = [NSURL fileURLWithPath:path];
        }
        if (!url) {
            printf("[J2ME Audio] WARNING: gs_instruments.sf2 not found in bundle!\n");
        }
    }
    return url;
}

// ============================================================
// Audio completion delegate
// ============================================================

// Event type for END_OF_MEDIA posted to input queue
#define J2ME_AUDIO_END_OF_MEDIA 13

@interface J2MEAudioDelegate : NSObject <AVAudioPlayerDelegate>
@end

@implementation J2MEAudioDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    // Post END_OF_MEDIA event to input queue
    j2me_input_post_key(J2ME_AUDIO_END_OF_MEDIA, 0);
}
@end

static J2MEAudioDelegate *g_audioDelegate = nil;

static J2MEAudioDelegate *getAudioDelegate(void) {
    if (!g_audioDelegate) {
        g_audioDelegate = [[J2MEAudioDelegate alloc] init];
    }
    return g_audioDelegate;
}

// ============================================================
// Active player tracking (for cleanup between game sessions)
// ============================================================

static NSMutableSet *g_active_audio_players = nil;
static NSMutableSet *g_active_midi_players = nil;

static void track_audio_player(AVAudioPlayer *player) {
    @synchronized ([AVAudioSession class]) {
        if (!g_active_audio_players) g_active_audio_players = [NSMutableSet new];
        [g_active_audio_players addObject:player];
    }
}

static void untrack_audio_player(AVAudioPlayer *player) {
    @synchronized ([AVAudioSession class]) {
        [g_active_audio_players removeObject:player];
    }
}

static void track_midi_player(LegacyMIDIPlayer *player) {
    @synchronized ([AVAudioSession class]) {
        if (!g_active_midi_players) g_active_midi_players = [NSMutableSet new];
        [g_active_midi_players addObject:player];
    }
}

static void untrack_midi_player(LegacyMIDIPlayer *player) {
    @synchronized ([AVAudioSession class]) {
        [g_active_midi_players removeObject:player];
    }
}

void j2me_audio_stop_all(void) {
    NSSet *midiSnapshot = nil;

    @synchronized ([AVAudioSession class]) {
        if (g_active_audio_players) {
            for (AVAudioPlayer *p in [g_active_audio_players copy]) {
                [p stop];
                CFRelease((__bridge CFTypeRef)p);
            }
            [g_active_audio_players removeAllObjects];
        }
        if (g_active_midi_players) {
            // Take a snapshot and clear the tracking set while holding the lock.
            // Actual stop+release of MIDI players must happen on the main thread
            // because LegacyMIDIPlayer's internal AUGraph asserts during dealloc if
            // the AudioUnit is still in a render callback on another thread.
            midiSnapshot = [g_active_midi_players copy];
            [g_active_midi_players removeAllObjects];
        }
    }

    if (midiSnapshot.count > 0) {
        if ([NSThread isMainThread]) {
            for (LegacyMIDIPlayer *p in midiSnapshot) {
                [p stop];
                CFRelease((__bridge CFTypeRef)p);
            }
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                for (LegacyMIDIPlayer *p in midiSnapshot) {
                    [p stop];
                    CFRelease((__bridge CFTypeRef)p);
                }
            });
        }
    }

    printf("[J2ME Audio] All players stopped and released\n");
}

// ============================================================
// WAV/MP3 — AVAudioPlayer
// ============================================================

static s32 n_audioCreatePlayer(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *arr = env->localvar_getRefer(runtime->localvar, 0);

    if (!arr) { env->push_long(runtime->stack, 0); return RUNTIME_STATUS_NORMAL; }

    ensureAudioSession();

    s32 length = arr->arr_length;
    NSData *data = [NSData dataWithBytes:arr->arr_body length:length];

    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error || !player) {
        printf("[J2ME Audio] AVAudioPlayer init error: %s\n",
               error ? [[error localizedDescription] UTF8String] : "nil");
        env->push_long(runtime->stack, 0);
        return RUNTIME_STATUS_NORMAL;
    }

    player.delegate = getAudioDelegate();
    [player prepareToPlay];
    // Prevent ARC from releasing — bridge retain
    CFRetain((__bridge CFTypeRef)player);
    track_audio_player(player);
    env->push_long(runtime->stack, (s64)(intptr_t)(__bridge void *)player);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioStart(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    if (handle) {
        AVAudioPlayer *player = (__bridge AVAudioPlayer *)(void *)(intptr_t)handle;
        [player play];
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioStop(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    if (handle) {
        AVAudioPlayer *player = (__bridge AVAudioPlayer *)(void *)(intptr_t)handle;
        [player pause];
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioClose(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    if (handle) {
        AVAudioPlayer *player = (__bridge AVAudioPlayer *)(void *)(intptr_t)handle;
        [player stop];
        untrack_audio_player(player);
        CFRelease((__bridge CFTypeRef)player);
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioSetLoop(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s32 count = env->localvar_getInt(runtime->localvar, 2);
    if (handle) {
        AVAudioPlayer *player = (__bridge AVAudioPlayer *)(void *)(intptr_t)handle;
        player.numberOfLoops = count; // -1 = infinite, 0 = play once
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioSetVolume(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    // float is passed as int bits in localvar slot 2
    s32 bits = env->localvar_getInt(runtime->localvar, 2);
    float volume;
    memcpy(&volume, &bits, sizeof(float));
    if (handle) {
        AVAudioPlayer *player = (__bridge AVAudioPlayer *)(void *)(intptr_t)handle;
        player.volume = volume;
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioGetDuration(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s64 duration = -1;
    if (handle) {
        AVAudioPlayer *player = (__bridge AVAudioPlayer *)(void *)(intptr_t)handle;
        duration = (s64)(player.duration * 1000000.0); // microseconds
    }
    env->push_long(runtime->stack, duration);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioGetTime(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    s64 time = 0;
    if (handle) {
        AVAudioPlayer *player = (__bridge AVAudioPlayer *)(void *)(intptr_t)handle;
        time = (s64)(player.currentTime * 1000000.0); // microseconds
    }
    env->push_long(runtime->stack, time);
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// MIDI — LegacyMIDIPlayer + gs_instruments.sf2
// ============================================================

static s32 n_audioCreateMidiPlayer(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    Instance *arr = env->localvar_getRefer(runtime->localvar, 0);

    if (!arr) { env->push_long(runtime->stack, 0); return RUNTIME_STATUS_NORMAL; }

    ensureAudioSession();

    s32 length = arr->arr_length;
    NSData *data = [NSData dataWithBytes:arr->arr_body length:length];
    NSURL *sfURL = getSoundFontURL();

    NSError *error = nil;
    LegacyMIDIPlayer *player = [[LegacyMIDIPlayer alloc] initWithData:data
                                                 soundBankURL:sfURL
                                                        error:&error];
    if (error || !player) {
        printf("[J2ME Audio] LegacyMIDIPlayer init error: %s\n",
               error ? [[error localizedDescription] UTF8String] : "nil");
        env->push_long(runtime->stack, 0);
        return RUNTIME_STATUS_NORMAL;
    }

    [player prepareToPlay];
    CFRetain((__bridge CFTypeRef)player);
    track_midi_player(player);
    env->push_long(runtime->stack, (s64)(intptr_t)(__bridge void *)player);
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioMidiStart(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    if (handle) {
        LegacyMIDIPlayer *player = (__bridge LegacyMIDIPlayer *)(void *)(intptr_t)handle;
        [player play:nil];
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioMidiStop(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    if (handle) {
        LegacyMIDIPlayer *player = (__bridge LegacyMIDIPlayer *)(void *)(intptr_t)handle;
        [player stop];
    }
    return RUNTIME_STATUS_NORMAL;
}

static s32 n_audioMidiClose(Runtime *runtime, JClass *clazz) {
    JniEnv *env = runtime->jnienv;
    s64 handle = env->localvar_getLong_2slot(runtime->localvar, 0);
    if (handle) {
        LegacyMIDIPlayer *player = (__bridge LegacyMIDIPlayer *)(void *)(intptr_t)handle;
        [player stop];
        untrack_midi_player(player);
        CFRelease((__bridge CFTypeRef)player);
    }
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Tone — convenience (not used directly, Java uses ToneManager)
// ============================================================

static s32 n_audioPlayTone(Runtime *runtime, JClass *clazz) {
    // This is a fallback — normally ToneManager handles playTone via TonePlayer
    JniEnv *env = runtime->jnienv;
    s32 note = env->localvar_getInt(runtime->localvar, 0);
    s32 duration = env->localvar_getInt(runtime->localvar, 1);
    s32 volume = env->localvar_getInt(runtime->localvar, 2);
    printf("[J2ME Audio] playTone: note=%d duration=%d volume=%d\n", note, duration, volume);
    // Tone is handled by Java ToneManager → ToneSequence → MIDI → LegacyMIDIPlayer
    return RUNTIME_STATUS_NORMAL;
}

// ============================================================
// Native method table
// ============================================================

#define CLS "javax/microedition/lcdui/NativeBridge"

static java_native_method j2me_audio_methods[] = {
    // WAV/MP3
    {CLS, "audioCreatePlayer",     "([B)J",   n_audioCreatePlayer},
    {CLS, "audioStart",            "(J)V",    n_audioStart},
    {CLS, "audioStop",             "(J)V",    n_audioStop},
    {CLS, "audioClose",            "(J)V",    n_audioClose},
    {CLS, "audioSetLoop",          "(JI)V",   n_audioSetLoop},
    {CLS, "audioSetVolume",        "(JF)V",   n_audioSetVolume},
    {CLS, "audioGetDuration",      "(J)J",    n_audioGetDuration},
    {CLS, "audioGetTime",          "(J)J",    n_audioGetTime},
    // MIDI
    {CLS, "audioCreateMidiPlayer", "([B)J",   n_audioCreateMidiPlayer},
    {CLS, "audioMidiStart",        "(J)V",    n_audioMidiStart},
    {CLS, "audioMidiStop",         "(J)V",    n_audioMidiStop},
    {CLS, "audioMidiClose",        "(J)V",    n_audioMidiClose},
    // Tone
    {CLS, "audioPlayTone",         "(III)V",  n_audioPlayTone},
};

#undef CLS

void j2me_audio_reg_natives(MiniJVM *jvm) {
    native_reg_lib(jvm, j2me_audio_methods,
                   sizeof(j2me_audio_methods) / sizeof(java_native_method));
    printf("[J2ME Audio] Registered %lu native methods\n",
           sizeof(j2me_audio_methods) / sizeof(java_native_method));
}
