package javax.microedition.lcdui;

/**
 * J2ME Graphics — thin wrapper over native Core Graphics context.
 * Analogous to J2ME-Loader's Graphics wrapping android.graphics.Canvas.
 */
public class Graphics {
    // Anchor constants
    public static final int HCENTER = 1;
    public static final int VCENTER = 2;
    public static final int LEFT = 4;
    public static final int RIGHT = 8;
    public static final int TOP = 16;
    public static final int BOTTOM = 32;
    public static final int BASELINE = 64;

    // Stroke constants
    public static final int SOLID = 0;
    public static final int DOTTED = 1;

    long nativeContext;
    boolean ownsContext; // true for Image graphics (released in finalize), false for Canvas graphics
    private int canvasWidth, canvasHeight;
    private int color = 0;
    private Font font = Font.getDefaultFont();
    private int translateX = 0, translateY = 0;
    private int clipX, clipY, clipW, clipH;
    private int strokeStyle = SOLID;

    Graphics(long nativeContext, int width, int height) {
        this.nativeContext = nativeContext;
        this.canvasWidth = width;
        this.canvasHeight = height;
        this.clipX = 0;
        this.clipY = 0;
        this.clipW = width;
        this.clipH = height;
        // Apply default font to native context
        font.applyToContext(nativeContext);
    }

    /**
     * Reset graphics state for a new paint cycle.
     */
    void reset(int clipX, int clipY, int clipW, int clipH) {
        this.translateX = 0;
        this.translateY = 0;
        this.clipX = clipX;
        this.clipY = clipY;
        this.clipW = clipW;
        this.clipH = clipH;
        NativeBridge.setClip(nativeContext, clipX, clipY, clipW, clipH);
        setColor(0x000000);
        setFont(Font.getDefaultFont());
        NativeBridge.setStrokeStyle(nativeContext, SOLID);
    }

    // --- Color ---

    public void setColor(int RGB) {
        this.color = RGB & 0x00FFFFFF;
        NativeBridge.setColor(nativeContext, 0xFF000000 | this.color);
    }

    public void setColor(int red, int green, int blue) {
        setColor((red << 16) | (green << 8) | blue);
    }

    public int getColor() { return color; }
    public int getRedComponent() { return (color >> 16) & 0xFF; }
    public int getGreenComponent() { return (color >> 8) & 0xFF; }
    public int getBlueComponent() { return color & 0xFF; }

    public void setGrayScale(int value) {
        setColor(value, value, value);
    }

    public int getGrayScale() {
        return (getRedComponent() + getGreenComponent() + getBlueComponent()) / 3;
    }

    // --- Stroke ---

    public void setStrokeStyle(int style) {
        this.strokeStyle = style;
        NativeBridge.setStrokeStyle(nativeContext, style);
    }

    public int getStrokeStyle() { return strokeStyle; }

    // --- Font ---

    public void setFont(Font f) {
        if (f == null) f = Font.getDefaultFont();
        this.font = f;
        f.applyToContext(nativeContext);
    }

    public Font getFont() { return font; }

    // --- Clip ---

    public void setClip(int x, int y, int w, int h) {
        clipX = x;
        clipY = y;
        clipW = w;
        clipH = h;
        NativeBridge.setClip(nativeContext, x + translateX, y + translateY, w, h);
    }

    public void clipRect(int x, int y, int w, int h) {
        // Intersect with current clip
        int nx = Math.max(clipX, x);
        int ny = Math.max(clipY, y);
        int nw = Math.min(clipX + clipW, x + w) - nx;
        int nh = Math.min(clipY + clipH, y + h) - ny;
        if (nw < 0) nw = 0;
        if (nh < 0) nh = 0;
        setClip(nx, ny, nw, nh);
    }

    public int getClipX() { return clipX; }
    public int getClipY() { return clipY; }
    public int getClipWidth() { return clipW; }
    public int getClipHeight() { return clipH; }

    // --- Transform ---

    public void translate(int x, int y) {
        translateX += x;
        translateY += y;
    }

    public int getTranslateX() { return translateX; }
    public int getTranslateY() { return translateY; }

    // --- Drawing ---

    public void drawLine(int x1, int y1, int x2, int y2) {
        NativeBridge.drawLine(nativeContext,
                x1 + translateX, y1 + translateY,
                x2 + translateX, y2 + translateY);
    }

    public void fillRect(int x, int y, int w, int h) {
        NativeBridge.fillRect(nativeContext,
                x + translateX, y + translateY, w, h);
    }

    public void drawRect(int x, int y, int w, int h) {
        NativeBridge.drawRect(nativeContext,
                x + translateX, y + translateY, w, h);
    }

    public void fillArc(int x, int y, int w, int h, int startAngle, int arcAngle) {
        NativeBridge.fillArc(nativeContext,
                x + translateX, y + translateY, w, h, startAngle, arcAngle);
    }

    public void drawArc(int x, int y, int w, int h, int startAngle, int arcAngle) {
        NativeBridge.drawArc(nativeContext,
                x + translateX, y + translateY, w, h, startAngle, arcAngle);
    }

