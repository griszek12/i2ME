package javax.microedition.lcdui;

public class StringItem extends Item {
    private String text;
    private int appearanceMode;

    public StringItem(String label, String text) {
        this(label, text, PLAIN);
    }

    public StringItem(String label, String text, int appearanceMode) {
        setLabel(label);
        this.text = text;
        this.appearanceMode = appearanceMode;
    }

    public String getText() { return text; }
    public void setText(String text) { this.text = text; }
    public int getAppearanceMode() { return appearanceMode; }
    public Font getFont() { return Font.getDefaultFont(); }
    public void setFont(Font font) { }

    int getItemType() { return 0; }
    String getItemText() { return text != null ? text : ""; }
}
