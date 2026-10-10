/*
 * Copyright 2012 Kulikov Dmitriy
 * Copyright 2015-2016 Nickolay Savchenko
 * Copyright 2017-2018 Nikita Shakarun
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Ported for iOS/miniJVM: removed Android dependencies.
 */
package javax.microedition.midlet;

import javax.microedition.io.ConnectionNotFoundException;
import java.util.Map;

public abstract class MIDlet {
    private static Map<String, String> properties;
    private static volatile boolean destroyRequested = false;
    private static volatile boolean resumeRequested = false;
    private static volatile boolean paused = false;

    protected MIDlet() {
    }

    public static void initProps(Map<String, String> p) {
        properties = p;
    }

    public String getAppProperty(String key) {
        if (properties == null) return null;
        return properties.get(key);
    }

    /**
     * Report that the MIDlet is ready to go into a pause.
     * Sets the paused flag — MIDletRunner/Display will stop calling startApp
     * until resumeRequest() is called.
     */
    public final void notifyPaused() {
        paused = true;
    }

    /**
     * Report that the MIDlet has completed its work.
     */
    public final void notifyDestroyed() {
        destroyRequested = true;
    }

    /**
     * Request the platform to resume this MIDlet.
     * MIDletRunner will call startApp() again on the next event loop cycle.
     */
    public final void resumeRequest() {
        if (paused) {
            paused = false;
            resumeRequested = true;
        }
    }

    public static boolean isDestroyRequested() { return destroyRequested; }
    public static void requestDestroy() { destroyRequested = true; }
    public static boolean isResumeRequested() {
        if (resumeRequested) { resumeRequested = false; return true; }
        return false;
    }
    public static boolean isPaused() { return paused; }
    public static void resetDestroyRequest() { destroyRequested = false; paused = false; resumeRequested = false; }

    /**
     * Called every time the MIDlet becomes active.
     */
    protected abstract void startApp() throws MIDletStateChangeException;

    /**
     * Called every time the MIDlet pauses.
     */
    protected abstract void pauseApp();

    /**
     * Called when the application terminates.
     */
    protected abstract void destroyApp(boolean unconditional) throws MIDletStateChangeException;

    // --- Internal lifecycle dispatch (used by MIDletRunner) ---

    public final void callStartApp() throws MIDletStateChangeException {
        paused = false;
        startApp();
    }

    public final void callPauseApp() {
        pauseApp();
    }

    public final void callDestroyApp(boolean unconditional) throws MIDletStateChangeException {
        destroyApp(unconditional);
    }

    /**
     * Request the platform to handle a URL — opens in system browser.
     */
    public boolean platformRequest(String url) throws ConnectionNotFoundException {
        if (url == null || url.isEmpty()) return false;
        System.out.println("[MIDlet] platformRequest: " + url);
        javax.microedition.lcdui.NativeBridge.platformRequest(url);
        return false;
    }

    public final int checkPermission(String permission) {
        return 1; // allowed
    }
}
