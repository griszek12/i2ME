package javax.microedition.io.file;

import java.util.Enumeration;
import java.util.Vector;

/**
 * FileSystemRegistry stub — no file system roots available on iOS emulator.
 */
public class FileSystemRegistry {

	public static boolean addFileSystemListener(FileSystemListener listener) {
		return false;
	}

	public static boolean removeFileSystemListener(FileSystemListener listener) {
		return false;
	}

	public static Enumeration listRoots() {
		return new Vector().elements();
	}
}
