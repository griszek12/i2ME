package javax.microedition.lcdui;

public class Spacer extends Item {
    private int minWidth, minHeight;
    public Spacer(int minWidth, int minHeight) { this.minWidth = minWidth; this.minHeight = minHeight; }
    public void setMinimumSize(int w, int h) { minWidth = w; minHeight = h; }
    int getItemType() { return 4; }
    String getItemText() { return ""; }
}
