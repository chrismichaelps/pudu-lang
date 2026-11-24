package org.pudu;

import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import java.util.ArrayDeque;
import java.util.Arrays;

/** Permissions. A kind is one or more platform permissions chosen by API
 *  level; a kind that needs none at this level answers from what the
 *  platform allows. Android tells "never asked" from "never ask again" only
 *  by remembering that it asked, so each kind's first request is recorded:
 *  refused after asking with no rationale to show is Blocked, refused while a
 *  rationale may be shown is Denied. Requests run one at a time, and
 *  returning to the foreground re-checks every kind the program has heard
 *  about and reports those that changed. */
final class PuduPermission {
  static final int PERMISSIONED = 28;
  /** Kind codes; they match Std.Mobile.Permission. */
  static final int CAMERA = 0, MICROPHONE = 1, PHOTOS = 2, PHOTOS_ADD = 3, LOCATION = 4, LOCATION_ALWAYS = 5, NOTIFICATIONS = 6,
      CONTACTS = 7, CALENDAR = 8, BLUETOOTH = 9, MOTION = 10, KINDS = 11;
  /** State codes; they match Std.Mobile.Permission. */
  static final int NOT_ASKED = 0, GRANTED = 1, LIMITED = 2, PROVISIONAL = 3, DENIED = 4, BLOCKED = 5, UNAVAILABLE = 6;
  /** The request code the activity's result carries. */
  static final int REQUEST = 0x5044;

  private static final int[] known = filled(-1);
  private static final ArrayDeque<Integer> waiting = new ArrayDeque<>();
  private static int asking = -1;
  /** Whether the activity is in front; prompts start only then. */
  static boolean foreground;

  private PuduPermission() {}

  private static int[] filled(int value) {
    int[] values = new int[KINDS];
    Arrays.fill(values, value);
    return values;
  }

  /** The platform permissions a kind needs at this API level; none when the
   *  level grants it without asking. */
  static String[] needed(int kind) {
    int api = Build.VERSION.SDK_INT;
    switch (kind) {
      case CAMERA: return new String[] {"android.permission.CAMERA"};
      case MICROPHONE: return new String[] {"android.permission.RECORD_AUDIO"};
      case PHOTOS:
        if (api >= 34) return new String[] {"android.permission.READ_MEDIA_IMAGES", "android.permission.READ_MEDIA_VISUAL_USER_SELECTED"};
        if (api >= 33) return new String[] {"android.permission.READ_MEDIA_IMAGES"};
        return new String[] {"android.permission.READ_EXTERNAL_STORAGE"};
      case PHOTOS_ADD: return api <= 28 ? new String[] {"android.permission.WRITE_EXTERNAL_STORAGE"} : new String[0];
      case LOCATION: return new String[] {"android.permission.ACCESS_COARSE_LOCATION", "android.permission.ACCESS_FINE_LOCATION"};
      case LOCATION_ALWAYS: return api >= 29 ? new String[] {"android.permission.ACCESS_BACKGROUND_LOCATION"} : needed(LOCATION);
      case NOTIFICATIONS: return api >= 33 ? new String[] {"android.permission.POST_NOTIFICATIONS"} : new String[0];
      case CONTACTS: return new String[] {"android.permission.READ_CONTACTS"};
      case CALENDAR: return new String[] {"android.permission.READ_CALENDAR", "android.permission.WRITE_CALENDAR"};
      case BLUETOOTH: return api >= 31 ? new String[] {"android.permission.BLUETOOTH_CONNECT", "android.permission.BLUETOOTH_SCAN"} : new String[0];
      case MOTION: return api >= 29 ? new String[] {"android.permission.ACTIVITY_RECOGNITION"} : new String[0];
      default: return new String[0];
    }
  }

  private static boolean granted(String permission) {
    return PuduBridge.activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
  }

  private static SharedPreferences asked() {
    return PuduBridge.activity.getSharedPreferences("org.pudu.permission", Context.MODE_PRIVATE);
  }

  /** Where a kind stands now. */
  static int state(int kind) {
    if (kind == NOTIFICATIONS && Build.VERSION.SDK_INT < 33) {
      NotificationManager manager = (NotificationManager) PuduBridge.activity.getSystemService(Context.NOTIFICATION_SERVICE);
      return manager.areNotificationsEnabled() ? GRANTED : BLOCKED;
    }
    String[] permissions = needed(kind);
    if (permissions.length == 0) return GRANTED;
    if (kind == LOCATION_ALWAYS && Build.VERSION.SDK_INT >= 29 && state(LOCATION) != GRANTED && state(LOCATION) != LIMITED) {
      return state(LOCATION) == NOT_ASKED ? NOT_ASKED : state(LOCATION);
    }
    int allowed = 0;
    for (String permission : permissions) allowed += granted(permission) ? 1 : 0;
    if (allowed == permissions.length) return GRANTED;
    if (kind == LOCATION && granted("android.permission.ACCESS_COARSE_LOCATION")) return LIMITED;
    if (kind == PHOTOS && Build.VERSION.SDK_INT >= 34 && granted("android.permission.READ_MEDIA_VISUAL_USER_SELECTED")) return LIMITED;
    if (!asked().getBoolean(Integer.toString(kind), false)) return NOT_ASKED;
    for (String permission : permissions) {
      if (!granted(permission) && PuduBridge.activity.shouldShowRequestPermissionRationale(permission)) return DENIED;
    }
    return BLOCKED;
  }

  private static void report(int kind, int value) {
    known[kind] = value;
    PuduBridge.event(PERMISSIONED, kind, null, value, null);
  }

  /** Reports where each kind stands, without prompting. */
  static void check(int[] kinds) {
    for (int kind : kinds) report(kind, state(kind));
  }

  /** Asks for a kind in its turn. */
  static void request(int kind) {
    waiting.add(kind);
    next();
  }

  private static void next() {
    if (asking >= 0 || waiting.isEmpty() || !foreground) return;
    int kind = waiting.poll();
    int now = state(kind);
    if (now != NOT_ASKED && now != DENIED && !(kind == LOCATION_ALWAYS && now == LIMITED)) {
      report(kind, now);
      next();
      return;
    }
    /* Background location is asked only once foreground location is allowed. */
    if (kind == LOCATION_ALWAYS && Build.VERSION.SDK_INT >= 29 && state(LOCATION) == NOT_ASKED) {
      waiting.addFirst(LOCATION_ALWAYS);
      waiting.addFirst(LOCATION);
      next();
      return;
    }
    asking = kind;
    asked().edit().putBoolean(Integer.toString(kind), true).apply();
    PuduBridge.activity.requestPermissions(needed(kind), REQUEST);
  }

  /** The activity's permission result for the request on screen. */
  static void answered(int code) {
    if (code != REQUEST || asking < 0) return;
    int kind = asking;
    asking = -1;
    report(kind, state(kind));
    next();
  }

  /** Back in the foreground: re-check what the program has heard about, then ask what waits. */
  static void resumed() {
    for (int kind = 0; kind < KINDS; kind++) {
      if (known[kind] < 0) continue;
      int now = state(kind);
      if (now != known[kind]) report(kind, now);
    }
    next();
  }

  /** The application's page in the platform's settings. */
  static void settings() {
    Intent open = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", PuduBridge.activity.getPackageName(), null));
    PuduBridge.activity.startActivity(open);
  }

}
