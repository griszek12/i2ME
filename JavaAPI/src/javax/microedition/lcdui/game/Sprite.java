/*
 * Copyright 2018 Nikita Shakarun
 * Licensed under the Apache License, Version 2.0
 * Ported for iOS/miniJVM — removed android.graphics.Matrix dependency.
 */
package javax.microedition.lcdui.game;

import javax.microedition.lcdui.Graphics;
import javax.microedition.lcdui.Image;

public class Sprite extends Layer {
	public static final int TRANS_NONE = 0;
	public static final int TRANS_ROT90 = 5;
	public static final int TRANS_ROT180 = 3;
	public static final int TRANS_ROT270 = 6;
	public static final int TRANS_MIRROR = 2;
	public static final int TRANS_MIRROR_ROT90 = 7;
	public static final int TRANS_MIRROR_ROT180 = 1;
	public static final int TRANS_MIRROR_ROT270 = 4;

	private static final int INVERTED_AXES = 0x4;
	private static final int X_FLIP = 0x2;
	private static final int Y_FLIP = 0x1;
	private static final int ALPHA_BITMASK = 0xff000000;
	private static final int FULLY_OPAQUE_ALPHA = 0xff000000;

	Image sourceImage;
	int numberFrames;
	int[] frameCoordsX;
	int[] frameCoordsY;
	int srcFrameWidth;
	int srcFrameHeight;
	int[] frameSequence;
	private int sequenceIndex;
	private boolean customSequenceDefined;
	int dRefX;
	int dRefY;
	int collisionRectX;
	int collisionRectY;
	int collisionRectWidth;
	int collisionRectHeight;
	int t_currentTransformation;
	int t_collisionRectX;
	int t_collisionRectY;
	int t_collisionRectWidth;
	int t_collisionRectHeight;

	public Sprite(Image image) {
		super(image.getWidth(), image.getHeight());
		initializeFrames(image, image.getWidth(), image.getHeight(), false);
		initCollisionRectBounds();
		setTransformImpl(TRANS_NONE);
	}

	public Sprite(Image image, int frameWidth, int frameHeight) {
		super(frameWidth, frameHeight);
		if ((frameWidth < 1 || frameHeight < 1) ||
				((image.getWidth() % frameWidth) != 0) ||
				((image.getHeight() % frameHeight) != 0))
			throw new IllegalArgumentException();
		initializeFrames(image, frameWidth, frameHeight, false);
		initCollisionRectBounds();
		setTransformImpl(TRANS_NONE);
	}

	public Sprite(Sprite s) {
		super(s != null ? s.getWidth() : 0, s != null ? s.getHeight() : 0);
		if (s == null) throw new NullPointerException();
		this.sourceImage = Image.createImage(s.sourceImage);
		this.numberFrames = s.numberFrames;
		this.frameCoordsX = new int[this.numberFrames];
		this.frameCoordsY = new int[this.numberFrames];
		System.arraycopy(s.frameCoordsX, 0, this.frameCoordsX, 0, s.getRawFrameCount());
		System.arraycopy(s.frameCoordsY, 0, this.frameCoordsY, 0, s.getRawFrameCount());
		this.x = s.getX(); this.y = s.getY();
		this.dRefX = s.dRefX; this.dRefY = s.dRefY;
		this.collisionRectX = s.collisionRectX; this.collisionRectY = s.collisionRectY;
		this.collisionRectWidth = s.collisionRectWidth; this.collisionRectHeight = s.collisionRectHeight;
		this.srcFrameWidth = s.srcFrameWidth; this.srcFrameHeight = s.srcFrameHeight;
		setTransformImpl(s.t_currentTransformation);
		this.setVisible(s.isVisible());
		this.frameSequence = new int[s.getFrameSequenceLength()];
		this.setFrameSequence(s.frameSequence);
		this.setFrame(s.getFrame());
		this.setRefPixelPosition(s.getRefPixelX(), s.getRefPixelY());
	}

	public void defineReferencePixel(int inp_x, int inp_y) { dRefX = inp_x; dRefY = inp_y; }

	public void setRefPixelPosition(int inp_x, int inp_y) {
		x = inp_x - getTransformedPtX(dRefX, dRefY, t_currentTransformation);
		y = inp_y - getTransformedPtY(dRefX, dRefY, t_currentTransformation);
	}

	public int getRefPixelX() { return x + getTransformedPtX(dRefX, dRefY, t_currentTransformation); }
	public int getRefPixelY() { return y + getTransformedPtY(dRefX, dRefY, t_currentTransformation); }

