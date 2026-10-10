package com.nokia.mid.ui;
public class SoftNotificationImpl extends SoftNotification {
    private int id;
    SoftNotificationImpl() { }
    SoftNotificationImpl(int id) { this.id = id; }
    public int getId() { return id; }
    public void post() throws SoftNotificationException { }
    public void remove() throws SoftNotificationException { }
    public void setText(String text, String groupText) { }
    public void setImage(byte[] data) { }
    public void setSoftKeys(String left, String right) { }
    public void setSoftkeyLabels(String left, String right) { }
    public void setListener(SoftNotificationListener l) { }
}
