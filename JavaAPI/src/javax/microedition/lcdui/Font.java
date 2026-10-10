package javax.microedition.lcdui;

/**
 * J2ME Font — delegates metrics to native CoreText via NativeBridge.
 * Analogous to J2ME-Loader's Font wrapping android.graphics.Paint + Typeface.
 */
public class Font {
    public static final int FACE_SYSTEM = 0;
    public static final int FACE_MONOSPACE = 32;
    public static final int FACE_PROPORTIONAL = 64;

    public static final int STYLE_PLAIN = 0;
    public static final int STYLE_BOLD = 1;
    public static final int STYLE_ITALIC = 2;
    public static final int STYLE_UNDERLINED = 4;

    public static final int SIZE_SMALL = 8;
    public static final int SIZE_MEDIUM = 0;
    public static final int SIZE_LARGE = 16;

    private int face, style, size;
    // Cached metrics — lazily computed via native context
    private int cachedHeight = -1;
    private int cachedAscent = -1;

    private Font(int face, int style, int size) {
        this.face = face;
        this.style = style;
        this.size = size;
    }

    public static Font getFont(int face, int style, int size) {
        return new Font(face, style, size);
    }

    public static Font getDefaultFont() {
        return new Font(FACE_SYSTEM, STYLE_PLAIN, SIZE_MEDIUM);
    }

    public int getFace() { return face; }
    public int getStyle() { return style; }
    public int getSize() { return size; }

    public boolean isPlain() { return style == STYLE_PLAIN; }
    public boolean isBold() { return (style & STYLE_BOLD) != 0; }
    public boolean isItalic() { return (style & STYLE_ITALIC) != 0; }
    public boolean isUnderlined() { return (style & STYLE_UNDERLINED) != 0; }

    public int getHeight() {
        return cachedHeight >= 0 ? cachedHeight : 16; // fallback
    }

    public int getBaselinePosition() {
        return cachedAscent >= 0 ? cachedAscent : 13; // fallback
    }

    public int stringWidth(String str) {
        // Need a context to measure — use temporary approach
        // Graphics will call applyToContext which caches metrics
        return str.length() * 8; // rough fallback
    }

    public int charWidth(char ch) {
        return stringWidth(String.valueOf(ch));
    }

    public int charsWidth(char[] ch, int offset, int length) {
        return stringWidth(new String(ch, offset, length));
    }

    public int substringWidth(String str, int offset, int len) {
        return stringWidth(str.substring(offset, offset + len));
    }

    /**
     * Apply this font to a native context and cache metrics.
     * Called by Graphics when font changes.
     */
    void applyToContext(long ctx) {
        NativeBridge.setFont(ctx, face, style, size);
        cachedHeight = NativeBridge.getFontHeight(ctx);
        cachedAscent = NativeBridge.getFontAscent(ctx);
    }

    /**
     * Measure string width using the given native context.
     */
    int stringWidth(long ctx, String str) {
        return NativeBridge.getStringWidth(ctx, str);
    }
}
