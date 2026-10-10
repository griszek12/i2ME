package javax.microedition.location;

/**
 * LocationProviderImpl stub for iOS — never instantiated
 * (LocationProvider.getInstance always throws).
 */
class LocationProviderImpl extends LocationProvider {

	public Location getLocation(int timeout) throws LocationException {
		throw new LocationException("Location not supported");
	}

	public void setLocationListener(LocationListener listener, int interval, int timeout, int maxAge) {
	}

	public int getState() {
		return OUT_OF_SERVICE;
	}

	public void reset() {
	}

	boolean meetsCriteria(Criteria criteria) {
		return false;
	}
}
