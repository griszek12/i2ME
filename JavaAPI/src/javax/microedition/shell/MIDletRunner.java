/*
 * MIDletRunner — Java-based MIDlet launcher for iOS/miniJVM.
 *
 * Replaces J2ME-Loader's MicroLoader + MidletThread + MicroActivity.
 * Reads the MIDlet JAR manifest, loads the MIDlet class via reflection,
 * and manages the MIDlet lifecycle (startApp/pauseApp/destroyApp).
 */
package javax.microedition.shell;

import javax.microedition.midlet.MIDlet;
import javax.microedition.midlet.MIDletStateChangeException;
import javax.microedition.lcdui.Canvas;
import javax.microedition.lcdui.Display;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class MIDletRunner {

    /**
     * Entry point. Args:
     *   args[0] = path to MIDlet JAR file
     *   args[1] = (optional) MIDlet class name override
     */
    public static void main(String[] args) {
        if (args == null || args.length < 1) {
            System.out.println("[MIDletRunner] ERROR: Usage: MIDletRunner <midlet.jar> [ClassName]");
            return;
        }

        String jarPath = args[0];
        String classNameOverride = (args.length > 1) ? args[1] : null;

        System.out.println("[MIDletRunner] Loading MIDlet JAR: " + jarPath);

        try {
            // 1. Read manifest
            Map<String, String> manifestAttrs = readManifest(jarPath);

            String midletName = manifestAttrs.get("MIDlet-Name");
            String midletVersion = manifestAttrs.get("MIDlet-Version");
            System.out.println("[MIDletRunner] MIDlet-Name: " + midletName);
            System.out.println("[MIDletRunner] MIDlet-Version: " + midletVersion);

            // 2. Determine MIDlet class name
            String className;
            if (classNameOverride != null && !classNameOverride.isEmpty()) {
                className = classNameOverride;
            } else {
                className = parseMIDletClassName(manifestAttrs);
            }

            if (className == null) {
                System.out.println("[MIDletRunner] ERROR: No MIDlet class found in manifest");
                return;
            }
            System.out.println("[MIDletRunner] MIDlet class: " + className);

            // 3. Initialize properties (manifest attributes available to MIDlet)
            MIDlet.initProps(manifestAttrs);
            MIDlet.resetDestroyRequest();

            // Apply FPS limit from system property (set by iOS native side)
            String fpsStr = System.getProperty("j2me.fps.limit");
            if (fpsStr != null) {
                try {
                    Canvas.setLimitFps(Integer.parseInt(fpsStr));
                } catch (NumberFormatException ignored) {}
            }

            // 4. Load and instantiate MIDlet class
            System.out.println("[MIDletRunner] Loading class: " + className);
            Class<?> clazz = Class.forName(className);
            MIDlet midlet = (MIDlet) clazz.newInstance();

            // 5. Run lifecycle
            runLifecycle(midlet);

        } catch (Exception e) {
            System.out.println("[MIDletRunner] ERROR: " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Read all attributes from the JAR's META-INF/MANIFEST.MF using ZipFile.
     * Manual parsing since miniJVM's JarFile.getManifest().getMainAttributes()
     * is not fully implemented.
     */
    private static Map<String, String> readManifest(String jarPath) throws Exception {
        Map<String, String> result = new HashMap<String, String>();

        ZipFile zipFile = new ZipFile(jarPath);
        try {
            ZipEntry entry = zipFile.getEntry("META-INF/MANIFEST.MF");
            if (entry == null) {
                System.out.println("[MIDletRunner] WARNING: No MANIFEST.MF in JAR");
                return result;
            }

            InputStream is = zipFile.getInputStream(entry);
            BufferedReader reader = new BufferedReader(new InputStreamReader(is, "UTF-8"));

            String lastKey = null;
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.isEmpty()) continue;

                // Continuation line (starts with space)
                if (line.charAt(0) == ' ' && lastKey != null) {
                    String prev = result.get(lastKey);
                    result.put(lastKey, prev + line.substring(1));
                    continue;
                }

                int colon = line.indexOf(':');
                if (colon > 0) {
                    String key = line.substring(0, colon).trim();
                    String value = line.substring(colon + 1).trim();
                    result.put(key, value);
                    lastKey = key;
                }
            }
            reader.close();
        } finally {
            zipFile.close();
        }

        return result;
    }

    /**
     * Parse the MIDlet class name from MIDlet-1 attribute.
     * Format: "Name, Icon, ClassName"
     */
    private static String parseMIDletClassName(Map<String, String> attrs) {
        // Try MIDlet-1 first
        String midlet1 = attrs.get("MIDlet-1");
        if (midlet1 == null) {
            // Try any MIDlet-N
            for (Map.Entry<String, String> entry : attrs.entrySet()) {
                String key = entry.getKey();
                if (key.startsWith("MIDlet-") && !key.equals("MIDlet-Name")
                        && !key.equals("MIDlet-Version")
                        && !key.equals("MIDlet-Vendor")) {
                    midlet1 = entry.getValue();
                    break;
                }
            }
        }

        if (midlet1 == null) return null;

        System.out.println("[MIDletRunner] MIDlet-1: " + midlet1);

        // Parse "Name, Icon, ClassName"
        String[] parts = midlet1.split(",");
        if (parts.length >= 3) {
            return parts[2].trim();
        } else if (parts.length == 1) {
            return parts[0].trim();
        }

        return null;
    }

    /**
     * Run the MIDlet lifecycle: startApp → (wait) → pauseApp → destroyApp
     */
    private static void runLifecycle(MIDlet midlet) {
        try {
            // startApp
            System.out.println("[MIDletRunner] >>> Calling startApp()");
            midlet.callStartApp();
            System.out.println("[MIDletRunner] <<< startApp() returned");

            // Run event/render loop — blocks until MIDlet calls notifyDestroyed().
            // Always run the loop — MIDlet may set Display.setCurrent()
            // asynchronously from its own thread (e.g. Gravity Defied).
            // If native stop was already requested (user pressed Back during init/startApp),
            // the loop will detect it on the first iteration and exit immediately.
            Display display = Display.getDisplay(midlet);
            display.runEventLoop();

            // pauseApp
            if (!MIDlet.isDestroyRequested()) {
                System.out.println("[MIDletRunner] >>> Calling pauseApp()");
                midlet.callPauseApp();
                System.out.println("[MIDletRunner] <<< pauseApp() returned");
            }

            // destroyApp
            System.out.println("[MIDletRunner] >>> Calling destroyApp(true)");
            midlet.callDestroyApp(true);
            System.out.println("[MIDletRunner] <<< destroyApp() returned");

            System.out.println("[MIDletRunner] MIDlet lifecycle complete");

        } catch (MIDletStateChangeException e) {
            System.out.println("[MIDletRunner] MIDletStateChangeException: " + e.getMessage());
        } catch (Exception e) {
            System.out.println("[MIDletRunner] ERROR in lifecycle: " + e.getClass().getName()
                    + ": " + e.getMessage());
            e.printStackTrace();
        }
    }
}
