package com.vodafone.v10.graphics.sprite;
import javax.microedition.lcdui.Canvas;
public abstract class SpriteCanvas extends Canvas {
    public SpriteCanvas(int type) { }
    public static int toSPColor(int p) { return p; }
    public static int toDeviceColor(int c) { return c; }
    public javax.microedition.lcdui.Graphics getSPGraphics() { return null; }
    public int createSpriteCanvas(int w, int h) { return 0; }
}
