package javax.bluetooth;

import java.util.Hashtable;
import javax.microedition.io.Connection;

public class LocalDevice {
	private static LocalDevice dev;
	private DiscoveryAgent agent;
	private static Hashtable properties;

	static {
		properties = new Hashtable();
		properties.put("bluetooth.api.version", "1.1");
		properties.put("bluetooth.master.switch", "false");
		properties.put("bluetooth.sd.attr.retrievable.max", "256");
		properties.put("bluetooth.connected.devices.max", "7");
		properties.put("bluetooth.l2cap.receiveMTU.max", "672");
		properties.put("bluetooth.sd.trans.max", "1");
		properties.put("bluetooth.connected.inquiry.scan", "false");
		properties.put("bluetooth.connected.page.scan", "false");
		properties.put("bluetooth.connected.inquiry", "false");
		properties.put("bluetooth.connected.page", "false");
	}

	private LocalDevice() throws BluetoothStateException {
		agent = new DiscoveryAgent();
	}

	public static LocalDevice getLocalDevice() throws BluetoothStateException {
		// Bluetooth hardware is not available on this device
		throw new BluetoothStateException("Bluetooth is not available");
	}

	public DiscoveryAgent getDiscoveryAgent() { return agent; }

	public String getFriendlyName() { return "iOS Device"; }

	public DeviceClass getDeviceClass() { return new DeviceClass(); }

	public boolean setDiscoverable(int mode) throws BluetoothStateException {
		return false;
	}

	public int getDiscoverable() { return DiscoveryAgent.NOT_DISCOVERABLE; }

	public static String getProperty(String property) {
		return (String) properties.get(property);
	}

	public static boolean isPowerOn() { return false; }

	public String getBluetoothAddress() { return "000000000000"; }

	public ServiceRecord getRecord(Connection notifier) {
		throw new IllegalArgumentException("Bluetooth not supported");
	}

	public void updateRecord(ServiceRecord srvRecord) { }
}
