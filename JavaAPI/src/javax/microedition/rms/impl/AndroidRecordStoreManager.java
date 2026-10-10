/*
 * MicroEmulator
 * Copyright (C) 2008 Bartek Teodorczyk <barteo@barteo.net>
 * Copyright (C) 2017-2018 Nikita Shakarun
 * <p>
 * It is licensed under the following two licenses as alternatives:
 * 1. GNU Lesser General Public License (the "LGPL") version 2.1 or any newer version
 * 2. Apache License (the "AL") Version 2.0
 * <p>
 * You may not use this file except in compliance with at least one of
 * the above two licenses.
 * <p>
 * You may obtain a copy of the LGPL at
 * http://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt
 * <p>
 * You may obtain a copy of the AL at
 * http://www.apache.org/licenses/LICENSE-2.0
 * <p>
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the LGPL or the AL for the specific language governing permissions and
 * limitations.
 *
 * @version $Id$
 */
package javax.microedition.rms.impl;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import javax.microedition.rms.InvalidRecordIDException;
import javax.microedition.rms.RecordStore;
import javax.microedition.rms.RecordStoreException;
import javax.microedition.rms.RecordStoreNotFoundException;

public class AndroidRecordStoreManager implements RecordStoreManager {
	private final static String RECORD_STORE_HEADER_SUFFIX = ".rsh";

	private final static String RECORD_STORE_RECORD_SUFFIX = ".rsr";

	private final static Object NULL_STORE = new Object();

	private Map<String, Object> recordStores = null;

	private static String getDataDir() {
		String root = System.getProperty("app.save.root");
		if (root == null) root = ".";
		String dir = root + "/rms";
		new File(dir).mkdirs();
		return dir;
	}

	private static String sanitizeName(String name) {
		return name.replaceAll("[\\\\/:*?\"<>|]", "");
	}

	@Override
	public String getName() {
		return "Android record store";
	}

	private synchronized void initializeIfNecessary() {
		if (recordStores == null) {
			recordStores = new ConcurrentHashMap<>();
			String[] list = new File(getDataDir()).list();
			if (list != null) {
				for (String fileName : list) {
					if (fileName.endsWith(RECORD_STORE_HEADER_SUFFIX)) {
						recordStores.put(fileName.substring(0,
								fileName.length() - RECORD_STORE_HEADER_SUFFIX.length()), NULL_STORE);
					}
				}
			}
		}
	}

	@Override
	public void deleteRecordStore(String recordStoreName) throws RecordStoreException {
		initializeIfNecessary();

		recordStoreName = sanitizeName(recordStoreName);
		Object value = recordStores.get(recordStoreName);
		if (value == null) {
			throw new RecordStoreNotFoundException(recordStoreName);
		}
		if (value instanceof RecordStoreImpl && ((RecordStoreImpl) value).isOpen()) {
			throw new RecordStoreException();
		}

		File dataDir = new File(getDataDir());
		String prefix = recordStoreName + ".";
		String[] files = dataDir.list();
		if (files != null) {
			for (String name : files) {
				int dot = name.indexOf('.', prefix.length() + 1);
				if ((dot == -1 || dot == name.lastIndexOf('.')) && name.startsWith(prefix)) {
					//noinspection ResultOfMethodCallIgnored
					new File(dataDir, name).delete();
				}
			}
		}

		recordStores.remove(recordStoreName);
		System.out.println("RecordStore " + recordStoreName + " deleted");
	}

	@Override
	public RecordStore openRecordStore(String recordStoreName, boolean createIfNecessary)
			throws RecordStoreException {
		initializeIfNecessary();
		recordStoreName = sanitizeName(recordStoreName);

		Object value = recordStores.get(recordStoreName);
		if (value instanceof RecordStoreImpl && ((RecordStoreImpl) value).isOpen()) {
			((RecordStoreImpl) value).setOpen();
			return (RecordStoreImpl) value;
		}

		RecordStoreImpl recordStoreImpl;
		String headerName = getHeaderFileName(recordStoreName);
		File headerFile = new File(getDataDir(), headerName);
		try (DataInputStream dis = new DataInputStream(new FileInputStream(headerFile))) {
			recordStoreImpl = new RecordStoreImpl(this);
			recordStoreImpl.readHeader(dis);
			recordStoreImpl.setOpen();
		} catch (FileNotFoundException e) {
			if (!createIfNecessary) {
				throw new RecordStoreNotFoundException(recordStoreName);
			}
			recordStoreImpl = new RecordStoreImpl(this, recordStoreName);
			recordStoreImpl.setOpen();
			saveToDisk(recordStoreImpl, -1);
		} catch (IOException e) {
			// miniJVM's FileInputStream throws IOException (not FileNotFoundException)
			// when the file doesn't exist.  Check if the header file actually exists
			// to distinguish "file not found" from "truly broken header".
			if (!headerFile.exists()) {
				if (!createIfNecessary) {
					throw new RecordStoreNotFoundException(recordStoreName);
				}
			}
			System.out.println("openRecordStore: " +
				(headerFile.exists() ? "broken header " : "not found ") +
				headerFile + ": " + e.getMessage());
			recordStoreImpl = new RecordStoreImpl(this, recordStoreName);
			recordStoreImpl.setOpen();
			saveToDisk(recordStoreImpl, -1);
		}

		recordStores.put(recordStoreName, recordStoreImpl);
		synchronized (recordStoreImpl.records) {
			File dataDir = new File(getDataDir());
			String prefix = recordStoreName + ".";
			String[] files = dataDir.list();
			if (files != null) {
				for (String name : files) {
					if (name.startsWith(prefix) && name.endsWith(RECORD_STORE_RECORD_SUFFIX)) {
						File file = new File(dataDir, name);
						try (DataInputStream dis = new DataInputStream(new FileInputStream(file))) {
							recordStoreImpl.readRecord(dis);
						} catch (IOException e) {
							System.out.println("loadFromDisk: broken record " + file + ": " + e.getMessage());
							int pLen = prefix.length();
							int sLen = RECORD_STORE_RECORD_SUFFIX.length();
							int nLen = name.length();
							if (pLen + sLen < nLen) {
								try {
									int recordId = Integer.parseInt(name.substring(pLen, nLen - sLen));
									recordStoreImpl.records.put(recordId, new byte[0]);
								} catch (NumberFormatException numberFormatException) {
									System.out.println("loadFromDisk: ERROR stubbing broken record " + file);
								}
							}
						}
					}
				}
			}

		}

		System.out.println("RecordStore " + recordStoreName + " opened");
		return recordStoreImpl;
	}

