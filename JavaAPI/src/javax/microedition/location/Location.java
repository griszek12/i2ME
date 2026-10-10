package javax.microedition.location;

/**
 * Location stub for iOS — instances are never created
 * (LocationProvider.getInstance always throws).
 */
public class Location {
	public static final int MTE_SATELLITE = 1;
	public static final int MTE_TIMEDIFFERENCE = 2;
	public static final int MTE_TIMEOFARRIVAL = 4;
	public static final int MTE_CELLID = 8;
	public static final int MTE_SHORTRANGE = 16;
	public static final int MTE_ANGLEOFARRIVAL = 32;
	public static final int MTY_TERMINALBASED = 65536;
	public static final int MTY_NETWORKBASED = 131072;
	public static final int MTA_ASSISTED = 262144;
	public static final int MTA_UNASSISTED = 524288;

	private QualifiedCoordinates coordinates;
	private int locationMethod;
	private long timestamp;
	private float speed = Float.NaN;
	private float course = Float.NaN;

	protected Location(QualifiedCoordinates coordinates, int method) {
		this.coordinates = coordinates;
		this.locationMethod = method;
		this.timestamp = System.currentTimeMillis();
	}

	public boolean isValid() {
		return coordinates != null;
	}

	public long getTimestamp() {
		return timestamp;
	}

	public QualifiedCoordinates getQualifiedCoordinates() {
		return coordinates;
	}

	public float getSpeed() {
		return speed;
	}

	public float getCourse() {
		return course;
	}

	public int getLocationMethod() {
		return locationMethod;
	}

	public AddressInfo getAddressInfo() {
		return null;
	}

	public String getExtraInfo(String mimetype) {
		return null;
	}
}
