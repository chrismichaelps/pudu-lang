package org.pudu;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Posts a scheduled notification when its alarm fires. Declared in the
 *  manifest and not exported, so only this application's alarms reach it. */
public final class PuduAlarm extends BroadcastReceiver {
  @Override
  public void onReceive(Context context, Intent intent) {
    String title = intent.getStringExtra(PuduNotify.TITLE), body = intent.getStringExtra(PuduNotify.BODY);
    PuduNotify.post(context, intent.getIntExtra(PuduNotify.EXTRA, 0), title == null ? "" : title, body == null ? "" : body);
  }
}
