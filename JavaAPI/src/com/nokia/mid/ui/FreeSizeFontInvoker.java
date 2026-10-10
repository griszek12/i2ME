package com.nokia.mid.ui;
import javax.microedition.lcdui.Font;
public class FreeSizeFontInvoker {
    public static Font getFont(int face, int style, int height) {
        if (height <= 12) return Font.getFont(face, style, Font.SIZE_SMALL);
        if (height <= 16) return Font.getFont(face, style, Font.SIZE_MEDIUM);
        return Font.getFont(face, style, Font.SIZE_LARGE);
    }
}
