package com.vodafone.util;

import javax.microedition.lcdui.Image;

/** Stub — image encoding not implemented on iOS */
public class ImageEncoder {
	public static final int FORMAT_PNG = 0;
	public static final int FORMAT_JPEG = 1;

	public static byte[] encode(Image image, int format) {
		return new byte[0]; // stub
	}
}
