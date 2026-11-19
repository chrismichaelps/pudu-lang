package org.pudu;

import android.content.Context;
import android.widget.DatePicker;
import android.widget.LinearLayout;
import android.widget.TimePicker;
import java.util.Calendar;

/** A date picker: a day, a time of day, or both, in the device's time zone.
 *  It holds whole seconds since the epoch and reports DATED with them as a
 *  high and a low word when the person picks a new moment. */
public final class PuduMoment extends LinearLayout {
  static final int DATED = 23;
  static final int DAY = 0, TIME = 1, DAY_AND_TIME = 2;

  final DatePicker day;
  final TimePicker time;
  final Calendar held = Calendar.getInstance();

  public PuduMoment(Context context) {
    super(context);
    setOrientation(VERTICAL);
    day = new DatePicker(context);
    time = new TimePicker(context);
    addView(day);
    addView(time);
    day.init(held.get(Calendar.YEAR), held.get(Calendar.MONTH), held.get(Calendar.DAY_OF_MONTH),
        (picker, year, month, date) -> changed());
    time.setOnTimeChangedListener((picker, hour, minute) -> changed());
  }

  /** MOMENT: what the picker picks and the moment it shows. */
  public void show(int mode, long seconds) {
    day.setVisibility(mode == TIME ? GONE : VISIBLE);
    time.setVisibility(mode == DAY ? GONE : VISIBLE);
    held.setTimeInMillis(seconds * 1000);
    PuduBridge.quiet = true;
    day.updateDate(held.get(Calendar.YEAR), held.get(Calendar.MONTH), held.get(Calendar.DAY_OF_MONTH));
    time.setHour(held.get(Calendar.HOUR_OF_DAY));
    time.setMinute(held.get(Calendar.MINUTE));
    PuduBridge.quiet = false;
  }

  private void changed() {
    if (PuduBridge.quiet) return;
    held.set(day.getYear(), day.getMonth(), day.getDayOfMonth(), time.getHour(), time.getMinute(), 0);
    report(Math.floorDiv(held.getTimeInMillis(), 1000L));
  }

  private void report(long seconds) {
    PuduBridge.event(DATED, PuduBridge.tagOf(this), null, 0, new int[] {(int) (seconds >> 32), (int) seconds});
  }

  /** What the controls self-test picks: a moment, as a person's pick reports it. */
  public void pick(long seconds) {
    show(day.getVisibility() == GONE ? TIME : time.getVisibility() == GONE ? DAY : DAY_AND_TIME, seconds);
    report(seconds);
  }
}
