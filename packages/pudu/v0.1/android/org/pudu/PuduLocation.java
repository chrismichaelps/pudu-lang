package org.pudu;

import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;

/** Positions. Each LOCATE sends exactly one LOCATED under its tag: a fix with
 *  latitude and longitude in ten-millionths of a degree, accuracy and
 *  altitude in meters, or no position when the permission is not allowed,
 *  no provider is enabled, or no fix arrives within thirty seconds. TRACK
 *  sends LOCATED under tag 0 for each new fix while on. Every listener runs
 *  on the main looper, where the host sends its events. */
final class PuduLocation {
  static final int LOCATED = 34;
  static final int PRECISE = 0, APPROXIMATE = 1, COARSE = 2;
  private static final long TIMEOUT_MS = 30_000, FRESH_MS = 60_000;

  private static LocationListener tracker;

  private PuduLocation() {}

  private static LocationManager manager() {
    return (LocationManager) PuduBridge.activity.getSystemService(Context.LOCATION_SERVICE);
  }

  private static boolean allowed() {
    return PuduBridge.activity.checkSelfPermission("android.permission.ACCESS_FINE_LOCATION") == PackageManager.PERMISSION_GRANTED
        || PuduBridge.activity.checkSelfPermission("android.permission.ACCESS_COARSE_LOCATION") == PackageManager.PERMISSION_GRANTED;
  }

  /** GPS for a precise fix and the network otherwise, falling back to whichever is enabled; null when none is. */
  private static String provider(LocationManager manager, int accuracy) {
    String wanted = accuracy == PRECISE ? LocationManager.GPS_PROVIDER : LocationManager.NETWORK_PROVIDER;
    String other = accuracy == PRECISE ? LocationManager.NETWORK_PROVIDER : LocationManager.GPS_PROVIDER;
    if (manager.isProviderEnabled(wanted)) return wanted;
    if (manager.isProviderEnabled(other)) return other;
    return null;
  }

  private static void send(int tag, Location fix) {
    if (fix == null) {
      PuduBridge.event(LOCATED, tag, null, 0, new int[0]);
      return;
    }
    int[] words = { (int) Math.round(fix.getLatitude() * 1e7), (int) Math.round(fix.getLongitude() * 1e7),
        (int) Math.ceil(fix.getAccuracy()), (int) Math.round(fix.getAltitude()) };
    PuduBridge.event(LOCATED, tag, null, 1, words);
  }

  @SuppressWarnings("MissingPermission")
  static void locate(int tag, int accuracy) {
    LocationManager manager = manager();
    String source = allowed() ? provider(manager, accuracy) : null;
    if (source == null) {
      send(tag, null);
      return;
    }
    Location last = manager.getLastKnownLocation(source);
    if (last != null && SystemClock.elapsedRealtimeNanos() - last.getElapsedRealtimeNanos() < FRESH_MS * 1_000_000) {
      send(tag, last);
      return;
    }
    Handler main = new Handler(Looper.getMainLooper());
    boolean[] answered = { false };
    LocationListener once = new Listener() {
      @Override
      public void onLocationChanged(Location fix) {
        if (answered[0]) return;
        answered[0] = true;
        manager.removeUpdates(this);
        send(tag, fix);
      }
    };
    manager.requestLocationUpdates(source, 0, 0, once, Looper.getMainLooper());
    main.postDelayed(() -> {
      if (answered[0]) return;
      answered[0] = true;
      manager.removeUpdates(once);
      send(tag, null);
    }, TIMEOUT_MS);
  }

  @SuppressWarnings("MissingPermission")
  static void track(boolean on, int accuracy, int distance) {
    LocationManager manager = manager();
    if (tracker != null) manager.removeUpdates(tracker);
    tracker = null;
    String source = on && allowed() ? provider(manager, accuracy) : null;
    if (source == null) return;
    tracker = new Listener() {
      @Override
      public void onLocationChanged(Location fix) { send(0, fix); }
    };
    manager.requestLocationUpdates(source, 0, distance, tracker, Looper.getMainLooper());
  }

  /** A listener whose provider callbacks do nothing; API levels below 30 require them. */
  private abstract static class Listener implements LocationListener {
    @Override
    public void onStatusChanged(String provider, int status, Bundle extras) {}

    @Override
    public void onProviderEnabled(String provider) {}

    @Override
    public void onProviderDisabled(String provider) {}
  }
}
