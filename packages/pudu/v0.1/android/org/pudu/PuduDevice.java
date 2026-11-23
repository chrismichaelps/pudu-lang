package org.pudu;

import android.content.Context;
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
  static final int DESCRIBED = 32, NETWORKED = 33;
  static final int OFFLINE = 0, WIFI = 1, CELLULAR = 2, WIRED = 3, UNKNOWN = -1;

  private static ConnectivityManager.NetworkCallback watcher;
  private static int link = UNKNOWN;

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
}