    public void fillRoundRect(int x, int y, int w, int h, int arcWidth, int arcHeight) {
        NativeBridge.fillRoundRect(nativeContext,
                x + translateX, y + translateY, w, h, arcWidth, arcHeight);
    }

    public void drawRoundRect(int x, int y, int w, int h, int arcWidth, int arcHeight) {
        NativeBridge.drawRoundRect(nativeContext,
                x + translateX, y + translateY, w, h, arcWidth, arcHeight);
    }

    // --- Text ---

    public void drawString(String str, int x, int y, int anchor) {
        if (str == null || str.isEmpty()) return;
        NativeBridge.drawString(nativeContext, str,
                x + translateX, y + translateY, anchor);
    }

    public void drawSubstring(String str, int offset, int len, int x, int y, int anchor) {
        drawString(str.substring(offset, offset + len), x, y, anchor);
    }

    public void drawChar(char character, int x, int y, int anchor) {
        drawString(String.valueOf(character), x, y, anchor);
    }

    public void drawChars(char[] data, int offset, int length, int x, int y, int anchor) {
        drawString(new String(data, offset, length), x, y, anchor);
    }

    // --- Image ---

    public void drawImage(Image img, int x, int y, int anchor) {
        if (img == null) return;
        NativeBridge.drawImage(nativeContext, img.nativeHandle,
                x + translateX, y + translateY, anchor);
    }

    public void drawRegion(Image src, int xSrc, int ySrc, int wSrc, int hSrc,
                           int transform, int xDst, int yDst, int anchor) {
        if (src == null) return;
        NativeBridge.drawRegion(nativeContext, src.nativeHandle,
                xSrc, ySrc, wSrc, hSrc, transform,
                xDst + translateX, yDst + translateY, anchor);
    }

    public void drawRGB(int[] rgbData, int offset, int scanlength,
                        int x, int y, int width, int height, boolean processAlpha) {
        NativeBridge.drawRGB(nativeContext, rgbData, offset, scanlength,
                x + translateX, y + translateY, width, height, processAlpha ? 1 : 0);
    }

    public void fillPolygon(int[] xPoints, int[] yPoints, int nPoints) {
        if (xPoints == null || yPoints == null) return;
        int[] tx = new int[nPoints];
        int[] ty = new int[nPoints];
        for (int i = 0; i < nPoints; i++) { tx[i] = xPoints[i] + translateX; ty[i] = yPoints[i] + translateY; }
        NativeBridge.fillPolygon(nativeContext, tx, ty, nPoints);
    }

    public void drawPolygon(int[] xPoints, int[] yPoints, int nPoints) {
        if (xPoints == null || yPoints == null) return;
        int[] tx = new int[nPoints];
        int[] ty = new int[nPoints];
        for (int i = 0; i < nPoints; i++) { tx[i] = xPoints[i] + translateX; ty[i] = yPoints[i] + translateY; }
        NativeBridge.drawPolygon(nativeContext, tx, ty, nPoints);
    }

    public void fillTriangle(int x1, int y1, int x2, int y2, int x3, int y3) {
        fillPolygon(new int[]{x1, x2, x3}, new int[]{y1, y2, y3}, 3);
    }

    public int getDisplayColor(int color) {
        // True color display — return as-is (24-bit)
        return color & 0x00FFFFFF;
    }

    /** Returns the native CGContext handle — used by micro3D Render for GL-to-canvas blit */
    public long getNativeContext() {
        return nativeContext;
    }

    /** Full canvas/image width — may differ from clip width */
    public int getCanvasWidth() { return canvasWidth; }

    /** Full canvas/image height — may differ from clip height */
    public int getCanvasHeight() { return canvasHeight; }

    /** Read pixel data from canvas — used by Nokia DirectGraphics */
    public void getPixels(int[] pixels, int offset, int scanlength, int x, int y, int w, int h) {
        // TODO: read from canvas context — for now stub with zeros
        // This requires reading from the RenderContext's bitmap, not from an Image
    }

    public void copyArea(int xSrc, int ySrc, int width, int height,
                         int xDest, int yDest, int anchor) {
        // Apply anchor to destination
        if ((anchor & HCENTER) != 0) xDest -= width / 2;
        if ((anchor & RIGHT) != 0) xDest -= width;
        if ((anchor & VCENTER) != 0) yDest -= height / 2;
        if ((anchor & BOTTOM) != 0) yDest -= height;
        // Read pixels from source area, write to dest
        int[] pixels = new int[width * height];
        // Use a temporary approach — read from the context's backing image
        // For now, use drawRegion-like approach through native
        // This is a simplified implementation
        NativeBridge.copyArea(nativeContext, xSrc + translateX, ySrc + translateY,
                width, height, xDest + translateX, yDest + translateY);
    }

    protected void finalize() throws Throwable {
        if (ownsContext && nativeContext != 0) {
            NativeBridge.destroyContext(nativeContext);
            nativeContext = 0;
        }
        super.finalize();
    }
}
