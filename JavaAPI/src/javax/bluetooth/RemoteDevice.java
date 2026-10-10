package javax.bluetooth;

import java.io.IOException;
import javax.microedition.io.Connection;

public class RemoteDevice {
	private String address;

	protected RemoteDevice(String address) {
		if (address == null) throw new NullPointerException("address is null");
		this.address = address.replace(":", "").toUpperCase();
	}

	public String getFriendlyName(boolean alwaysAsk) throws IOException {
		return address;
	}

	public final String getBluetoothAddress() {
		return address;
	}

	public boolean equals(Object obj) {
		if (obj == null || !(obj instanceof RemoteDevice)) return false;
		return address.equals(((RemoteDevice) obj).address);
	}

	public int hashCode() { return address.hashCode(); }

	public static RemoteDevice getRemoteDevice(Connection conn) throws IOException {
		throw new IOException("Bluetooth not supported");
	}

	public boolean authenticate() throws IOException { return false; }
	public boolean authorize(Connection conn) throws IOException { return false; }
	public boolean encrypt(Connection conn, boolean on) throws IOException { return false; }
	public boolean isAuthenticated() { return false; }
	public boolean isAuthorized(Connection conn) throws IOException { return false; }
	public boolean isEncrypted() { return false; }
	public boolean isTrustedDevice() { return false; }
}
