package javax.microedition.lcdui;

public class Alert extends Screen {
    public static final int FOREVER = -2;
    public static final Command DISMISS_COMMAND = new Command("OK", Command.OK, 0);

    private String text;
    private Image image;
    private AlertType type;
    private int timeout = FOREVER;
    Displayable nextDisplayable;

    public Alert(String title) { this(title, null, null, null); }

    public Alert(String title, String alertText, Image alertImage, AlertType alertType) {
        setTitle(title);
        this.text = alertText;
        this.image = alertImage;
        this.type = alertType;
    }

    public String getString() { return text; }
    public void setString(String str) { this.text = str; }
    public Image getImage() { return image; }
    public void setImage(Image img) { this.image = img; }
    public AlertType getType() { return type; }
    public void setType(AlertType type) { this.type = type; }
    public int getTimeout() { return timeout; }
    public void setTimeout(int time) { this.timeout = time; }
    public int getDefaultTimeout() { return FOREVER; }
    public Indicator getIndicator() { return null; }
    public void setIndicator(Indicator indicator) { }

    public void showNative() {
        NativeBridge.formBegin(getTitle(), 2); // type 2 = alert
        NativeBridge.setAlertText(text != null ? text : "", timeout);
        java.util.ArrayList<Command> cmds = getCommands();
        if (cmds.isEmpty()) {
            NativeBridge.formAddCommand(DISMISS_COMMAND.getLabel(),
                    DISMISS_COMMAND.getCommandType(), DISMISS_COMMAND.getPriority(), 0);
        } else {
            for (int i = 0; i < cmds.size(); i++) {
                Command c = cmds.get(i);
                NativeBridge.formAddCommand(c.getLabel(), c.getCommandType(), c.getPriority(), i);
            }
        }
        NativeBridge.formShow();
    }
}
