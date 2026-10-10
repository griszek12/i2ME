package com.kddi.media;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;

import javax.microedition.media.Manager;
import javax.microedition.media.MediaException;
import javax.microedition.media.Player;

public class MediaResource {
	private Player player;
	private String type;

	public Player _getPlayer() { return this.player; }

	public MediaResource(String url) {
		this.player = null;
		this.type = "devm39z";
		// Resource loading stub — MMFConverter not ported
	}

	public MediaResource(byte[] resource, String disposition) {
		this.player = null;
		this.type = disposition;
		// MMFConverter not ported — stub
	}

	public MediaPlayerBox[] getPlayer() { return new MediaPlayerBox[]{}; }
	public String getType() { return this.type; }

	public void dispose() {
		if (this.player != null) { this.player.close(); this.player = null; }
	}
}
