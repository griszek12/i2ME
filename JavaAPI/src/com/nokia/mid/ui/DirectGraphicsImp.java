/*
 *  Nokia API for MicroEmulator — Ported for iOS/miniJVM
 *  Removed android.util.Log. Replaced setColorAlpha with setColor.
 */
package com.nokia.mid.ui;

import javax.microedition.lcdui.Graphics;
import javax.microedition.lcdui.Image;
import javax.microedition.lcdui.game.Sprite;

public class DirectGraphicsImp implements DirectGraphics {
	private final Graphics graphics;
	private int alphaComponent;

	public DirectGraphicsImp(Graphics g) { graphics = g; }

	public void drawImage(Image img, int x, int y, int anchor, int manipulation) {
		if (img == null) throw new NullPointerException();
		int transform = getTransformation(manipulation);
		if (anchor >= 64 || transform == -1) throw new IllegalArgumentException();
		graphics.drawRegion(img, 0, 0, img.getWidth(), img.getHeight(), transform, x, y, anchor);
	}

	public void setARGBColor(int argb) {
		alphaComponent = (argb >> 24) & 0xFF;
		graphics.setColor(argb & 0x00FFFFFF);
	}

	public int getAlphaComponent() { return alphaComponent; }
	public int getNativePixelFormat() { return TYPE_INT_8888_ARGB; }

	public void drawPolygon(int[] xp, int xOff, int[] yp, int yOff, int n, int argb) {
		setARGBColor(argb);
		int[] x = new int[n], y = new int[n];
		System.arraycopy(xp, xOff, x, 0, n);
		System.arraycopy(yp, yOff, y, 0, n);
		graphics.drawPolygon(x, y, n);
	}

	public void drawTriangle(int x1, int y1, int x2, int y2, int x3, int y3, int argb) {
		drawPolygon(new int[]{x1,x2,x3}, 0, new int[]{y1,y2,y3}, 0, 3, argb);
	}

	public void fillPolygon(int[] xp, int xOff, int[] yp, int yOff, int n, int argb) {
		setARGBColor(argb);
		int[] x = new int[n], y = new int[n];
		System.arraycopy(xp, xOff, x, 0, n);
		System.arraycopy(yp, yOff, y, 0, n);
		graphics.fillPolygon(x, y, n);
	}

	public void fillTriangle(int x1, int y1, int x2, int y2, int x3, int y3, int argb) {
		fillPolygon(new int[]{x1,x2,x3}, 0, new int[]{y1,y2,y3}, 0, 3, argb);
	}

	public void drawPixels(byte[] pix, byte[] alpha, int off, int scanlen, int x, int y,
			int width, int height, int manipulation, int format) {
		if (pix == null) throw new NullPointerException();
		if (width <= 0 || height <= 0) return;
		int transform = getTransformation(manipulation);
		int[] pixres = new int[height * width];
		switch (format) {
			case TYPE_BYTE_1_GRAY: {
				int b = 7 - off % 8;
				for (int yj = 0; yj < height; yj++) {
					int line = off + yj * scanlen, ypos = yj * width;
					for (int xj = 0; xj < width; xj++) {
						pixres[ypos+xj] = doAlpha(pix, alpha, (line+xj)/8, b);
						if (--b < 0) b = 7;
					}
					b -= (scanlen - width) % 8;
					if (b < 0) b += 8;
				}
				break;
			}
			case TYPE_BYTE_1_GRAY_VERTICAL: {
				int ods = off/scanlen, oms = off%scanlen, b = ods%8;
				for (int yj = 0; yj < height; yj++) {
					int ypos = yj*width, tmp = (ods+yj)/8*scanlen+oms;
					for (int xj = 0; xj < width; xj++)
						pixres[ypos+xj] = doAlpha(pix, alpha, tmp+xj, b);
					if (++b > 7) b = 0;
				}
				break;
			}
			default: throw new IllegalArgumentException("Illegal format: " + format);
		}
		Image image = Image.createRGBImage(pixres, width, height, true);
		graphics.drawRegion(image, 0, 0, width, height, transform, x, y, 0);
	}

