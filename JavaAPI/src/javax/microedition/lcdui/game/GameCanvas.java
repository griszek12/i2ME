/*
 * Copyright 2017-2018 Nikita Shakarun
 * Licensed under the Apache License, Version 2.0
 * Ported for iOS/miniJVM — matches J2ME-Loader's GameCanvas structure.
 */
package javax.microedition.lcdui.game;

import javax.microedition.lcdui.Canvas;
import javax.microedition.lcdui.Graphics;
import javax.microedition.lcdui.Image;

public class GameCanvas extends Canvas {

	public static final int UP_PRESSED = 1 << Canvas.UP;
	public static final int DOWN_PRESSED = 1 << Canvas.DOWN;
	public static final int LEFT_PRESSED = 1 << Canvas.LEFT;
	public static final int RIGHT_PRESSED = 1 << Canvas.RIGHT;
	public static final int FIRE_PRESSED = 1 << Canvas.FIRE;
	public static final int GAME_A_PRESSED = 1 << Canvas.GAME_A;
	public static final int GAME_B_PRESSED = 1 << Canvas.GAME_B;
	public static final int GAME_C_PRESSED = 1 << Canvas.GAME_C;
	public static final int GAME_D_PRESSED = 1 << Canvas.GAME_D;

	private Image image;
	private int keyState;
	private final boolean suppressCommands;

	public GameCanvas(boolean suppressCommands) {
		super();
		this.suppressCommands = suppressCommands;
		image = Image.createImage(width, height);
	}

	@Override
	public void paint(Graphics g) {
		g.drawImage(image, 0, 0, Graphics.LEFT | Graphics.TOP);
	}

	private int convertGameKeyCode(int keyCode) {
		switch (keyCode) {
			case KEY_LEFT:
			case KEY_NUM4:
				return LEFT_PRESSED;
			case KEY_UP:
			case KEY_NUM2:
				return UP_PRESSED;
			case KEY_RIGHT:
			case KEY_NUM6:
				return RIGHT_PRESSED;
			case KEY_DOWN:
			case KEY_NUM8:
				return DOWN_PRESSED;
			case KEY_FIRE:
			case KEY_NUM5:
				return FIRE_PRESSED;
			case KEY_NUM7:
				return GAME_A_PRESSED;
			case KEY_NUM9:
				return GAME_B_PRESSED;
			case KEY_STAR:
				return GAME_C_PRESSED;
			case KEY_POUND:
				return GAME_D_PRESSED;
			default:
				return 0;
		}
	}

	@Override
	public void postKeyPressed(int keyCode) {
		int code = convertGameKeyCode(keyCode);
		if (code != 0) {
			keyState |= code;
			if (suppressCommands) {
				return;
			}
		}
		super.postKeyPressed(keyCode);
	}

	@Override
	public void postKeyReleased(int keyCode) {
		int code = convertGameKeyCode(keyCode);
		if (code != 0) {
			keyState &= ~code;
			if (suppressCommands) {
				return;
			}
		}
		super.postKeyReleased(keyCode);
	}

	@Override
	public void postKeyRepeated(int keyCode) {
		if (suppressCommands && convertGameKeyCode(keyCode) != 0) {
			return;
		}
		super.postKeyRepeated(keyCode);
	}

	public int getKeyStates() {
		return keyState;
	}

	public Graphics getGraphics() {
		if (image == null || image.getWidth() != width || image.getHeight() != height) {
			image = Image.createImage(width, height);
		}
		return image.getGraphics();
	}

	public void flushGraphics() {
		flushGraphics(0, 0, width, height);
	}

	public void flushGraphics(int x, int y, int width, int height) {
		flushBuffer(image, x, y, width, height);
	}

	@Override
	public void doShowNotify() {
		keyState = 0;
		super.doShowNotify();
	}
}
