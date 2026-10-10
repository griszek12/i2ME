/*
 *  Nokia API — Ported for iOS/miniJVM
 *  Replaced Android Bitmap with our Image API.
 */
package com.nokia.mid.ui;

import javax.microedition.lcdui.Displayable;
import javax.microedition.lcdui.Font;
import javax.microedition.lcdui.Graphics;
import javax.microedition.lcdui.Image;

public class DirectUtils {

	public static DirectGraphics getDirectGraphics(Graphics g) {
		return new DirectGraphicsImp(g);
	}

	public static Image createImage(byte[] imageData, int imageOffset, int imageLength) {
		// Create mutable image from encoded data (Nokia extension)
		Image immutable = Image.createImage(imageData, imageOffset, imageLength);
		// Make mutable copy
		Image mutable = Image.createImage(immutable.getWidth(), immutable.getHeight());
		Graphics g = mutable.getGraphics();
		g.drawImage(immutable, 0, 0, Graphics.LEFT | Graphics.TOP);
		return mutable;
	}

	public static Image createImage(int width, int height, int argb) {
		Image img = Image.createImage(width, height);
		Graphics g = img.getGraphics();
		g.setColor(argb & 0x00FFFFFF);
		g.fillRect(0, 0, width, height);
		return img;
	}

	public static Font getFont(int identifier) {
		switch (identifier) {
			case 1: return Font.getFont(Font.FACE_SYSTEM, Font.STYLE_PLAIN, Font.SIZE_SMALL);
			case 2: return Font.getFont(Font.FACE_SYSTEM, Font.STYLE_PLAIN, Font.SIZE_MEDIUM);
			case 3: return Font.getFont(Font.FACE_SYSTEM, Font.STYLE_PLAIN, Font.SIZE_LARGE);
			case 4: return Font.getFont(Font.FACE_SYSTEM, Font.STYLE_BOLD, Font.SIZE_MEDIUM);
			default: return Font.getDefaultFont();
		}
	}

	public static Font getFont(int face, int style, int height) {
		// FreeSizeFont — return closest match
		if (height <= 12) return Font.getFont(face, style, Font.SIZE_SMALL);
		if (height <= 16) return Font.getFont(face, style, Font.SIZE_MEDIUM);
		return Font.getFont(face, style, Font.SIZE_LARGE);
	}

	public static boolean setHeader(Displayable d, String text, Image img,
			int textColor, int bgColor, int divColor) {
		return false; // stub
	}
}