	public void drawPixels(short[] pix, boolean trans, int off, int scanlen,
			int x, int y, int width, int height, int manipulation, int format) {
		if (pix == null) throw new NullPointerException();
		if (width <= 0 || height <= 0) return;
		int transform = getTransformation(manipulation);
		int[] pixres = new int[height * width];
		switch (format) {
			case TYPE_USHORT_4444_ARGB:
				for (int iy = 0; iy < height; iy++)
					for (int ix = 0; ix < width; ix++) {
						short s = pix[off+ix+iy*scanlen];
						int v = ((s&0xF000)<<12)|((s&0x0F00)<<8)|((s&0x00F0)<<4)|(s&0x000F);
						pixres[iy*width+ix] = v | (v<<4);
					}
				break;
			case TYPE_USHORT_444_RGB:
				for (int iy = 0; iy < height; iy++)
					for (int ix = 0; ix < width; ix++) {
						short s = pix[off+ix+iy*scanlen];
						int rgb = ((s&0x0F00)<<8)|((s&0x00F0)<<4)|(s&0x000F);
						pixres[iy*width+ix] = 0xFF000000|rgb|(rgb<<4);
					}
				break;
			case TYPE_USHORT_565_RGB:
				for (int iy = 0; iy < height; iy++)
					for (int ix = 0; ix < width; ix++) {
						short s = pix[off+ix+iy*scanlen];
						int r = (s&0xF800)<<8|(s&0xE000)<<3;
						int g = (s&0x07E0)<<5|(s&0x0600)>>1;
						int b = (s&0x001F)<<3|(s&0x001C)>>2;
						pixres[iy*width+ix] = 0xFF000000|r|g|b;
					}
				break;
			default: throw new IllegalArgumentException("Illegal format: " + format);
		}
		Image image = Image.createRGBImage(pixres, width, height, true);
		graphics.drawRegion(image, 0, 0, width, height, transform, x, y, 0);
	}

	public void drawPixels(int[] pix, boolean trans, int off, int scanlen, int x, int y,
			int width, int height, int manipulation, int format) {
		if (pix == null) throw new NullPointerException();
		if (width <= 0 || height <= 0) return;
		int transform = getTransformation(manipulation);
		int[] pixres = new int[height * width];
		for (int iy = 0; iy < height; iy++)
			for (int ix = 0; ix < width; ix++) {
				int c = pix[off+ix+iy*scanlen];
				if (format == TYPE_INT_888_RGB) c |= 0xFF000000;
				pixres[iy*width+ix] = c;
			}
		Image image = Image.createRGBImage(pixres, width, height, true);
		graphics.drawRegion(image, 0, 0, width, height, transform, x, y, 0);
	}

	public void getPixels(byte[] pixels, byte[] mask, int offset, int scanLen,
			int x, int y, int width, int height, int format) {
		if (pixels == null) throw new NullPointerException();
		if (width <= 0 || height <= 0) return;
		if (format != TYPE_BYTE_1_GRAY) throw new IllegalArgumentException();
		int dataLen = height*scanLen-(scanLen-width);
		int[] colors = new int[width*height];
		graphics.getPixels(colors, 0, width, x, y, width, height);
		for (int i = offset, k = 0, w = 0, d = 0; d < dataLen; i++)
			for (int j = 7; j >= 0 && d < dataLen; j--, w++, d++) {
				if (w == scanLen) w = 0;
				if (w >= width) continue;
				int color = colors[k++];
				int alpha = color >>> 31;
				int gray = (((color&0x80)>>7)+((color&0x8000)>>15)+((color&0x800000)>>23))>>1;
				if (gray == 0 && alpha == 1) pixels[i] |= 1<<j; else pixels[i] &= ~(1<<j);
				if (mask != null) { if (alpha == 1) mask[i] |= 1<<j; else mask[i] &= ~(1<<j); }
			}
	}

