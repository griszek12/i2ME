package com.samsung.util;
import javax.microedition.media.*;
import java.io.*;
public class AudioClip {
    public static final int TYPE_MMF = 1;
    public static final int TYPE_MP3 = 2;
    public static final int TYPE_MIDI = 5;
    private Player player;
    public AudioClip(int type, String resname) {
        try {
            InputStream is = AudioClip.class.getResourceAsStream(resname);
            if (is == null && !resname.startsWith("/")) is = AudioClip.class.getResourceAsStream("/" + resname);
            if (is != null) { player = Manager.createPlayer(is, "audio/midi"); player.realize(); }
        } catch (Exception e) { System.out.println("AudioClip: " + e.getMessage()); }
    }
    public AudioClip(int type, byte[] data, int off, int len) {
        try { player = Manager.createPlayer(new ByteArrayInputStream(data, off, len), "audio/midi"); player.realize(); }
        catch (Exception e) { }
    }
    public void play(int loop, int vol) { try { if (player!=null) { player.setLoopCount(loop); player.start(); } } catch (Exception e) {} }
    public void pause() { try { if (player!=null) player.stop(); } catch (Exception e) {} }
    public void resume() { try { if (player!=null) player.start(); } catch (Exception e) {} }
    public void stop() { try { if (player!=null) player.stop(); } catch (Exception e) {} }
    public static boolean isSupported() { return true; }
}
