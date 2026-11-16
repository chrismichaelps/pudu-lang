package org.pudu;

import android.app.Activity;
import android.content.Intent;
import android.content.res.Configuration;
import android.os.Bundle;
import android.widget.FrameLayout;

/** The application's one activity: it loads the program's library, gives
 *  the host its surface, and reports the scene's size and lifecycle as the
 *  iOS host does. A self-test is asked for with intent extras named like the
 *  iOS host's environment variables. */
public final class PuduActivity extends Activity {
  static final int RESIZED = 11, LIFECYCLE = 12;
  static final int ACTIVE = 1, INACTIVE = 2, BACKGROUND = 3, FOREGROUND = 4;

  private int[] reported;
  private boolean stopped;

  @Override protected void onCreate(Bundle saved) {
    super.onCreate(saved);
    System.loadLibrary("pudu_app");
    FrameLayout surface = new FrameLayout(this);
    setContentView(surface);
    PuduBridge.activity = this;
    PuduBridge.surface = surface;
    Intent intent = getIntent();
    PuduBridge.testing = intent.hasExtra("PUDU_UI_SELFTEST");
    PuduBridge.taps = parse(intent.getStringExtra("PUDU_UI_SELFTEST"));
    PuduBridge.typed = intent.getStringExtra("PUDU_UI_TYPE");
    PuduBridge.controls = intent.hasExtra("PUDU_UI_CONTROLS_TEST");
    PuduBridge.capabilities = intent.hasExtra("PUDU_UI_CAPABILITY_TEST");
    surface.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> resized(view));
    PuduBridge.start(this, surface, getResources().getDisplayMetrics().density, night(getResources().getConfiguration()),
        PuduBridge.testing);
  }

  private static int parse(String number) {
    try {
      return number == null ? 0 : Integer.parseInt(number.trim());
    } catch (NumberFormatException wrong) {
      return 0;
    }
  }

  private static boolean night(Configuration configuration) {
    return (configuration.uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
  }

  /** The scene's size in points and its size class per axis, once laid out
   *  and again only when they change: 1 compact, 2 regular. */
  private void resized(android.view.View view) {
    float density = getResources().getDisplayMetrics().density;
    int width = Math.round(view.getWidth() / density), height = Math.round(view.getHeight() / density);
    int[] words = {width, height, width >= 600 ? 2 : 1, height >= 500 ? 2 : 1};
    if (width <= 0 || java.util.Arrays.equals(words, reported)) return;
    reported = words;
    PuduBridge.event(RESIZED, 0, null, 0, words);
  }

  @Override public void onConfigurationChanged(Configuration configuration) {
    super.onConfigurationChanged(configuration);
    PuduBridge.configured(night(configuration));
  }

  @Override protected void onStart() {
    super.onStart();
    if (stopped) PuduBridge.event(LIFECYCLE, 0, null, FOREGROUND, null);
    stopped = false;
  }

  @Override protected void onResume() {
    super.onResume();
    PuduBridge.event(LIFECYCLE, 0, null, ACTIVE, null);
  }

  @Override protected void onPause() {
    PuduBridge.event(LIFECYCLE, 0, null, INACTIVE, null);
    super.onPause();
  }

  @Override protected void onStop() {
    stopped = true;
    PuduBridge.event(LIFECYCLE, 0, null, BACKGROUND, null);
    super.onStop();
  }
}
