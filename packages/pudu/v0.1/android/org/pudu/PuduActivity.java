package org.pudu;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Insets;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.WindowInsets;
import android.widget.FrameLayout;

/** The application's one activity: it loads the program's library, gives
 *  the host its surface, and reports the scene's size and lifecycle as the
 *  iOS host does. A self-test is asked for with intent extras named like the
 *  iOS host's environment variables. */
public final class PuduActivity extends Activity {
  static final int RESIZED = 11, LIFECYCLE = 12, INSETS = 17, MEMORY = 20, LINKED = 30;
  static final int ACTIVE = 1, INACTIVE = 2, BACKGROUND = 3, FOREGROUND = 4;
  /** The most taps a self-test asks for. */
  static final int MAX_TAPS = 100;

  private int[] reported;
  private int[] insetsReported;
  private boolean stopped;

  @Override protected void onCreate(Bundle saved) {
    super.onCreate(saved);
    System.loadLibrary("pudu_app");
    FrameLayout surface = new FrameLayout(this);
    setContentView(surface);
    PuduBridge.activity = this;
    PuduBridge.surface = surface;
    /* The launcher activity is exported, so self-test extras count only in a
       test build; any other package drops whatever another application sends. */
    Intent intent = getIntent();
    PuduBridge.testing = testBuild() && intent.hasExtra("PUDU_UI_SELFTEST");
    if (!PuduBridge.testing) intent = new Intent();
    PuduBridge.taps = Math.min(MAX_TAPS, parse(intent.getStringExtra("PUDU_UI_SELFTEST")));
    PuduBridge.typed = intent.getStringExtra("PUDU_UI_TYPE");
    PuduBridge.controls = intent.hasExtra("PUDU_UI_CONTROLS_TEST");
    PuduBridge.capabilities = intent.hasExtra("PUDU_UI_CAPABILITY_TEST");
    surface.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> resized(view));
    surface.setOnApplyWindowInsetsListener((view, insets) -> inset(view, insets));
    PuduBridge.start(this, surface, getResources().getDisplayMetrics().density, night(getResources().getConfiguration()),
        PuduBridge.testing);
    linked(getIntent());
    PuduNotify.opened(getIntent());
  }

  /** A package built with PUDU_ANDROID_TEST_BUILD: debuggable and carrying
   *  the org.pudu.selftest marker in its manifest. */
  private boolean testBuild() {
    if ((getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) == 0) return false;
    try {
      Bundle meta = getPackageManager().getApplicationInfo(getPackageName(), PackageManager.GET_META_DATA).metaData;
      return meta != null && meta.getBoolean("org.pudu.selftest", false);
    } catch (PackageManager.NameNotFoundException missing) {
      return false;
    }
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

  /** The system bars' and cutout's insets: the surface is padded by them, so
   *  content stays clear of the bars when the window draws edge to edge, and
   *  they are reported in dp as top, left, bottom, right when they change. */
  private WindowInsets inset(View view, WindowInsets insets) {
    int top, left, bottom, right;
    if (Build.VERSION.SDK_INT >= 30) {
      Insets bars = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
      top = bars.top;
      left = bars.left;
      bottom = bars.bottom;
      right = bars.right;
    } else {
      top = insets.getSystemWindowInsetTop();
      left = insets.getSystemWindowInsetLeft();
      bottom = insets.getSystemWindowInsetBottom();
      right = insets.getSystemWindowInsetRight();
    }
    view.setPadding(left, top, right, bottom);
    float density = getResources().getDisplayMetrics().density;
    int[] words = {Math.round(top / density), Math.round(left / density), Math.round(bottom / density), Math.round(right / density)};
    if (!java.util.Arrays.equals(words, insetsReported)) {
      insetsReported = words;
      PuduBridge.event(INSETS, 0, null, 0, words);
    }
    return insets;
  }

  /** System back pops the navigation before it leaves the activity; on API 33
   *  and later the navigator registers its own callback instead. */
  @Override public void onBackPressed() {
    if (!PuduWeb.backPressed() && !PuduTabs.back() && !PuduNavigator.back()) super.onBackPressed();
  }

  /** The platform is short of memory: the program drops what nothing shows. */
  @Override public void onTrimMemory(int level) {
    super.onTrimMemory(level);
    if (level == TRIM_MEMORY_RUNNING_LOW || level == TRIM_MEMORY_RUNNING_CRITICAL || level >= TRIM_MEMORY_MODERATE) {
      PuduImage.trim();
      PuduBridge.event(MEMORY, 0, null, 0, null);
    }
  }

  @Override public void onLowMemory() {
    super.onLowMemory();
    PuduImage.trim();
    PuduBridge.event(MEMORY, 0, null, 0, null);
  }

  /** A link that opened the activity, at launch or while it runs in its single task. */
  @Override protected void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    setIntent(intent);
    linked(intent);
    PuduNotify.opened(intent);
  }

  private static void linked(Intent intent) {
    if (intent != null && Intent.ACTION_VIEW.equals(intent.getAction()) && intent.getData() != null) {
      PuduBridge.event(LINKED, 0, intent.getData().toString(), 0, null);
    }
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
    PuduPermission.foreground = true;
    PuduPermission.resumed();
    PuduMedia.resumed();
    PuduBridge.event(LIFECYCLE, 0, null, ACTIVE, null);
  }

  /** A result from an activity a request started: confirming the device owner, or picking an image. */
  @Override protected void onActivityResult(int code, int result, Intent data) {
    super.onActivityResult(code, result, data);
    PuduAuth.result(code, result == RESULT_OK);
    PuduMedia.result(code, result == RESULT_OK, data);
  }

  @Override public void onRequestPermissionsResult(int code, String[] permissions, int[] results) {
    super.onRequestPermissionsResult(code, permissions, results);
    PuduPermission.answered(code);
  }

  @Override protected void onPause() {
    PuduPermission.foreground = false;
    PuduBridge.event(LIFECYCLE, 0, null, INACTIVE, null);
    super.onPause();
  }

  @Override protected void onStop() {
    stopped = true;
    PuduBridge.event(LIFECYCLE, 0, null, BACKGROUND, null);
    super.onStop();
  }
}
