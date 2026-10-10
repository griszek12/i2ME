#ifndef JVM_BRIDGE_H
#define JVM_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

/// 3D supersampling scale factor (shared by M3G and MascotCapsule).
/// Set by jvm_bridge_init, read by j2me_m3g_jni.c and MC3D via system property.
extern int g_render_3d_scale;

/// Initialize miniJVM with the given resource and save directories.
/// @param res_root         Path to directory containing runtime JARs
/// @param save_root        Path to writable directory for app data
/// @param midlet_jar       Path to the MIDlet JAR to include in classpath
/// @param screen_width     J2ME virtual screen width (e.g. 240)
/// @param screen_height    J2ME virtual screen height (e.g. 320)
/// @param render_3d_scale  3D supersampling factor for M3G & MC3D (1=native, 2=2x, 3=3x)
/// @param fps_limit        Max frames per second (0 = unlimited)
/// @return 0 on success, non-zero on failure
int jvm_bridge_init(const char *res_root, const char *save_root, const char *midlet_jar,
                    int screen_width, int screen_height, int render_3d_scale,
                    int fps_limit);

/// Run a MIDlet from a JAR file via MIDletRunner.
/// @param midlet_jar_path Path to the MIDlet JAR file
/// @return 0 on success, non-zero on failure
int jvm_bridge_run_midlet(const char *midlet_jar_path);

/// Destroy the JVM instance and free resources.
void jvm_bridge_destroy(void);

/// Request graceful MIDlet stop (non-blocking, thread-safe).
/// Can be called from any thread (e.g. main UI thread).
/// The Display event loop will detect this and call notifyDestroyed().
void jvm_bridge_request_stop(void);

/// Check if stop has been requested. Called from native methods on JVM thread.
int jvm_bridge_is_stop_requested(void);

#ifdef __cplusplus
}
#endif

#endif /* JVM_BRIDGE_H */