	public void setFrame(int inp_sequenceIndex) {
		if (inp_sequenceIndex < 0 || inp_sequenceIndex >= frameSequence.length)
			throw new IndexOutOfBoundsException();
		sequenceIndex = inp_sequenceIndex;
	}

	public final int getFrame() { return sequenceIndex; }
	public int getRawFrameCount() { return numberFrames; }
	public int getFrameSequenceLength() { return frameSequence.length; }
	public void nextFrame() { sequenceIndex = (sequenceIndex + 1) % frameSequence.length; }

	public void prevFrame() {
		if (sequenceIndex == 0) sequenceIndex = frameSequence.length - 1;
		else sequenceIndex--;
	}

	public final void paint(Graphics g) {
		if (g == null) throw new NullPointerException();
		if (visible) {
			g.drawRegion(sourceImage,
					frameCoordsX[frameSequence[sequenceIndex]],
					frameCoordsY[frameSequence[sequenceIndex]],
					srcFrameWidth, srcFrameHeight,
					t_currentTransformation, this.x, this.y,
					Graphics.TOP | Graphics.LEFT);
		}
	}

	public void setFrameSequence(int sequence[]) {
		if (sequence == null) {
			sequenceIndex = 0; customSequenceDefined = false;
			frameSequence = new int[numberFrames];
			for (int i = 0; i < numberFrames; i++) frameSequence[i] = i;
			return;
		}
		if (sequence.length < 1) throw new IllegalArgumentException();
		for (int v : sequence)
			if (v < 0 || v >= numberFrames) throw new ArrayIndexOutOfBoundsException();
		customSequenceDefined = true;
		frameSequence = new int[sequence.length];
		System.arraycopy(sequence, 0, frameSequence, 0, sequence.length);
		sequenceIndex = 0;
	}

	public void setImage(Image img, int frameWidth, int frameHeight) {
		if ((frameWidth < 1 || frameHeight < 1) ||
				((img.getWidth() % frameWidth) != 0) || ((img.getHeight() % frameHeight) != 0))
			throw new IllegalArgumentException();
		int noOfFrames = (img.getWidth() / frameWidth) * (img.getHeight() / frameHeight);
		boolean maintainCurFrame = true;
		if (noOfFrames < numberFrames) { maintainCurFrame = false; customSequenceDefined = false; }
		if (!((srcFrameWidth == frameWidth) && (srcFrameHeight == frameHeight))) {
			int oldX = this.x + getTransformedPtX(dRefX, dRefY, t_currentTransformation);
			int oldY = this.y + getTransformedPtY(dRefX, dRefY, t_currentTransformation);
			setWidthImpl(frameWidth); setHeightImpl(frameHeight);
			initializeFrames(img, frameWidth, frameHeight, maintainCurFrame);
			initCollisionRectBounds();
			this.x = oldX - getTransformedPtX(dRefX, dRefY, t_currentTransformation);
			this.y = oldY - getTransformedPtY(dRefX, dRefY, t_currentTransformation);
			computeTransformedBounds(t_currentTransformation);
		} else {
			initializeFrames(img, frameWidth, frameHeight, maintainCurFrame);
		}
	}

	public void defineCollisionRectangle(int inp_x, int inp_y, int width, int height) {
		if (width < 0 || height < 0) throw new IllegalArgumentException();
		collisionRectX = inp_x; collisionRectY = inp_y;
		collisionRectWidth = width; collisionRectHeight = height;
		setTransformImpl(t_currentTransformation);
	}

	public void setTransform(int transform) { setTransformImpl(transform); }

