package javax.microedition.lcdui;

import javax.microedition.lcdui.event.EventQueue;
import javax.microedition.lcdui.event.Event;
import javax.microedition.lcdui.event.CanvasEvent;
import javax.microedition.lcdui.event.RunnableEvent;
import javax.microedition.midlet.MIDlet;

/**
 * J2ME Display — manages the current Displayable and render loop.
 * Analogous to J2ME-Loader's Display.
 */
public class Display {
    private static Display instance;
    private Displayable current;
    private volatile boolean running;
    private static final EventQueue eventQueue = new EventQueue();
    private MIDlet currentMIDlet;

    // Screen dimensions (configurable via system properties)
    private static int screenWidth = 240;
    private static int screenHeight = 320;

    static {
        String w = System.getProperty("j2me.screen.width");
        String h = System.getProperty("j2me.screen.height");
        if (w != null) try { screenWidth = Integer.parseInt(w); } catch (Exception e) {}
        if (h != null) try { screenHeight = Integer.parseInt(h); } catch (Exception e) {}
    }

    private Display() {
    }

    public static Display getDisplay(MIDlet midlet) {
        if (instance == null) {
            instance = new Display();
        }
        if (midlet != null) {
            instance.currentMIDlet = midlet;
        }
        return instance;
    }

    public void setCurrent(Displayable d) {
        if (d == null) return;
        Displayable old = current;
        current = d;

        d.width = screenWidth;
        d.height = screenHeight;

        if (d instanceof Canvas) {
            // Pass canvas commands to native (for soft-key display)
            java.util.ArrayList<Command> cmds = d.getCommands();
            NativeBridge.formBegin("", 0); // reset command buffer
            for (int i = 0; i < cmds.size(); i++) {
                Command c = cmds.get(i);
                NativeBridge.formAddCommand(c.getLabel(), c.getCommandType(), c.getPriority(), i);
            }
            NativeBridge.showCanvas();
            Canvas canvas = (Canvas) d;
            canvas.initContext();
            canvas.repaintPending = true;
            canvas.showNotify();
        } else if (d instanceof Form) {
            ((Form) d).showNative();
        } else if (d instanceof List) {
            ((List) d).showNative();
        } else if (d instanceof Alert) {
            ((Alert) d).showNative();
        }

        if (old instanceof Canvas && old != d) {
            ((Canvas) old).hideNotify();
            ((Canvas) old).destroyContext();
        }
    }

    public void setCurrent(Alert alert, Displayable nextDisplayable) {
        alert.nextDisplayable = nextDisplayable;
        setCurrent(alert);
    }

    public Displayable getCurrent() {
        return current;
    }

    public void callSerially(Runnable r) {
        if (r != null) {
            Display.eventQueue.postEvent(RunnableEvent.getInstance(r));
        }
    }

    /**
     * Post an event to the event queue (analogous to J2ME-Loader's Display.postEvent).
     */
    public static void postEvent(Event event) {
        Display.eventQueue.postEvent(event);
    }

    // --- Display capabilities (MIDP 2.0) ---

    public boolean isColor() { return true; }
    public int numColors() { return 16777216; } // 24-bit (2^24)
    public int numAlphaLevels() { return 256; } // 8-bit alpha
    public boolean flashBacklight(int duration) { return false; }
    public int getBestImageHeight(int imageType) { return 0; }
    public int getBestImageWidth(int imageType) { return 0; }
    public int getBorderStyle(boolean highlighted) {
        return highlighted ? Graphics.SOLID : Graphics.DOTTED;
    }
    public int getColor(int colorSpecifier) { return 0; }

    // --- Vibration ---

    public boolean vibrate(int duration) {
        if (duration < 0) throw new IllegalArgumentException();
        NativeBridge.vibrate(duration);
        return true;
    }

    // --- Screen size ---

    public static int getScreenWidth() { return screenWidth; }
    public static int getScreenHeight() { return screenHeight; }

    // --- Render loop ---

    /**
     * Run the render/event loop. Blocks until MIDlet calls notifyDestroyed().
     * Called by MIDletRunner after startApp().
     */
    public void runEventLoop() {
        running = true;
        eventQueue.startProcessing();
        System.out.println("[Display] Event loop started (" + screenWidth + "x" + screenHeight + ")");

        while (running && !MIDlet.isDestroyRequested()) {
            // 0. Check if native side requested stop (e.g. user pressed Back)
            if (NativeBridge.isStopRequested()) {
                System.out.println("[Display] Native stop requested, exiting event loop");
                MIDlet.requestDestroy();
                break;
            }

            // 1. Poll native input events and post to EventQueue
            int[] nativeEvent;
            while ((nativeEvent = NativeBridge.pollInputEvent()) != null) {
                int type = nativeEvent[0];
                if (type <= 2 && current instanceof Canvas) {
                    // Pointer event → post CanvasEvent
                    Canvas c = (Canvas) current;
                    int ceType = type == 0 ? CanvasEvent.POINTER_PRESSED :
                                 type == 1 ? CanvasEvent.POINTER_DRAGGED : CanvasEvent.POINTER_RELEASED;
                    Display.eventQueue.postEvent(CanvasEvent.getInstance(c, ceType, 0, (float)nativeEvent[1], (float)nativeEvent[2]));
                } else if (type >= 3 && type <= 5 && current instanceof Canvas) {
                    // Key event → post CanvasEvent
                    Canvas c = (Canvas) current;
                    int ceType = type == 3 ? CanvasEvent.KEY_PRESSED :
                                 type == 4 ? CanvasEvent.KEY_RELEASED : CanvasEvent.KEY_REPEATED;
                    Display.eventQueue.postEvent(CanvasEvent.getInstance(c, ceType, nativeEvent[3]));
                } else if (type == 10) {
                    int cmdId = nativeEvent[3];
                    if (current != null) current.fireCommandAction(cmdId);
                } else if (type == 11 && current instanceof List) {
                    ((List) current).handleListSelect(nativeEvent[3]);
                } else if (type == 12 && current instanceof Alert) {
                    Alert alert = (Alert) current;
                    if (alert.nextDisplayable != null) setCurrent(alert.nextDisplayable);
                }
            }

            // 2. Handle resumeRequest — call startApp() again
            if (MIDlet.isResumeRequested() && currentMIDlet != null) {
                try {
                    currentMIDlet.callStartApp();
                } catch (Exception e) {
                    System.out.println("[Display] resumeRequest startApp error: " + e.getMessage());
                }
            }

            // 3. Repaint if needed (Canvas only)
            if (current instanceof Canvas) {
                Canvas canvas = (Canvas) current;
                if (canvas.repaintPending) {
                    canvas.doPaint();
                }
            }

            // Sleep in short intervals so we react quickly to destroyRequested
            try {
                for (int i = 0; i < 4 && !MIDlet.isDestroyRequested(); i++) {
                    Thread.sleep(4);
                }
            } catch (InterruptedException e) {
                break;
            }
        }

        eventQueue.stopProcessing();

        // Destroy current Canvas context to release native CGBitmapContext memory
        if (current instanceof Canvas) {
            ((Canvas) current).hideNotify();
            ((Canvas) current).destroyContext();
        }
        current = null;
        currentMIDlet = null;
        instance = null; // Reset for next MIDlet launch
        System.out.println("[Display] Event loop stopped");
    }

    /**
     * Stop the event loop.
     */
    public void stopEventLoop() {
        running = false;
    }
}
