package javax.microedition.lcdui;

import java.util.ArrayList;

/**
 * Base class for all J2ME UI screens.
 */
public abstract class Displayable {
    private String title;
    public int width = 240;
    public int height = 320;
    private ArrayList<Command> commands = new ArrayList<Command>();
    private CommandListener commandListener;
    private Ticker ticker;

    public void setTitle(String title) { this.title = title; }
    public String getTitle() { return title != null ? title : ""; }

    public int getWidth() { return width; }
    public int getHeight() { return height; }

    public void addCommand(Command cmd) {
        if (cmd != null && !commands.contains(cmd)) commands.add(cmd);
    }

    public void removeCommand(Command cmd) { commands.remove(cmd); }

    public void setCommandListener(CommandListener listener) {
        this.commandListener = listener;
    }

    public ArrayList<Command> getCommands() { return commands; }
    public CommandListener getCommandListener() { return commandListener; }

    public void setTicker(Ticker ticker) { this.ticker = ticker; }
    public Ticker getTicker() { return ticker; }

    public boolean isShown() {
        Display d = Display.getDisplay(null);
        return d != null && d.getCurrent() == this;
    }

    protected void sizeChanged(int w, int h) { }

    /** Fire command action. Called from Display event loop when a command event is received. */
    public void fireCommandAction(int commandIndex) {
        if (commandListener != null && commandIndex >= 0 && commandIndex < commands.size()) {
            commandListener.commandAction(commands.get(commandIndex), this);
        }
    }
}