	public final boolean collidesWith(Sprite s, boolean pixelLevel) {
		if (!(s.visible && this.visible)) return false;
		int otherLeft = s.x + s.t_collisionRectX;
		int otherTop = s.y + s.t_collisionRectY;
		int otherRight = otherLeft + s.t_collisionRectWidth;
		int otherBottom = otherTop + s.t_collisionRectHeight;
		int left = this.x + this.t_collisionRectX;
		int top = this.y + this.t_collisionRectY;
		int right = left + this.t_collisionRectWidth;
		int bottom = top + this.t_collisionRectHeight;
		if (intersectRect(otherLeft, otherTop, otherRight, otherBottom, left, top, right, bottom)) {
			if (pixelLevel) {
				if (t_collisionRectX < 0) left = this.x;
				if (t_collisionRectY < 0) top = this.y;
				if (t_collisionRectX + t_collisionRectWidth > width) right = this.x + width;
				if (t_collisionRectY + t_collisionRectHeight > height) bottom = this.y + height;
				if (s.t_collisionRectX < 0) otherLeft = s.x;
				if (s.t_collisionRectY < 0) otherTop = s.y;
				if (s.t_collisionRectX + s.t_collisionRectWidth > s.width) otherRight = s.x + s.width;
				if (s.t_collisionRectY + s.t_collisionRectHeight > s.height) otherBottom = s.y + s.height;
				if (!intersectRect(otherLeft, otherTop, otherRight, otherBottom, left, top, right, bottom))
					return false;
				int iLeft = Math.max(left, otherLeft), iTop = Math.max(top, otherTop);
				int iRight = Math.min(right, otherRight), iBottom = Math.min(bottom, otherBottom);
				int iw = Math.abs(iRight - iLeft), ih = Math.abs(iBottom - iTop);
				if (iw <= 0 || ih <= 0) return false;
				return doPixelCollision(
						getImageTopLeftX(iLeft, iTop, iRight, iBottom),
						getImageTopLeftY(iLeft, iTop, iRight, iBottom),
						s.getImageTopLeftX(iLeft, iTop, iRight, iBottom),
						s.getImageTopLeftY(iLeft, iTop, iRight, iBottom),
						this.sourceImage, this.t_currentTransformation,
						s.sourceImage, s.t_currentTransformation, iw, ih);
			}
			return true;
		}
		return false;
	}

	public final boolean collidesWith(TiledLayer t, boolean pixelLevel) {
		if (!(t.visible && this.visible)) return false;
		int tLx1 = t.x, tLy1 = t.y, tLx2 = tLx1 + t.width, tLy2 = tLy1 + t.height;
		int tW = t.getCellWidth(), tH = t.getCellHeight();
		int sx1 = this.x + this.t_collisionRectX;
		int sy1 = this.y + this.t_collisionRectY;
		int sx2 = sx1 + this.t_collisionRectWidth;
		int sy2 = sy1 + this.t_collisionRectHeight;
		if (!intersectRect(tLx1, tLy1, tLx2, tLy2, sx1, sy1, sx2, sy2)) return false;
		int startCol = (sx1 <= tLx1) ? 0 : (sx1 - tLx1) / tW;
		int startRow = (sy1 <= tLy1) ? 0 : (sy1 - tLy1) / tH;
		int endCol = (sx2 < tLx2) ? ((sx2 - 1 - tLx1) / tW) : t.getColumns() - 1;
		int endRow = (sy2 < tLy2) ? ((sy2 - 1 - tLy1) / tH) : t.getRows() - 1;
		for (int row = startRow; row <= endRow; row++)
			for (int col = startCol; col <= endCol; col++)
				if (t.getCell(col, row) != 0) return true;
		return false;
	}

	public final boolean collidesWith(Image image, int inp_x, int inp_y, boolean pixelLevel) {
		if (!visible) return false;
		int otherRight = inp_x + image.getWidth(), otherBottom = inp_y + image.getHeight();
		int left = x + t_collisionRectX, top = y + t_collisionRectY;
		int right = left + t_collisionRectWidth, bottom = top + t_collisionRectHeight;
		return intersectRect(inp_x, inp_y, otherRight, otherBottom, left, top, right, bottom);
	}

	// --- Internal methods ---

	private void initializeFrames(Image image, int fWidth, int fHeight, boolean maintainCurFrame) {
		int numH = image.getWidth() / fWidth, numV = image.getHeight() / fHeight;
		sourceImage = image; srcFrameWidth = fWidth; srcFrameHeight = fHeight;
		numberFrames = numH * numV;
		frameCoordsX = new int[numberFrames]; frameCoordsY = new int[numberFrames];
		if (!maintainCurFrame) sequenceIndex = 0;
		if (!customSequenceDefined) frameSequence = new int[numberFrames];
		int cur = 0;
		for (int yy = 0; yy < image.getHeight(); yy += fHeight)
			for (int xx = 0; xx < image.getWidth(); xx += fWidth) {
				frameCoordsX[cur] = xx; frameCoordsY[cur] = yy;
				if (!customSequenceDefined) frameSequence[cur] = cur;
				cur++;
			}
	}

	private void initCollisionRectBounds() {
		collisionRectX = 0; collisionRectY = 0;
		collisionRectWidth = this.width; collisionRectHeight = this.height;
	}

