package org.pudu;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.UiModeManager;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.animation.LayoutTransition;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CompoundButton;
import android.widget.FrameLayout;
import android.widget.GridView;
import android.widget.LinearLayout;
import android.widget.NumberPicker;
import android.widget.ProgressBar;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;

/** What the C host reaches through Java: views the framework only builds in
 *  Java, quiet value updates, dialogs and the main thread. Every decision is
 *  the host's; these methods only realize them. */
public final class PuduBridge {
  private PuduBridge() {}

  static Activity activity;
  static FrameLayout surface;
  static final Handler main = new Handler(Looper.getMainLooper());
  /** Set while the host writes a value, so the listener it fires stays silent. */
  static boolean quiet;
  static boolean testing;
  static boolean firstShown;
  static int taps;
  static String typed;
  static boolean controls, capabilities;

  static native void start(Activity activity, ViewGroup root, float density, boolean night, boolean testing);
  static native void event(int kind, int tag, String text, int detail, int[] words);
  static native void applyCommit(long commit);
  static native void configured(boolean night);
  static native View rowView(int list, int position);
  static native void selfTest(int taps, String typed, boolean controls);
  static native void report();
  static native void perform(long task);

  /** Runs a Java call the program asked for on the main thread; the program waits. */
  static void runOnMain(long task) { main.post(() -> perform(task)); }

  /* Text crosses the boundary as UTF-8 bytes in both directions. */
  static String decode(byte[] bytes) { return new String(bytes, StandardCharsets.UTF_8); }
  static byte[] encode(String text) { return text.getBytes(StandardCharsets.UTF_8); }

  /** Applies a commit on the main thread; the first one shown starts a self-test. */
  static void post(long commit) {
    main.post(() -> {
      applyCommit(commit);
      if (testing && !firstShown) {
        firstShown = true;
        main.postDelayed(() -> {
          if (capabilities) PuduTests.capabilities();
          else selfTest(taps, typed, controls);
        }, 500);
      }
    });
  }

  /** The program ended: reports what the screen shows under a self-test, then closes. */
  static void finish(int status, boolean report) {
    main.post(() -> {
      if (report) {
        report();
        PuduTests.reportAccess();
      }
      System.out.flush();
      activity.finishAndRemoveTask();
    });
  }

  static void tag(View view, int tag) { view.setTag(tag); }

  static int tagOf(View view) {
    Object tag = view.getTag();
    return tag instanceof Integer ? (Integer) tag : 0;
  }

  static void bold(TextView view, boolean bold) { view.setTypeface(null, bold ? Typeface.BOLD : Typeface.NORMAL); }

  /** A group whose children keep their measured sizes, separated by a gap. */
  static LinearLayout group(boolean vertical, int spacing) {
    LinearLayout group = new LinearLayout(activity);
    group.setOrientation(vertical ? LinearLayout.VERTICAL : LinearLayout.HORIZONTAL);
    group.setGravity(vertical ? Gravity.CENTER_HORIZONTAL : Gravity.CENTER_VERTICAL);
    GradientDrawable gap = new GradientDrawable();
    gap.setSize(spacing, spacing);
    gap.setColor(0);
    group.setDividerDrawable(gap);
    group.setShowDividers(LinearLayout.SHOW_DIVIDER_MIDDLE);
    return group;
  }

