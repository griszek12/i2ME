package javax.microedition.lcdui;

public class ImageItem extends Item {
    public static final int LAYOUT_DEFAULT = 0;
    public static final int LAYOUT_LEFT = 1;
    public static final int LAYOUT_RIGHT = 2;
    public static final int LAYOUT_CENTER = 3;

    private Image image;
    private String altText;
    private int appearanceMode;

    public ImageItem(String label, Image img, int layout, String altText) {
        setLabel(label); this.image = img; setLayout(layout); this.altText = altText;
    }
    public ImageItem(String label, Image img, int layout, String altText, int appearanceMode) {
        this(label, img, layout, altText); this.appearanceMode = appearanceMode;
    }

    public Image getImage() { return image; }
    public void setImage(Image img) { this.image = img; }
    public String getAltText() { return altText; }
    public void setAltText(String text) { this.altText = text; }
    public int getAppearanceMode() { return appearanceMode; }

    int getItemType() { return 3; }
    String getItemText() { return altText != null ? altText : ""; }
}