	private boolean intersectRect(int r1x1, int r1y1, int r1x2, int r1y2,
								  int r2x1, int r2y1, int r2x2, int r2y2) {
		return !(r2x1 >= r1x2 || r2y1 >= r1y2 || r2x2 <= r1x1 || r2y2 <= r1y1);
	}

	private void setTransformImpl(int transform) {
		this.x = this.x + getTransformedPtX(dRefX, dRefY, this.t_currentTransformation)
				- getTransformedPtX(dRefX, dRefY, transform);
		this.y = this.y + getTransformedPtY(dRefX, dRefY, this.t_currentTransformation)
				- getTransformedPtY(dRefX, dRefY, transform);
		computeTransformedBounds(transform);
		t_currentTransformation = transform;
	}

	private int getImageTopLeftX(int x1, int y1, int x2, int y2) {
		int retX = 0;
		switch (t_currentTransformation) {
			case TRANS_NONE: case TRANS_MIRROR_ROT180: retX = x1 - this.x; break;
			case TRANS_MIRROR: case TRANS_ROT180: retX = (this.x + this.width) - x2; break;
			case TRANS_ROT90: case TRANS_MIRROR_ROT270: retX = y1 - this.y; break;
			case TRANS_ROT270: case TRANS_MIRROR_ROT90: retX = (this.y + this.height) - y2; break;
		}
		return retX + frameCoordsX[frameSequence[sequenceIndex]];
	}

	private int getImageTopLeftY(int x1, int y1, int x2, int y2) {
		int retY = 0;
		switch (t_currentTransformation) {
			case TRANS_NONE: case TRANS_MIRROR: retY = y1 - this.y; break;
			case TRANS_ROT180: case TRANS_MIRROR_ROT180: retY = (this.y + this.height) - y2; break;
			case TRANS_ROT270: case TRANS_MIRROR_ROT270: retY = x1 - this.x; break;
			case TRANS_ROT90: case TRANS_MIRROR_ROT90: retY = (this.x + this.width) - x2; break;
		}
		return retY + frameCoordsY[frameSequence[sequenceIndex]];
	}

	private static boolean doPixelCollision(
			int img1XOff, int img1YOff, int img2XOff, int img2YOff,
			Image image1, int transform1, Image image2, int transform2,
			int width, int height) {
		int numPixels = height * width;
		int[] argb1 = new int[numPixels], argb2 = new int[numPixels];

		int startY1, xIncr1, yIncr1;
		if ((transform1 & INVERTED_AXES) != 0) {
			if ((transform1 & Y_FLIP) != 0) { xIncr1 = -height; startY1 = numPixels - height; }
			else { xIncr1 = height; startY1 = 0; }
			if ((transform1 & X_FLIP) != 0) { yIncr1 = -1; startY1 += height - 1; }
			else { yIncr1 = 1; }
			image1.getRGB(argb1, 0, height, img1XOff, img1YOff, height, width);
		} else {
			if ((transform1 & Y_FLIP) != 0) { startY1 = numPixels - width; yIncr1 = -width; }
			else { startY1 = 0; yIncr1 = width; }
			if ((transform1 & X_FLIP) != 0) { xIncr1 = -1; startY1 += width - 1; }
			else { xIncr1 = 1; }
			image1.getRGB(argb1, 0, width, img1XOff, img1YOff, width, height);
		}

		int startY2, xIncr2, yIncr2;
		if ((transform2 & INVERTED_AXES) != 0) {
			if ((transform2 & Y_FLIP) != 0) { xIncr2 = -height; startY2 = numPixels - height; }
			else { xIncr2 = height; startY2 = 0; }
			if ((transform2 & X_FLIP) != 0) { yIncr2 = -1; startY2 += height - 1; }
			else { yIncr2 = 1; }
			image2.getRGB(argb2, 0, height, img2XOff, img2YOff, height, width);
		} else {
			if ((transform2 & Y_FLIP) != 0) { startY2 = numPixels - width; yIncr2 = -width; }
			else { startY2 = 0; yIncr2 = width; }
			if ((transform2 & X_FLIP) != 0) { xIncr2 = -1; startY2 += width - 1; }
			else { xIncr2 = 1; }
			image2.getRGB(argb2, 0, width, img2XOff, img2YOff, width, height);
		}

		for (int row = 0, xb1 = startY1, xb2 = startY2; row < height;
				xb1 += yIncr1, xb2 += yIncr2, row++) {
			for (int col = 0, p1 = xb1, p2 = xb2; col < width;
					p1 += xIncr1, p2 += xIncr2, col++) {
				if ((argb1[p1] & 0xff000000) == 0xff000000 &&
					(argb2[p2] & 0xff000000) == 0xff000000)
					return true;
			}
		}
		return false;
	}