  static ScrollView scroll() {
    ScrollView scroll = new ScrollView(activity);
    scroll.setFillViewport(true);
    scroll.addView(group(true, 0), new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    return scroll;
  }

  /** A material panel: a rounded translucent surface holding one column. */
  static LinearLayout material(int padding) {
    LinearLayout panel = group(true, padding);
    panel.setPadding(padding, padding, padding, padding);
    return panel;
  }

  /** Materials 1 to 3 from thin to thick: the surface color at rising opacity. */
  static boolean materialStyle(View view, int code, int surfaceColor) {
    if (code < 1 || code > 3) return false;
    int[] opacity = {0, 0x99, 0xCC, 0xEE};
    GradientDrawable panel = new GradientDrawable();
    panel.setCornerRadius(16 * activity.getResources().getDisplayMetrics().density);
    panel.setColor((opacity[code] << 24) | (surfaceColor & 0x00FFFFFF));
    view.setBackground(panel);
    return true;
  }

  static ProgressBar progress(boolean indeterminate) {
    ProgressBar bar = indeterminate ? new ProgressBar(activity)
        : new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
    if (!indeterminate) {
      bar.setMax(1000);
      bar.setMinimumWidth((int) (200 * activity.getResources().getDisplayMetrics().density));
    }
    return bar;
  }

  /** The column a scroll view or material places children in. */
  static LinearLayout inner(ViewGroup view) {
    return view instanceof ScrollView ? (LinearLayout) ((ScrollView) view).getChildAt(0) : (LinearLayout) view;
  }

  static void quietText(TextView view, String text) {
    if (view.getText().toString().equals(text)) return;
    quiet = true;
    view.setText(text);
    quiet = false;
  }

  static void quietChecked(CompoundButton view, boolean on) {
    quiet = true;
    view.setChecked(on);
    quiet = false;
  }

  static void listen(View view, int kind) { PuduListener.attach(view, kind); }

  static void stepped(View view, int low, int step) { PuduListener.of(view).steps(low, step); }

  /** A stepper's range as step indexes, each labelled with its value. */
  static void steps(NumberPicker picker, int low, int high, int step) {
    int count = (int) (((long) high - low) / step);
    String[] labels = new String[count + 1];
    for (int i = 0; i <= count; i++) labels[i] = Long.toString((long) low + (long) i * step);
    picker.setDisplayedValues(null);
    picker.setMinValue(0);
    picker.setMaxValue(count);
    picker.setDisplayedValues(labels);
    PuduListener.of(picker).steps(low, step);
  }

  static void slide(SeekBar bar, int value) {
    PuduListener listener = PuduListener.of(bar);
    int index = (int) Math.max(0, Math.min(bar.getMax(), ((long) value - listener.low) / listener.step));
    bar.setProgress(index);
  }

  static void step(NumberPicker picker, int value) {
    PuduListener listener = PuduListener.of(picker);
    picker.setValue((int) Math.max(picker.getMinValue(), Math.min(picker.getMaxValue(), ((long) value - listener.low) / listener.step)));
  }

  /** A segmented control's or wheel's labels replaced. */
  static void options(View view, String[] labels) {
    if (view instanceof RadioGroup) {
      RadioGroup group = (RadioGroup) view;
      quiet = true;
      group.removeAllViews();
      for (int i = 0; i < labels.length; i++) {
        RadioButton button = new RadioButton(activity);
        button.setId(i + 1);
        button.setText(labels[i]);
        group.addView(button);
      }
      quiet = false;
    } else {
      NumberPicker wheel = (NumberPicker) view;
      wheel.setDisplayedValues(null);
      wheel.setMinValue(0);
      wheel.setMaxValue(labels.length - 1);
      wheel.setDisplayedValues(labels);
    }
  }

  static int optionCount(View view) {
    return view instanceof RadioGroup ? ((RadioGroup) view).getChildCount() : ((NumberPicker) view).getMaxValue() + 1;
  }

  static void select(View view, int index) {
    if (view instanceof RadioGroup) {
      quiet = true;
      ((RadioGroup) view).check(index + 1);
      quiet = false;
    } else {
      ((NumberPicker) view).setValue(index);
    }
  }

  /* The controls self-test drives, as on iOS. */
  static void driveSlider(SeekBar bar) { PuduListener.of(bar).slid(bar, 3, true); bar.setProgress(3); }
  static void driveStepper(NumberPicker picker) {
    int next = Math.min(picker.getMaxValue(), picker.getValue() + 1);
    picker.setValue(next);
    PuduListener.of(picker).onValueChange(picker, next - 1, next);
  }
  static void driveChoice(View view) {
    if (view instanceof RadioGroup) ((RadioGroup) view).check(2);
    else {
      ((NumberPicker) view).setValue(2);
      PuduListener.of(view).onValueChange((NumberPicker) view, 0, 2);
    }
  }

  static GridView list(int node) { return PuduList.make(node); }

  static void listShape(GridView list, int total, int first, int rows, int columns) {
    PuduList.shape(list, total, first, rows, columns);
  }

  /** From API 35 the system draws content behind the status bar, which then
   *  shows the surface itself; earlier systems take its color directly. */
  @SuppressWarnings("deprecation")
  static void surface(int color, int accent) {
    surface.setBackgroundColor(color);
    if (Build.VERSION.SDK_INT < 35) activity.getWindow().setStatusBarColor(color);
    PuduList.accent = accent;
  }

  static void appearance(int code) {
    if (Build.VERSION.SDK_INT >= 31) {
      int[] modes = {UiModeManager.MODE_NIGHT_AUTO, UiModeManager.MODE_NIGHT_NO, UiModeManager.MODE_NIGHT_YES};
      ((UiModeManager) activity.getSystemService(Activity.UI_MODE_SERVICE)).setApplicationNightMode(modes[code]);
    }
  }

  static void detach(View view) {
    if (view.getParent() instanceof ViewGroup) ((ViewGroup) view.getParent()).removeView(view);
  }

  /** Places a child at an index of a group, or last for -1; a child already
   *  in the group moves. Answers false for an index past the group's end. */
  static boolean place(ViewGroup group, View child, int index) {
    int count = group.getChildCount();
    if (index > count) return false;
    if (child.getParent() == group) {
      group.removeView(child);
      count -= 1;
    } else {
      detach(child);
    }
    group.addView(child, index < 0 || index > count ? count : index);
    return true;
  }

  static boolean animated(ViewGroup group) { return group.getLayoutTransition() != null; }

  /** Animated groups animate placements with the platform transition; the
   *  system's animator scale, zero under reduced motion, governs it. */
  static void animate(ViewGroup group, boolean on) { group.setLayoutTransition(on ? new LayoutTransition() : null); }

  /** Shows a node as the screen's content: filling the screen, or centered. */
  static void root(View view, boolean fill) {
    surface.removeAllViews();
    if (view == null) return;
    detach(view);
    FrameLayout.LayoutParams placed = fill
        ? new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        : new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER);
    surface.addView(view, placed);
  }

