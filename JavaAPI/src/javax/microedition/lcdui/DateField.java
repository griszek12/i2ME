package javax.microedition.lcdui;

import java.util.Date;
import java.util.TimeZone;

public class DateField extends Item {
    public static final int DATE = 1;
    public static final int TIME = 2;
    public static final int DATE_TIME = 3;

    private Date date;
    private int mode;

    public DateField(String label, int mode) { setLabel(label); this.mode = mode; }
    public DateField(String label, int mode, TimeZone timeZone) { this(label, mode); }
    public Date getDate() { return date; }
    public void setDate(Date date) { this.date = date; }
    public int getInputMode() { return mode; }
    public void setInputMode(int mode) { this.mode = mode; }

    int getItemType() { return 6; }
    String getItemText() { return date != null ? date.toString() : ""; }
}