	public void getPixels(short[] pix, int offset, int scanlen, int x, int y,
			int width, int height, int format) {
		if (pix == null) throw new NullPointerException();
		if (width <= 0 || height <= 0) return;
		int[] pixels = new int[width*height];
		graphics.getPixels(pixels, 0, width, x, y, width, height);
		switch (format) {
			case TYPE_USHORT_4444_ARGB:
				for (int iy = 0; iy < height; iy++)
					for (int ix = 0; ix < width; ix++) {
						int c = pixels[ix+iy*width];
						pix[offset+iy*scanlen+ix] = (short)((c>>16&0xF000)|(c>>12&0x0F00)|(c>>8&0x00F0)|(c>>4&0x000F));
					}
				break;
			case TYPE_USHORT_444_RGB:
				for (int iy = 0; iy < height; iy++)
					for (int ix = 0; ix < width; ix++) {
						int c = pixels[ix+iy*width];
						pix[offset+iy*scanlen+ix] = (short)(0xf000|(c>>12&0x0F00)|(c>>8&0x00F0)|(c>>4&0x000F));
					}
				break;
			case TYPE_USHORT_565_RGB:
				for (int iy = 0; iy < height; iy++)
					for (int ix = 0; ix < width; ix++) {
						int c = pixels[ix+iy*width];
						pix[offset+iy*scanlen+ix] = (short)((c>>8&0xF800)|(c>>5&0x07E0)|(c>>3&0x001F));
					}
				break;
			default: throw new IllegalArgumentException("Illegal format: " + format);
		}
	}

	public void getPixels(int[] pix, int offset, int scanlen, int x, int y,
			int width, int height, int format) {
		if (pix == null) throw new NullPointerException();
		if (width <= 0 || height <= 0) return;
		graphics.getPixels(pix, offset, scanlen, x, y, width, height);
		if (format == TYPE_INT_888_RGB)
			for (int iy = 0; iy < height; iy++)
				for (int ix = 0; ix < width; ix++)
					pix[offset+iy*scanlen+ix] |= 0xFF000000;
	}

	private static int doAlpha(byte[] pix, byte[] alpha, int pos, int shift) {
		int p = ((pix[pos] & (1<<shift)) != 0) ? 0 : 0x00FFFFFF;
		int a = (alpha == null || (alpha[pos] & (1<<shift)) != 0) ? 0xFF000000 : 0;
		return p | a;
	}

	private static int getTransformation(int manipulation) {
		int ret = -1, rotation = manipulation & 0x0FFF;
		boolean hFlip = (manipulation & FLIP_HORIZONTAL) != 0;
		boolean vFlip = (manipulation & FLIP_VERTICAL) != 0;
		if (hFlip && vFlip) {
			switch (rotation) {
				case 0: ret=Sprite.TRANS_ROT180; break; case ROTATE_90: ret=Sprite.TRANS_ROT90; break;
				case ROTATE_180: ret=Sprite.TRANS_NONE; break; case ROTATE_270: ret=Sprite.TRANS_ROT270; break;
			}
		} else if (hFlip) {
			switch (rotation) {
				case 0: ret=Sprite.TRANS_MIRROR; break; case ROTATE_90: ret=Sprite.TRANS_MIRROR_ROT90; break;
				case ROTATE_180: ret=Sprite.TRANS_MIRROR_ROT180; break; case ROTATE_270: ret=Sprite.TRANS_MIRROR_ROT270; break;
			}
		} else if (vFlip) {
			switch (rotation) {
				case 0: ret=Sprite.TRANS_MIRROR_ROT180; break; case ROTATE_90: ret=Sprite.TRANS_MIRROR_ROT270; break;
				case ROTATE_180: ret=Sprite.TRANS_MIRROR; break; case ROTATE_270: ret=Sprite.TRANS_MIRROR_ROT90; break;
			}
		} else {
			switch (rotation) {
				case 0: ret=Sprite.TRANS_NONE; break; case ROTATE_90: ret=Sprite.TRANS_ROT270; break;
				case ROTATE_180: ret=Sprite.TRANS_ROT180; break; case ROTATE_270: ret=Sprite.TRANS_ROT90; break;
			}
		}
		return ret;
	}
}