  static void gestures(View view, int tag, int mask) { PuduGestures.attach(view, tag, mask); }

  static void traits(View view, int mask) { PuduAccess.of(view).traits(mask); }
  static void accessHint(View view, String hint) { PuduAccess.of(view).hint(hint); }
  static void accessValue(View view, String value) { PuduAccess.of(view).value(value); }

  static void menu(View view, int tag, int[] roles, String[] labels) { PuduMenus.attach(view, tag, roles, labels); }

  /* One alert shows at a time; later ones wait their turn. */
  static final ArrayDeque<AlertDialog> alerts = new ArrayDeque<>();
  static AlertDialog shown;

  static void alert(int tag, int style, String title, String message, int[] roles, String[] labels) {
    AlertDialog dialog = PuduMenus.alert(tag, style, title, message, roles, labels);
    dialog.setOnDismissListener(gone -> {
      shown = null;
      nextAlert();
    });
    alerts.add(dialog);
    nextAlert();
  }

  static void nextAlert() {
    if (shown != null || alerts.isEmpty()) return;
    shown = alerts.poll();
    shown.show();
  }

  /** Plays a haptic through the surface; codes follow Std.Mobile.Feedback. */
  static void haptic(int code) {
    int confirm = Build.VERSION.SDK_INT >= 30 ? HapticFeedbackConstants.CONFIRM : HapticFeedbackConstants.VIRTUAL_KEY;
    int reject = Build.VERSION.SDK_INT >= 30 ? HapticFeedbackConstants.REJECT : HapticFeedbackConstants.LONG_PRESS;
    int[] effects = {0, HapticFeedbackConstants.CLOCK_TICK, HapticFeedbackConstants.VIRTUAL_KEY,
        HapticFeedbackConstants.KEYBOARD_TAP, HapticFeedbackConstants.LONG_PRESS, confirm,
        HapticFeedbackConstants.LONG_PRESS, reject};
    surface.performHapticFeedback(effects[code]);
  }

  static ColorDrawable clear() { return new ColorDrawable(0); }
}
