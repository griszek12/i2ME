package javax.microedition.location;

/**
 * LocationProvider stub for iOS — models "no location hardware available".
 * getInstance() always throws LocationException.
 */
public abstract class LocationProvider {
	public static final int AVAILABLE = 1;
	public static final int TEMPORARILY_UNAVAILABLE = 2;
	public static final int OUT_OF_SERVICE = 3;

	public static LocationProvider getInstance(Criteria criteria) throws LocationException {
		throw new LocationException("Location not supported");
	}

	public abstract Location getLocation(int timeout) throws LocationException, InterruptedException;

	public abstract void setLocationListener(LocationListener listener, int interval, int timeout, int maxAge);

	public static Location getLastKnownLocation() {
		return null;
	}

	public abstract int getState();

	public abstract void reset();

	public static void addProximityListener(ProximityListener listener, Coordinates coordinates, float proximityRadius)
			throws LocationException {
		throw new LocationException("Location not supported");
	}

	public static void removeProximityListener(ProximityListener listener) {
	}
}
