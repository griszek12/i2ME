package javax.microedition.media;

import javax.microedition.lcdui.NativeBridge;

/**
 * Player for MIDI via native AVMIDIPlayer + gs_instruments.sf2.
 * Analogous to J2ME-Loader's MidiPlayer wrapping MidiDriver.
 */
public class MidiPlayer extends BasePlayer {
    private long nativeHandle;
    private byte[] midiData;

    public MidiPlayer(byte[] data) {
        this.midiData = data;
    }

    protected void doRealize() throws MediaException {
        if (midiData != null) {
            nativeHandle = NativeBridge.audioCreateMidiPlayer(midiData);
            if (nativeHandle == 0) throw new MediaException("Failed to create MIDI player");
        }
    }

    protected void doStart() throws MediaException {
        if (nativeHandle != 0) NativeBridge.audioMidiStart(nativeHandle);
    }

    protected void doStop() throws MediaException {
        if (nativeHandle != 0) NativeBridge.audioMidiStop(nativeHandle);
    }

    protected void doClose() {
        if (nativeHandle != 0) {
            NativeBridge.audioMidiClose(nativeHandle);
            nativeHandle = 0;
        }
        midiData = null;
    }
}
