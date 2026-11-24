package org.pudu;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.SystemClock;

/** Local notifications. NOTIFY sets an inexact alarm that fires PuduAlarm,
 *  which posts the notification; the same id replaces an earlier one. A tap
 *  opens the activity with the id in EXTRA and this installation's secret
 *  in TOKEN; the activity is exported, so only an intent carrying the secret
 *  is reported as NOTIFIED. Without the notifications permission on versions that need it,
 *  the platform drops the notification. */
final class PuduNotify {
  static final int NOTIFIED = 35;
  static final String EXTRA = "org.pudu.notified", TITLE = "org.pudu.title", BODY = "org.pudu.body", TOKEN = "org.pudu.token";
  private static final String CHANNEL = "org.pudu.notifications";

  private PuduNotify() {}

  /** A random secret made once per installation and kept in private preferences. */
  private static String secret(Context context) {
    android.content.SharedPreferences kept = context.getSharedPreferences("org.pudu.notify", Context.MODE_PRIVATE);
    String found = kept.getString("secret", null);
    if (found == null) {
      found = java.util.UUID.randomUUID().toString();
      kept.edit().putString("secret", found).apply();
    }
    return found;
  }

  private static PendingIntent alarm(Context context, int id, String title, String body) {
    Intent fire = new Intent(context, PuduAlarm.class).putExtra(EXTRA, id).putExtra(TITLE, title).putExtra(BODY, body);
    return PendingIntent.getBroadcast(context, id, fire, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  static void schedule(int id, long delay, String title, String body) {
    Context context = PuduBridge.activity;
    AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
    alarms.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, SystemClock.elapsedRealtime() + delay * 1000, alarm(context, id, title, body));
  }

  static void cancel(int id) {
    Context context = PuduBridge.activity;
    ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE)).cancel(alarm(context, id, "", ""));
    ((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE)).cancel(id);
  }

  /** Posts notification `id`; called by PuduAlarm, which may run with no activity. */
  @SuppressWarnings("deprecation")
  static void post(Context context, int id, String title, String body) {
    NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    Notification.Builder builder;
    if (Build.VERSION.SDK_INT >= 26) {
      manager.createNotificationChannel(new NotificationChannel(CHANNEL, "Notifications", NotificationManager.IMPORTANCE_DEFAULT));
      builder = new Notification.Builder(context, CHANNEL);
    } else {
      builder = new Notification.Builder(context);
    }
    Intent open = new Intent(context, PuduActivity.class).putExtra(EXTRA, id).putExtra(TOKEN, secret(context))
        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
    PendingIntent tap = PendingIntent.getActivity(context, id, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    builder.setContentTitle(title).setContentText(body).setSmallIcon(context.getApplicationInfo().icon).setContentIntent(tap).setAutoCancel(true);
    manager.notify(id, builder.build());
  }

  /** Reports the notification a launch or new intent came from, once. */
  static void opened(Intent intent) {
    if (intent == null || !intent.hasExtra(EXTRA)) return;
    boolean genuine = secret(PuduBridge.activity).equals(intent.getStringExtra(TOKEN));
    if (genuine) PuduBridge.event(NOTIFIED, intent.getIntExtra(EXTRA, 0), null, 0, null);
    intent.removeExtra(EXTRA);
    intent.removeExtra(TOKEN);
  }
}
