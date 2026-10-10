package javax.microedition.lcdui;

public class TextField extends Item {
    public static final int ANY = 0;
    public static final int EMAILADDR = 1;
    public static final int NUMERIC = 2;
    public static final int PHONENUMBER = 3;
    public static final int URL = 4;
    public static final int DECIMAL = 5;
    public static final int PASSWORD = 0x10000;
    public static final int UNEDITABLE = 0x20000;
    public static final int SENSITIVE = 0x40000;
    public static final int NON_PREDICTIVE = 0x80000;
    public static final int INITIAL_CAPS_WORD = 0x100000;
    public static final int INITIAL_CAPS_SENTENCE = 0x200000;
    public static final int CONSTRAINT_MASK = 0xFFFF;

    private String text;
    private int maxSize;
    private int constraints;

    public TextField(String label, String text, int maxSize, int constraints) {
        setLabel(label);
        this.text = text != null ? text : "";
        this.maxSize = maxSize;
        this.constraints = constraints;
    }

    public String getString() { return text; }
    public void setString(String text) { this.text = text != null ? text : ""; }
    public int getMaxSize() { return maxSize; }
    public int setMaxSize(int maxSize) { this.maxSize = maxSize; return maxSize; }
    public int getConstraints() { return constraints; }
    public void setConstraints(int constraints) { this.constraints = constraints; }
    public int size() { return text.length(); }
    public void insert(String src, int position) { /* stub */ }
    public void delete(int offset, int length) { /* stub */ }
    public int getCaretPosition() { return text.length(); }
    public void setInitialInputMode(String characterSubset) { }

    int getItemType() { return 1; }
    String getItemText() { return text; }
}
