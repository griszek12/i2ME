package javax.microedition.media;

import javax.microedition.lcdui.NativeBridge;

/**
 * Player for WAV/MP3 audio via native AVAudioPlayer.
 * Analogous to J2ME-Loader's MicroPlayer wrapping Android MediaPlayer.
 */
public class MicroPlayer extends BasePlayer {
    private long nativeHandle;
    private byte[] audioData;

    public MicroPlayer(byte[] data) {
        this.audioData = data;
    }

    protected void doRealize() throws MediaException {
        nativeHandle = NativeBridge.audioCreatePlayer(audioData);
        if (nativeHandle == 0) throw new MediaException("Failed to create audio player");
    }

    protected void doStart() throws MediaException {
        NativeBridge.audioStart(nativeHandle);
    }

    protected void doStop() throws MediaException {
        NativeBridge.audioStop(nativeHandle);
    }

    protected void doClose() {
        if (nativeHandle != 0) {
            NativeBridge.audioClose(nativeHandle);
            nativeHandle = 0;
        }
        audioData = null;
    }

    protected long doGetDuration() {
        return nativeHandle != 0 ? NativeBridge.audioGetDuration(nativeHandle) : TIME_UNKNOWN;
    }

    protected long doGetMediaTime() {
        return nativeHandle != 0 ? NativeBridge.audioGetTime(nativeHandle) : 0;
    }

    protected void doSetLevel(int level) {
        if (nativeHandle != 0) NativeBridge.audioSetVolume(nativeHandle, level / 100.0f);
    }

    public void setLoopCount(int count) {
        super.setLoopCount(count);
        if (nativeHandle != 0) NativeBridge.audioSetLoop(nativeHandle, count == -1 ? -1 : count - 1);
    }
}