	@Override
	public String[] listRecordStores() {
		initializeIfNecessary();

		String[] result = recordStores.keySet().toArray(new String[0]);

		if (result.length > 0) {
			return result;
		} else {
			return null;
		}
	}

	@Override
	public void deleteRecord(RecordStoreImpl recordStoreImpl, int recordId)
			throws RecordStoreException {
		deleteFromDisk(recordStoreImpl, recordId);
	}

	@Override
	public void loadRecord(RecordStoreImpl recordStoreImpl, int recordId)
			throws RecordStoreException {
		String recordName = getRecordFileName(recordStoreImpl.getName(), recordId);
		try (DataInputStream dis = new DataInputStream(new FileInputStream(new File(getDataDir(), recordName)))) {
			recordStoreImpl.readRecord(dis);
		} catch (FileNotFoundException e) {
			throw new InvalidRecordIDException();
		} catch (IOException e) {
			System.out.println("RecordStore.loadFromDisk: ERROR reading " + recordName + ": " + e.getMessage());
		}
	}

	@Override
	public void saveRecord(RecordStoreImpl recordStoreImpl, int recordId)
			throws RecordStoreException {
		saveToDisk(recordStoreImpl, recordId);
	}

	private synchronized void deleteFromDisk(RecordStoreImpl recordStore, int recordId)
			throws RecordStoreException {
		String headerName = getHeaderFileName(recordStore.getName());
		try (DataOutputStream dos = new DataOutputStream(new FileOutputStream(new File(getDataDir(), headerName)))) {
			recordStore.writeHeader(dos);
		} catch (IOException e) {
			System.out.println("RecordStore.saveToDisk: ERROR writing object to " + headerName + ": " + e.getMessage());
			throw new RecordStoreException(e.getMessage());
		}

		new File(getDataDir(), getRecordFileName(recordStore.getName(), recordId)).delete();
	}

	/**
	 * @param recordId -1 for storing only header
	 */
	private synchronized void saveToDisk(RecordStoreImpl recordStore, int recordId)
			throws RecordStoreException {
		String headerName = getHeaderFileName(recordStore.getName());
		try (DataOutputStream dos = new DataOutputStream(new FileOutputStream(new File(getDataDir(), headerName)))) {
			recordStore.writeHeader(dos);
		} catch (IOException e) {
			System.out.println("RecordStore.saveToDisk: ERROR writing object to " + headerName + ": " + e.getMessage());
			throw new RecordStoreException(e.getMessage());
		}

		if (recordId != -1) {
			String recordName = getRecordFileName(recordStore.getName(), recordId);
			try (DataOutputStream dos = new DataOutputStream(new FileOutputStream(new File(getDataDir(), recordName)))) {
				recordStore.writeRecord(dos, recordId);
			} catch (IOException e) {
				System.out.println("RecordStore.saveToDisk: ERROR writing object to " + recordName + ": " + e.getMessage());
				throw new RecordStoreException(e.getMessage());
			}
		}
	}

	@Override
	public int getSizeAvailable(RecordStoreImpl recordStoreImpl) {
		// TODO should return free space on device
		return 1024 * 1024;
	}

	private String getHeaderFileName(String recordStoreName) {
		return recordStoreName + RECORD_STORE_HEADER_SUFFIX;
	}

	private String getRecordFileName(String recordStoreName, int recordId) {
		return recordStoreName + "." + recordId + RECORD_STORE_RECORD_SUFFIX;
	}
}
