package javax.microedition.lcdui;

import java.util.ArrayList;

public class ChoiceGroup extends Item implements Choice {
    private int choiceType;
    private ArrayList<String> strings = new ArrayList<String>();
    private ArrayList<Image> images = new ArrayList<Image>();
    private ArrayList<Boolean> selected = new ArrayList<Boolean>();

    public ChoiceGroup(String label, int choiceType) { setLabel(label); this.choiceType = choiceType; }
    public ChoiceGroup(String label, int choiceType, String[] stringElements, Image[] imageElements) {
        this(label, choiceType);
        if (stringElements != null) for (int i = 0; i < stringElements.length; i++)
            append(stringElements[i], imageElements != null && i < imageElements.length ? imageElements[i] : null);
    }

    public int append(String s, Image img) { strings.add(s); images.add(img); selected.add(Boolean.FALSE); return strings.size()-1; }
    public void delete(int i) { strings.remove(i); images.remove(i); selected.remove(i); }
    public void deleteAll() { strings.clear(); images.clear(); selected.clear(); }
    public int getSelectedIndex() { for (int i=0;i<selected.size();i++) if (selected.get(i)) return i; return -1; }
    public String getString(int i) { return strings.get(i); }
    public Image getImage(int i) { return images.get(i); }
    public void insert(int i, String s, Image img) { strings.add(i,s); images.add(i,img); selected.add(i,Boolean.FALSE); }
    public boolean isSelected(int i) { return selected.get(i); }
    public void set(int i, String s, Image img) { strings.set(i,s); images.set(i,img); }
    public void setSelectedIndex(int i, boolean s) {
        if (choiceType==EXCLUSIVE) for (int j=0;j<selected.size();j++) selected.set(j,Boolean.FALSE);
        selected.set(i,s);
    }
    public int size() { return strings.size(); }
    public int getSelectedFlags(boolean[] a) { for(int i=0;i<a.length&&i<selected.size();i++) a[i]=selected.get(i); return selected.size(); }
    public void setSelectedFlags(boolean[] a) { for(int i=0;i<a.length&&i<selected.size();i++) selected.set(i,a[i]); }
    public int getFitPolicy() { return 0; }
    public void setFitPolicy(int p) {}
    public Font getFont(int i) { return Font.getDefaultFont(); }
    public void setFont(int i, Font f) {}

    int getItemType() { return 2; }
    String getItemText() { return strings.size()>0?strings.get(getSelectedIndex()>=0?getSelectedIndex():0):""; }
}
