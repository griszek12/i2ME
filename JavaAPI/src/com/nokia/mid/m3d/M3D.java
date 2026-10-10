package com.nokia.mid.m3d;
/** Stub — Nokia 3D API not implemented */
public class M3D {
    public static final int ANTIALIAS = 0;
    public static final int DITHER = 1;
    public static final int TRUE_COLOR = 2;
    public static M3D createInstance() { return new M3D(); }
    public void setupBuffers(int flags, int w, int h) { }
    public void bindTarget(javax.microedition.lcdui.Graphics g) { }
    public void releaseTarget() { }
    public void clear(int color) { }
    public void setCamera(int x, int y, int z, int dx, int dy, int dz, int roll) { }
    public void enableLight(int id, boolean on) { }
    public void setLightDirection(int id, int dx, int dy, int dz) { }
    public void setLightColor(int id, int color) { }
    public void setLightIntensity(int id, int i) { }
    public void setLightAmbientIntensity(int id, int i) { }
    public void postRotate(int a, int x, int y, int z) { }
    public void postTranslate(int x, int y, int z) { }
    public void postScale(int x, int y, int z) { }
    public void setIdentity() { }
    public void renderMesh(Texture t, int[] vertices, int[] normals, int[] texCoords, int[] faces) { }
    public void flush() { }
}
