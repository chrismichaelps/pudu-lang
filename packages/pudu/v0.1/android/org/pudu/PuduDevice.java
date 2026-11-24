package org.pudu;

import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ActivityInfo;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.BatteryManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.text.TextUtils;
import android.view.WindowManager;
import java.util.Locale;
import java.util.TimeZone;

/** What the device is and how it reaches the network. DESCRIBED carries the
 *  platform, version, model, language tag and time zone as five lines with
 *  the font scale in percent; NETWORKED carries the kind of the default
 *  network's link, sent when watching starts and whenever the kind changes.
 *  Callbacks arrive on the connectivity thread and are posted to the main
 *  thread, where every event of the host is sent. */
final class PuduDevice {
  static final int DESCRIBED = 32, NETWORKED = 33, POWERED = 39, SENSED = 40;
  /** Charge codes as POWERED carries them. */
  static final int CHARGE_UNKNOWN = 0, UNPLUGGED = 1, CHARGING = 2, FULL = 3;
  static final int OFFLINE = 0, WIFI = 1, CELLULAR = 2, WIRED = 3, UNKNOWN = -1;

  private static ConnectivityManager.NetworkCallback watcher;
  private static int link = UNKNOWN;
  private static SensorEventListener sensing;

  private PuduDevice() {}

  static void describe(int tag) {
    String[] lines = { "android", Build.VERSION.RELEASE, Build.MANUFACTURER + " " + Build.MODEL, Locale.getDefault().toLanguageTag(),
        TimeZone.getDefault().getID() };
    int scale = Math.round(PuduBridge.activity.getResources().getConfiguration().fontScale * 100);
    PuduBridge.event(DESCRIBED, tag, TextUtils.join("\n", lines), scale, null);
  }

  static void network(boolean watching) {
    ConnectivityManager manager = (ConnectivityManager) PuduBridge.activity.getSystemService(Context.CONNECTIVITY_SERVICE);
    if (!watching) {
      if (watcher != null) manager.unregisterNetworkCallback(watcher);
      watcher = null;
      link = UNKNOWN;
      return;
    }
    if (watcher != null) {
      if (link != UNKNOWN) PuduBridge.event(NETWORKED, 0, null, link, null);
      return;
    }
    ConnectivityManager.NetworkCallback callback = new ConnectivityManager.NetworkCallback() {
      @Override
      public void onCapabilitiesChanged(Network network, NetworkCapabilities capabilities) { post(this, kind(capabilities)); }

      @Override
      public void onLost(Network network) { post(this, OFFLINE); }
    };
    watcher = callback;
    manager.registerDefaultNetworkCallback(callback);
    if (manager.getActiveNetwork() == null) report(OFFLINE);
  }

  static void awake(boolean on) {
    if (on) PuduBridge.activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    else PuduBridge.activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
  }

  private static int kind(NetworkCapabilities capabilities) {
    if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return WIFI;
    if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) return CELLULAR;
    return WIRED;
  }

  /** Reports `found` on the main thread unless watching stopped or moved to another callback. */
  private static void post(ConnectivityManager.NetworkCallback from, int found) {
    PuduBridge.activity.runOnUiThread(() -> {
      if (watcher == from) report(found);
    });
  }

  private static void report(int found) {
    if (found == link) return;
    link = found;
    PuduBridge.event(NETWORKED, 0, null, found, null);
  }

  /** BATTERY: the level from the sticky battery broadcast, which needs no receiver. */
  static void battery(int tag) {
    Intent status = PuduBridge.activity.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
    int level = -1, charge = CHARGE_UNKNOWN;
    if (status != null) {
      int raw = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1), scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
      if (raw >= 0 && scale > 0) level = Math.round(raw * 100f / scale);
      int state = status.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN);
      if (state == BatteryManager.BATTERY_STATUS_CHARGING) charge = CHARGING;
      else if (state == BatteryManager.BATTERY_STATUS_FULL) charge = FULL;
      else if (state == BatteryManager.BATTERY_STATUS_DISCHARGING || state == BatteryManager.BATTERY_STATUS_NOT_CHARGING) charge = UNPLUGGED;
    }
    PuduBridge.event(POWERED, tag, null, charge, new int[] {level});
  }

  /** BRIGHTNESS: the window's own brightness, which the platform drops when the activity leaves. */
  static void brightness(int percent) {
    WindowManager.LayoutParams attributes = PuduBridge.activity.getWindow().getAttributes();
    attributes.screenBrightness = percent / 100f;
    PuduBridge.activity.getWindow().setAttributes(attributes);
  }

  /** ORIENTATION: 0 any, 1 portrait, 2 landscape, either way up. */
  static void orientation(int code) {
    final int[] requested = { ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED, ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT,
        ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE };
    PuduBridge.activity.setRequestedOrientation(requested[code]);
  }

  /** SENSE: the accelerometer in m/s² reported in thousandths of standard gravity, with the sign
   *  turned so a device lying flat reads about -1000 on z, as the other platform reports. */
  static void sense(boolean on, int interval) {
    SensorManager manager = (SensorManager) PuduBridge.activity.getSystemService(Context.SENSOR_SERVICE);
    if (sensing != null) manager.unregisterListener(sensing);
    sensing = null;
    Sensor accelerometer = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
    if (!on || accelerometer == null) return;
    sensing = new SensorEventListener() {
      @Override
      public void onSensorChanged(SensorEvent event) {
        int[] words = new int[3];
        for (int axis = 0; axis < 3; axis++) words[axis] = Math.round(-event.values[axis] / SensorManager.GRAVITY_EARTH * 1000);
        PuduBridge.event(SENSED, 0, null, 0, words);
      }

      @Override
      public void onAccuracyChanged(Sensor sensor, int accuracy) {}
    };
    manager.registerListener(sensing, accelerometer, Math.max(interval, 10) * 1000);
  }
}
