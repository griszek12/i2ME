package javax.bluetooth;

import java.io.IOException;
import javax.microedition.io.Connection;

public interface L2CAPConnection extends Connection {
	public static final int DEFAULT_MTU = 672;
	public static final int MINIMUM_MTU = 48;

	public int getTransmitMTU() throws IOException;
	public int getReceiveMTU() throws IOException;
	public void send(byte[] data) throws IOException;
	public int receive(byte[] inBuf) throws IOException;
	public boolean ready() throws IOException;
}
