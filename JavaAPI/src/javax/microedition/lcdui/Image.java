package javax.microedition.lcdui;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/**
 * J2ME Image — wraps a native CGImage/CGBitmapContext handle.
 * Analogous to J2ME-Loader's Image wrapping android.graphics.Bitmap.
 */
public class Image {
    public long nativeHandle; // RenderImage pointer
    private int width, height;
    private boolean mutable;

    private Graphics cachedGraphics;

    public Image(long nativeHandle, int width, int height, boolean mutable) {
        this.nativeHandle = nativeHandle;
        this.width = width;
        this.height = height;
        this.mutable = mutable;
    }

    public static Image createImage(int width, int height) {
        long handle = NativeBridge.createMutableImage(width, height);
        if (handle == 0) {
            System.out.println("[Image] ERROR: createMutableImage returned 0 for " + width + "x" + height);
        }
        return new Image(handle, width, height, true);
    }

    /**
     * Create a mutable image filled with the specified ARGB color.
     * When argb is 0, the image is fully transparent.
     */
    public static Image createImage(int width, int height, int argb) {
        Image img = createImage(width, height);
        if (argb != 0) {
            // Fill with the specified color
            int[] fill = new int[width * height];
            java.util.Arrays.fill(fill, argb);
            Graphics g = img.getGraphics();
            g.drawRGB(fill, 0, width, 0, 0, width, height, true);
        } else {
            // Clear to fully transparent by overwriting with transparent pixels
            int[] fill = new int[width * height];
            // fill is already all zeros (fully transparent)
            Graphics g = img.getGraphics();
            g.drawRGB(fill, 0, width, 0, 0, width, height, true);
        }
        return img;
    }

    public static Image createImage(String name) throws IOException {
        InputStream is = findResource(name);
        if (is == null) {
            System.out.println("[Image] ERROR: resource not found: " + name);
            throw new IOException("Image resource not found: " + name);
        }
        return createImage(is);
    }

    private static InputStream findResource(String name) {
        // Try exact name first via classloader
        InputStream is = tryLoadResource(name);
        if (is != null) return is;

        // If resource has no extension, search JARs on the classpath
        // for an entry whose name before the extension matches
        if (name.lastIndexOf('.') <= name.lastIndexOf('/')) {
            String searchName = name.startsWith("/") ? name.substring(1) : name;
            String match = findEntryByPrefix(searchName);
            if (match != null) {
                is = tryLoadResource("/" + match);
                if (is != null) return is;
            }
        }
        return null;
    }

    /**
     * Scan classpath JARs for an entry whose basename (without extension)
     * matches the given name. For example, searching for "bg1" will match "bg1.png".
     */
    private static String findEntryByPrefix(String name) {
        String cp = System.getProperty("java.class.path");
        if (cp == null) return null;
        String[] paths = cp.split(File.pathSeparator);
        for (String path : paths) {
            if (path == null || path.length() == 0) continue;
            File f = new File(path);
            if (!f.isFile()) continue;
            try {
                ZipFile zf = new ZipFile(f);
                Enumeration entries = zf.entries();
                while (entries.hasMoreElements()) {
                    ZipEntry entry = (ZipEntry) entries.nextElement();
                    String entryName = entry.getName();
                    int dotIdx = entryName.lastIndexOf('.');
                    if (dotIdx > 0) {
                        String baseName = entryName.substring(0, dotIdx);
                        if (baseName.equals(name)) {
                            zf.close();
                            return entryName;
                        }
                    }
                }
                zf.close();
            } catch (IOException e) {
                // skip this jar
            }
        }
        return null;
    }

    private static InputStream tryLoadResource(String name) {
        InputStream is = Image.class.getResourceAsStream(name);
        if (is == null && !name.startsWith("/")) {
            is = Image.class.getResourceAsStream("/" + name);
        }
        if (is == null) {
            ClassLoader cl = Thread.currentThread().getContextClassLoader();
            if (cl != null) {
                is = cl.getResourceAsStream(name);
                if (is == null && name.startsWith("/")) {
                    is = cl.getResourceAsStream(name.substring(1));
                }
            }
        }
        return is;
    }

    public static Image createImage(InputStream stream) throws IOException {
        byte[] data = readAllBytes(stream);
        return createImage(data, 0, data.length);
    }

    public static Image createImage(byte[] imageData, int imageOffset, int imageLength) {
        long handle = NativeBridge.createImageFromData(imageData, imageOffset, imageLength);
        if (handle == 0) {
            throw new IllegalArgumentException("Failed to decode image data");
        }
        int w = NativeBridge.getImageWidth(handle);
        int h = NativeBridge.getImageHeight(handle);
        return new Image(handle, w, h, false);
    }

    public static Image createImage(Image source, int x, int y, int width, int height, int transform) {
        // Determine output size based on transform
        int outW = width, outH = height;
        if (transform == 5 || transform == 6 || transform == 7 || transform == 4) {
            // ROT90, ROT270, MIRROR_ROT90, MIRROR_ROT270 swap axes
            outW = height; outH = width;
        }
        Image result = createImage(outW, outH);
        Graphics g = result.getGraphics();
        g.drawRegion(source, x, y, width, height, transform, 0, 0, Graphics.LEFT | Graphics.TOP);
        // Mark as immutable but keep same object to avoid double-free
        result.mutable = false;
        return result;
    }

    public static Image createImage(Image source) {
        // Create mutable copy
        Image copy = createImage(source.width, source.height);
        Graphics g = copy.getGraphics();
        g.drawImage(source, 0, 0, Graphics.LEFT | Graphics.TOP);
        return copy;
    }

    public static Image createRGBImage(int[] rgb, int width, int height, boolean processAlpha) {
        Image img = createImage(width, height);
        Graphics g = img.getGraphics();
        g.drawRGB(rgb, 0, width, 0, 0, width, height, processAlpha);
        return img;
    }

    public Graphics getGraphics() {
        if (!mutable) {
            throw new IllegalStateException("Image is not mutable");
        }
        if (cachedGraphics == null) {
            long ctx = NativeBridge.getImageContext(nativeHandle);
            cachedGraphics = new Graphics(ctx, width, height);
            cachedGraphics.ownsContext = true;
        }
        return cachedGraphics;
    }

    public int getWidth() { return width; }
    public int getHeight() { return height; }
    public boolean isMutable() { return mutable; }

    public void getRGB(int[] rgbData, int offset, int scanlength,
                       int x, int y, int w, int h) {
        NativeBridge.getImageRGB(nativeHandle, rgbData, offset, scanlength, x, y, w, h);
    }

    private static byte[] readAllBytes(InputStream is) throws IOException {
        ByteArrayOutputStream bos = new ByteArrayOutputStream(4096);
        byte[] buf = new byte[4096];
        int n;
        while ((n = is.read(buf)) > 0) {
            bos.write(buf, 0, n);
        }
        is.close();
        return bos.toByteArray();
    }

    protected void finalize() throws Throwable {
        // Don't destroy cachedGraphics.nativeContext here — the Graphics
        // object may still be in use on another thread's stack.
        // Graphics.finalize() will release its own RenderContext (ownsContext=true).
        cachedGraphics = null;
        if (nativeHandle != 0) {
            NativeBridge.destroyImage(nativeHandle);
            nativeHandle = 0;
        }
        super.finalize();
    }
}
