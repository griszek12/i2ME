package javax.microedition.lcdui;

public interface Choice {
    int EXCLUSIVE = 1;
    int MULTIPLE = 2;
    int IMPLICIT = 3;
    int POPUP = 4;
    int TEXT_WRAP_DEFAULT = 0;
    int TEXT_WRAP_ON = 1;
    int TEXT_WRAP_OFF = 2;

    int append(String stringPart, Image imagePart);
    void delete(int elementNum);
    void deleteAll();
    int getSelectedIndex();
    String getString(int elementNum);
    void insert(int elementNum, String stringPart, Image imagePart);
    boolean isSelected(int elementNum);
    void set(int elementNum, String stringPart, Image imagePart);
    void setSelectedIndex(int elementNum, boolean selected);
    int size();
    int getSelectedFlags(boolean[] selectedArray);
    void setSelectedFlags(boolean[] selectedArray);
    int getFitPolicy();
    void setFitPolicy(int fitPolicy);
    Font getFont(int elementNum);
    void setFont(int elementNum, Font font);
    Image getImage(int elementNum);
}
