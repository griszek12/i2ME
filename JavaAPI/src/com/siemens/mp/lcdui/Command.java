package com.siemens.mp.lcdui;
public class Command extends javax.microedition.lcdui.Command {
    public Command(String label, int commandType, int priority) { super(label, commandType, priority); }
    public Command(int type, int prio) { super("", type, prio); }
}
