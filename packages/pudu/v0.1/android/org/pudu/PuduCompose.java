package org.pudu;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.provider.CalendarContract;
import java.io.File;

/** System sheets that finish or not. The platform does not report whether
 *  the person saved an event or sent a message through another application,
 *  so COMPLETED reports true once the sheet opens and false when nothing can
 *  handle it; a shared file reports SHARED the same way. Files are shared
 *  only from the cache directory, through PuduFiles. */
final class PuduCompose {
  static final int SHARED = 26, COMPLETED = 47;

  private PuduCompose() {}

  private static boolean opened(Intent intent) {
    try {
      PuduBridge.activity.startActivity(intent);
      return true;
    } catch (ActivityNotFoundException | SecurityException none) {
      return false;
    }
  }

  private static void completed(int tag, boolean done) { PuduBridge.event(COMPLETED, tag, null, done ? 1 : 0, null); }

  static void shareFile(int tag, String path) {
    Uri served = PuduFiles.uriOf(new File(path));
    boolean shown = false;
    if (served != null) {
      Intent send = new Intent(Intent.ACTION_SEND).setType(PuduBridge.activity.getContentResolver().getType(served))
          .putExtra(Intent.EXTRA_STREAM, served).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
      shown = opened(Intent.createChooser(send, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION));
    }
    PuduBridge.event(SHARED, tag, null, shown ? 1 : 0, null);
  }

  static void addEvent(int tag, long start, long end, String title, String location) {
    Intent insert = new Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
        .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start * 1000).putExtra(CalendarContract.EXTRA_EVENT_END_TIME, Math.max(start, end) * 1000)
        .putExtra(CalendarContract.Events.TITLE, title);
    if (!location.isEmpty()) insert.putExtra(CalendarContract.Events.EVENT_LOCATION, location);
    completed(tag, opened(insert));
  }

  static void mail(int tag, String to, String subject, String body) {
    Intent send = new Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:")).putExtra(Intent.EXTRA_EMAIL, recipients(to))
        .putExtra(Intent.EXTRA_SUBJECT, subject).putExtra(Intent.EXTRA_TEXT, body);
    completed(tag, opened(send));
  }

  static void message(int tag, String to, String body) {
    Intent send = new Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:" + Uri.encode(android.text.TextUtils.join(";", recipients(to))))).putExtra("sms_body", body);
    completed(tag, opened(send));
  }

  private static String[] recipients(String joined) {
    String[] parts = joined.isEmpty() ? new String[0] : joined.split(",");
    for (int i = 0; i < parts.length; i++) parts[i] = parts[i].trim();
    return parts;
  }
}
