package com.samsung.util;

public class Vibration {
	public static void start(int duration, int strength) {
		javax.microedition.lcdui.NativeBridge.vibrate(duration * 1000);
	}
	public static void stop() {
		javax.microedition.lcdui.NativeBridge.vibrate(0);
	}
	public static boolean isSupported() { return true; }
}
