/*
 * Ported from J2ME-Loader. Removed Android/PanControl/EqualizerControl deps.
 */
package javax.microedition.media;

import java.util.ArrayList;
import java.util.HashMap;
import javax.microedition.media.control.VolumeControl;

public class BasePlayer implements Player, VolumeControl {
    private TimeBase timeBase;
    protected int state;
    private int loopCount = 1;
    private int loopsLeft;
    private final ArrayList<PlayerListener> listeners = new ArrayList<PlayerListener>();
    private final HashMap<String, Control> controls = new HashMap<String, Control>();
    private boolean mute;
    private int level = 100;

    public BasePlayer() {
        state = UNREALIZED;
        controls.put(VolumeControl.class.getName(), this);
        controls.put("VolumeControl", this);
    }

    public void addControl(String name, Control control) { controls.put(name, control); }

    public void complete() {
        if (state == STARTED) {
            loopsLeft--;
            if (loopsLeft == 0) {
                try { stop(); } catch (MediaException e) {}
                postEvent(PlayerListener.END_OF_MEDIA, new Long(getMediaTime()));
            } else {
                try {
                    setMediaTime(0);
                    doStart();
                } catch (MediaException e) {}
            }
        }
    }

    public Control getControl(String controlType) {
        checkRealized();
        if (!controlType.contains(".")) controlType = "javax.microedition.media.control." + controlType;
        return controls.get(controlType);
    }

    public Control[] getControls() {
        checkRealized();
        return controls.values().toArray(new Control[0]);
    }

    public void addPlayerListener(PlayerListener pl) {
        checkClosed();
        if (pl != null && !listeners.contains(pl)) listeners.add(pl);
    }

    public void removePlayerListener(PlayerListener pl) {
        checkClosed();
        listeners.remove(pl);
    }

    protected void postEvent(String event, Object data) {
        for (PlayerListener pl : new ArrayList<PlayerListener>(listeners)) {
            pl.playerUpdate(this, event, data);
        }
    }

    public void realize() throws MediaException {
        checkClosed();
        if (state < REALIZED) { doRealize(); state = REALIZED; }
    }

    public void prefetch() throws MediaException {
        checkClosed();
        if (state < REALIZED) realize();
        if (state < PREFETCHED) { doPrefetch(); state = PREFETCHED; }
    }

    public void start() throws MediaException {
        prefetch();
        if (state == PREFETCHED) {
            loopsLeft = loopCount;
            doStart();
            state = STARTED;
            postEvent(PlayerListener.STARTED, new Long(getMediaTime()));
        }
    }

    public void stop() throws MediaException {
        if (state == STARTED) {
            doStop();
            state = PREFETCHED;
            postEvent(PlayerListener.STOPPED, new Long(getMediaTime()));
        }
    }

    public void deallocate() {
        if (state == STARTED) { try { stop(); } catch (MediaException e) {} }
        if (state == PREFETCHED) state = REALIZED;
    }

    public void close() {
        if (state != CLOSED) {
            if (state == STARTED) { try { stop(); } catch (MediaException e) {} }
            doClose();
            state = CLOSED;
            postEvent(PlayerListener.CLOSED, null);
        }
    }

    public int getState() { return state; }
    public long getDuration() { return doGetDuration(); }
    public long getMediaTime() { return doGetMediaTime(); }
    public long setMediaTime(long now) throws MediaException { return doSetMediaTime(now); }
    public void setLoopCount(int count) { loopCount = count == -1 ? Integer.MAX_VALUE : count; }
    public String getContentType() { return ""; }
    public TimeBase getTimeBase() { return timeBase; }
    public void setTimeBase(TimeBase master) { timeBase = master; }

    // VolumeControl
    public int setLevel(int l) { level = Math.max(0, Math.min(100, l)); doSetLevel(level); return level; }
    public int getLevel() { return level; }
    public void setMute(boolean m) { mute = m; doSetLevel(m ? 0 : level); }
    public boolean isMuted() { return mute; }

    // Subclass hooks
    protected void doRealize() throws MediaException {}
    protected void doPrefetch() throws MediaException {}
    protected void doStart() throws MediaException {}
    protected void doStop() throws MediaException {}
    protected void doClose() {}
    protected long doGetDuration() { return TIME_UNKNOWN; }
    protected long doGetMediaTime() { return TIME_UNKNOWN; }
    protected long doSetMediaTime(long now) throws MediaException { return now; }
    protected void doSetLevel(int level) {}

    protected void checkClosed() { if (state == CLOSED) throw new IllegalStateException("Player is closed"); }
    protected void checkRealized() { if (state < REALIZED) throw new IllegalStateException("Player not realized"); }
}
