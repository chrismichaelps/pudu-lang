package org.pudu;

import android.app.Dialog;
import android.os.Build;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.Toolbar;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;

/** The native page stack and page sheet. The program owns which routes exist:
 *  each NAVIGATE names them root first, with each route's body and title, then
 *  the sheet. The top route's body is shown under a platform toolbar whose up
 *  affordance, like system back, pops one route.
 *
 *  The accepted stack is the program's last presentation, trimmed by user
 *  pops already reported. A user pop is applied at once and reported as
 *  POPPED with the route that was on top and the destination; the program
 *  answers by presenting the trimmed stack, which then changes nothing, or by
 *  presenting the stack again, which restores it. A sheet's dismissal is
 *  reported only for the sheet still current. */
final class PuduNavigator {
  static final int POPPED = 14, DISMISSED = 15;

  private static LinearLayout page;
  private static Toolbar bar;
  private static FrameLayout area;
  private static int[] accepted = new int[0];
  private static View[] bodies = new View[0];
  private static boolean[] fills = new boolean[0];
  private static String[] titles = new String[0];
  private static Dialog sheet;
  private static int sheetRoute;
  private static View sheetBody;
  private static Object backCallback;

  private PuduNavigator() {}

  /** Shows a presentation; the host has already refused repeated ids and a
   *  sheet sharing a route's id. */
  static void show(int[] ids, View[] views, boolean[] filling, String[] named, boolean hasSheet, int sheetId, View sheetView,
      boolean sheetFills) {
    install();
    accepted = ids.clone();
    bodies = views.clone();
    fills = filling.clone();
    titles = named.clone();
    showTop();
    if (!hasSheet) {
      closeSheet();
    } else if (sheet == null || sheetRoute != sheetId || sheetBody != sheetView) {
      closeSheet();
      openSheet(sheetId, sheetView, sheetFills);
    }
    track();
  }

  /** The body on top of the screen: the sheet's, otherwise the top route's;
   *  null before any navigation. */
  static View top() {
    if (sheet != null) return sheetBody;
    return bodies.length == 0 ? null : bodies[bodies.length - 1];
  }

  /** Ends the navigation, for tabs that replace it. */
  static void close() {
    closeSheet();
    page = null;
    accepted = new int[0];
    bodies = new View[0];
    fills = new boolean[0];
    titles = new String[0];
    track();
  }

  /** Pops one route as the person asked, when there is one below. */
  static boolean back() {
    if (sheet != null) {
      sheet.cancel();
      return true;
    }
    if (accepted.length < 2) return false;
    int top = accepted[accepted.length - 1];
    int keep = accepted.length - 1;
    accepted = java.util.Arrays.copyOf(accepted, keep);
    bodies = java.util.Arrays.copyOf(bodies, keep);
    fills = java.util.Arrays.copyOf(fills, keep);
    titles = java.util.Arrays.copyOf(titles, keep);
    showTop();
    track();
    PuduBridge.event(POPPED, top, null, accepted[keep - 1], null);
    return true;
  }

  private static void install() {
    if (page != null) return;
    page = new LinearLayout(PuduBridge.activity);
    page.setOrientation(LinearLayout.VERTICAL);
    bar = new Toolbar(PuduBridge.activity);
    bar.setNavigationOnClickListener(pressed -> back());
    area = new FrameLayout(PuduBridge.activity);
    page.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    page.addView(area, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
    PuduBridge.surface.removeAllViews();
    PuduBridge.surface.addView(page, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
  }

  private static void showTop() {
    int last = bodies.length - 1;
    View body = bodies[last];
    bar.setTitle(titles[last]);
    bar.setNavigationIcon(last > 0 ? upArrow() : null);
    bar.setNavigationContentDescription(last > 0 ? titles[last - 1] : null);
    if (area.getChildCount() == 1 && area.getChildAt(0) == body) return;
    area.removeAllViews();
    PuduBridge.detach(body);
    area.addView(body, placement(fills[last]));
  }

  /** The theme's up indicator, so the arrow matches the platform's look. */
  private static android.graphics.drawable.Drawable upArrow() {
    android.content.res.TypedArray read = PuduBridge.activity.obtainStyledAttributes(new int[] {android.R.attr.homeAsUpIndicator});
    android.graphics.drawable.Drawable arrow = read.getDrawable(0);
    read.recycle();
    return arrow;
  }

  private static FrameLayout.LayoutParams placement(boolean fill) {
    return fill
        ? new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        : new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER);
  }

  private static void openSheet(int route, View body, boolean fill) {
    Dialog made = new Dialog(PuduBridge.activity);
    made.requestWindowFeature(Window.FEATURE_NO_TITLE);
    FrameLayout holder = new FrameLayout(PuduBridge.activity);
    PuduBridge.detach(body);
    holder.addView(body, placement(fill));
    made.setContentView(holder);
    made.setCanceledOnTouchOutside(true);
    /* A late report about an earlier sheet cannot close its replacement. */
    made.setOnCancelListener(gone -> {
      if (sheet != made) return;
      sheet = null;
      sheetBody = null;
      track();
      PuduBridge.event(DISMISSED, route, null, 0, null);
    });
    Window window = made.getWindow();
    if (window != null) window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, fill ? ViewGroup.LayoutParams.MATCH_PARENT : ViewGroup.LayoutParams.WRAP_CONTENT);
    sheet = made;
    sheetRoute = route;
    sheetBody = body;
    made.show();
  }

  /** Closes the shown sheet without reporting: the program asked for it. */
  private static void closeSheet() {
    if (sheet == null) return;
    Dialog closing = sheet;
    sheet = null;
    sheetBody = null;
    closing.dismiss();
  }

  /** On API 33 and later, system back reaches the navigator only while it has
   *  something to pop; otherwise the system's own back leaves the activity. */
  private static void track() {
    if (Build.VERSION.SDK_INT < 33) return;
    OnBackInvokedDispatcher dispatcher = PuduBridge.activity.getOnBackInvokedDispatcher();
    boolean wanted = sheet == null && accepted.length > 1;
    if (wanted && backCallback == null) {
      OnBackInvokedCallback callback = PuduNavigator::back;
      dispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback);
      backCallback = callback;
    } else if (!wanted && backCallback != null) {
      dispatcher.unregisterOnBackInvokedCallback((OnBackInvokedCallback) backCallback);
      backCallback = null;
    }
  }
}
