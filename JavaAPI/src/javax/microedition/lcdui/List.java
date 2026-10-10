package javax.microedition.lcdui;

import java.util.ArrayList;

public class List extends Screen implements Choice {
    public static final int EXCLUSIVE = Choice.EXCLUSIVE;
    public static final int IMPLICIT = Choice.IMPLICIT;
    public static final int MULTIPLE = Choice.MULTIPLE;
    public static final Command SELECT_COMMAND = new Command("Select", Command.SCREEN, 0);

    private int listType;
    private ArrayList<String> strings = new ArrayList<String>();
    private ArrayList<Image> images = new ArrayList<Image>();
    private ArrayList<Boolean> selected = new ArrayList<Boolean>();
    private int selectedIndex = -1;
    private Command selectCommand = SELECT_COMMAND;

    public List(String title, int listType) {
        setTitle(title);
        this.listType = listType;
    }

    public List(String title, int listType, String[] stringElements, Image[] imageElements) {
        this(title, listType);
        if (stringElements != null) {
            for (int i = 0; i < stringElements.length; i++) {
                append(stringElements[i], imageElements != null && i < imageElements.length ? imageElements[i] : null);
            }
        }
    }

    public int append(String stringPart, Image imagePart) {
        strings.add(stringPart);
        images.add(imagePart);
        selected.add(Boolean.FALSE);
        if (selectedIndex < 0 && listType == EXCLUSIVE) selectedIndex = 0;
        return strings.size() - 1;
    }

    public void delete(int elementNum) { strings.remove(elementNum); images.remove(elementNum); selected.remove(elementNum); }
    public void deleteAll() { strings.clear(); images.clear(); selected.clear(); selectedIndex = -1; }
    public int getSelectedIndex() { return selectedIndex; }
    public String getString(int elementNum) { return strings.get(elementNum); }
    public Image getImage(int elementNum) { return images.get(elementNum); }
    public void insert(int elementNum, String stringPart, Image imagePart) {
        strings.add(elementNum, stringPart); images.add(elementNum, imagePart); selected.add(elementNum, Boolean.FALSE);
    }
    public boolean isSelected(int elementNum) { return selected.get(elementNum); }
    public void set(int elementNum, String stringPart, Image imagePart) {
        strings.set(elementNum, stringPart); images.set(elementNum, imagePart);
    }
    public void setSelectedIndex(int elementNum, boolean sel) {
        if (listType == EXCLUSIVE) { for (int i = 0; i < selected.size(); i++) selected.set(i, Boolean.FALSE); }
        selected.set(elementNum, sel);
        if (sel) selectedIndex = elementNum;
    }
    public int size() { return strings.size(); }
    public int getSelectedFlags(boolean[] a) { for (int i = 0; i < a.length && i < selected.size(); i++) a[i] = selected.get(i); return selected.size(); }
    public void setSelectedFlags(boolean[] a) { for (int i = 0; i < a.length && i < selected.size(); i++) selected.set(i, a[i]); }
    public int getFitPolicy() { return 0; }
    public void setFitPolicy(int p) { }
    public Font getFont(int i) { return Font.getDefaultFont(); }
    public void setFont(int i, Font f) { }
    public void setSelectCommand(Command cmd) { selectCommand = cmd; }

    public void showNative() {
        NativeBridge.formBegin(getTitle(), 1); // type 1 = list
        NativeBridge.setListType(listType);
        for (String s : strings) NativeBridge.listAddItem(s);
        ArrayList<Command> cmds = getCommands();
        for (int i = 0; i < cmds.size(); i++) {
            Command c = cmds.get(i);
            NativeBridge.formAddCommand(c.getLabel(), c.getCommandType(), c.getPriority(), i);
        }
        NativeBridge.formShow();
    }

    public void handleListSelect(int index) {
        if (index >= 0 && index < strings.size()) {
            selectedIndex = index;
            if (listType == IMPLICIT && getCommandListener() != null) {
                getCommandListener().commandAction(selectCommand, this);
            }
        }
    }
}
