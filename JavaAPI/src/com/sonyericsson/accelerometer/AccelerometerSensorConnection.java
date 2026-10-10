/*
 * Copyright 2020 Nikita Shakarun
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.sonyericsson.accelerometer;

import java.io.IOException;

/**
 * Stub implementation of SonyEricsson AccelerometerSensorConnection.
 * Models "no sensor available" — getData() returns empty arrays,
 * getState() returns STATE_CLOSED.
 *
 * The original extends javax.microedition.sensor.SensorConnection, but
 * since the entire sensor API package is absent from the iOS port, this
 * is implemented as a self-contained stub with the same constant values.
 */
public class AccelerometerSensorConnection {

	public static final int STATE_CLOSED = 4;
	public static final int STATE_LISTENING = 2;
	public static final int STATE_OPENED = 1;

	private int state = STATE_CLOSED;

	public int getState() {
		return state;
	}

	public void close() throws IOException {
		state = STATE_CLOSED;
	}

	/**
	 * Open is a no-op — sensor hardware is not available.
	 */
	public static AccelerometerSensorConnection open(String url) {
		return new AccelerometerSensorConnection();
	}
}