	private void computeTransformedBounds(int transform) {
		switch (transform) {
			case TRANS_NONE:
				t_collisionRectX = collisionRectX; t_collisionRectY = collisionRectY;
				t_collisionRectWidth = collisionRectWidth; t_collisionRectHeight = collisionRectHeight;
				this.width = srcFrameWidth; this.height = srcFrameHeight; break;
			case TRANS_MIRROR:
				t_collisionRectX = srcFrameWidth - (collisionRectX + collisionRectWidth);
				t_collisionRectY = collisionRectY;
				t_collisionRectWidth = collisionRectWidth; t_collisionRectHeight = collisionRectHeight;
				this.width = srcFrameWidth; this.height = srcFrameHeight; break;
			case TRANS_MIRROR_ROT180:
				t_collisionRectY = srcFrameHeight - (collisionRectY + collisionRectHeight);
				t_collisionRectX = collisionRectX;
				t_collisionRectWidth = collisionRectWidth; t_collisionRectHeight = collisionRectHeight;
				this.width = srcFrameWidth; this.height = srcFrameHeight; break;
			case TRANS_ROT90:
				t_collisionRectX = srcFrameHeight - (collisionRectHeight + collisionRectY);
				t_collisionRectY = collisionRectX;
				t_collisionRectHeight = collisionRectWidth; t_collisionRectWidth = collisionRectHeight;
				this.width = srcFrameHeight; this.height = srcFrameWidth; break;
			case TRANS_ROT180:
				t_collisionRectX = srcFrameWidth - (collisionRectWidth + collisionRectX);
				t_collisionRectY = srcFrameHeight - (collisionRectHeight + collisionRectY);
				t_collisionRectWidth = collisionRectWidth; t_collisionRectHeight = collisionRectHeight;
				this.width = srcFrameWidth; this.height = srcFrameHeight; break;
			case TRANS_ROT270:
				t_collisionRectX = collisionRectY;
				t_collisionRectY = srcFrameWidth - (collisionRectWidth + collisionRectX);
				t_collisionRectHeight = collisionRectWidth; t_collisionRectWidth = collisionRectHeight;
				this.width = srcFrameHeight; this.height = srcFrameWidth; break;
			case TRANS_MIRROR_ROT90:
				t_collisionRectX = srcFrameHeight - (collisionRectHeight + collisionRectY);
				t_collisionRectY = srcFrameWidth - (collisionRectWidth + collisionRectX);
				t_collisionRectHeight = collisionRectWidth; t_collisionRectWidth = collisionRectHeight;
				this.width = srcFrameHeight; this.height = srcFrameWidth; break;
			case TRANS_MIRROR_ROT270:
				t_collisionRectY = collisionRectX; t_collisionRectX = collisionRectY;
				t_collisionRectHeight = collisionRectWidth; t_collisionRectWidth = collisionRectHeight;
				this.width = srcFrameHeight; this.height = srcFrameWidth; break;
			default: throw new IllegalArgumentException();
		}
	}

	private int getTransformedPtX(int inp_x, int inp_y, int transform) {
		switch (transform) {
			case TRANS_NONE: case TRANS_MIRROR_ROT180: return inp_x;
			case TRANS_MIRROR: case TRANS_ROT180: return srcFrameWidth - inp_x - 1;
			case TRANS_ROT90: case TRANS_MIRROR_ROT90: return srcFrameHeight - inp_y - 1;
			case TRANS_ROT270: case TRANS_MIRROR_ROT270: return inp_y;
			default: return 0;
		}
	}

	private int getTransformedPtY(int inp_x, int inp_y, int transform) {
		switch (transform) {
			case TRANS_NONE: case TRANS_MIRROR: return inp_y;
			case TRANS_MIRROR_ROT180: case TRANS_ROT180: return srcFrameHeight - inp_y - 1;
			case TRANS_ROT90: case TRANS_MIRROR_ROT90: return srcFrameWidth - inp_x - 1;
			case TRANS_ROT270: case TRANS_MIRROR_ROT270: return inp_x;
			default: return 0;
		}
	}
}
