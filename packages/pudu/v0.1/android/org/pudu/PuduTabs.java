package org.pudu;

import android.app.Dialog;
import android.os.Build;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.Toolbar;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;
import java.util.Arrays;

/** The tab bar: a stack per tab under a platform toolbar, the tabs' titles in
 *  a bar along the bottom, and at most one sheet over everything. The program
 *  owns the tabs, their routes and the selection; a person's pick is applied
 *  at once and reported as SELECTED, and a pop inside the selected tab, by the
 *  up affordance or system back, is applied and reported as POPPED. A
 *  programmatic change reports nothing. */
final class PuduTabs {
  static final int SELECTED = 29;

  /** One tab's stack: route ids, bodies, whether each fills, titles. */
  private static final class Stack {
    int[] ids;
    View[] bodies;
    boolean[] fills;
    String[] titles;
  }

  private static LinearLayout page;
  private static Toolbar bar;
  private static FrameLayout area;
  private static LinearLayout buttons;
  private static int[] tabIds = new int[0];
  private static Stack[] stacks = new Stack[0];
  private static int selected;
  private static Dialog sheet;
  private static int sheetRoute;
  private static View sheetBody;
  private static Object backCallback;

  private PuduTabs() {}

  /** Shows the tabs; the host has refused repeated ids and an unknown selection. */
  static void show(int[] ids, String[] names, int[] counts, int[] routes, View[] bodies, boolean[] fills, String[] titles, int chosen,
      boolean hasSheet, int sheetId, View sheetView, boolean sheetFills) {
    install();
    tabIds = ids.clone();
    stacks = new Stack[ids.length];
    buttons.removeAllViews();
    for (int tab = 0, at = 0; tab < ids.length; at += counts[tab], tab++) {
      Stack stack = new Stack();
      stack.ids = Arrays.copyOfRange(routes, at, at + counts[tab]);
      stack.bodies = Arrays.copyOfRange(bodies, at, at + counts[tab]);
      stack.fills = Arrays.copyOfRange(fills, at, at + counts[tab]);
      stack.titles = Arrays.copyOfRange(titles, at, at + counts[tab]);
      stacks[tab] = stack;
      Button item = new Button(PuduBridge.activity, null, android.R.attr.borderlessButtonStyle);
      item.setText(names[tab]);
      final int index = tab;
      item.setOnClickListener(pressed -> pick(index));
      buttons.addView(item, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
      if (ids[tab] == chosen) selected = tab;
    }
    showTop();
    if (!hasSheet) closeSheet();
    else if (sheet == null || sheetRoute != sheetId || sheetBody != sheetView) {
      closeSheet();
      openSheet(sheetId, sheetView, sheetFills);
    }
    track();
  }

  /** Whether the tabs are shown. */
  static boolean shown() { return page != null; }

  /** The body on top: the sheet's, otherwise the selected tab's top page's. */
  static View top() {
    if (sheet != null) return sheetBody;
    if (stacks.length == 0) return null;
    Stack stack = stacks[selected];
    return stack.bodies[stack.bodies.length - 1];
  }

  /** Ends the tabs, for a navigation or root that replaces them. */
  static void close() {
    closeSheet();
    page = null;
    tabIds = new int[0];
    stacks = new Stack[0];
    track();
  }

  /** Pops the selected tab's stack as the person asked, when it can. */
  static boolean back() {
    if (page == null) return false;
    if (sheet != null) {
      sheet.cancel();
      return true;
    }
    Stack stack = stacks[selected];
    if (stack.ids.length < 2) return false;
    int top = stack.ids[stack.ids.length - 1];
    int keep = stack.ids.length - 1;
    stack.ids = Arrays.copyOf(stack.ids, keep);
    stack.bodies = Arrays.copyOf(stack.bodies, keep);
    stack.fills = Arrays.copyOf(stack.fills, keep);
    stack.titles = Arrays.copyOf(stack.titles, keep);
    showTop();
    track();
    PuduBridge.event(PuduNavigator.POPPED, top, null, stack.ids[keep - 1], null);
    return true;
  }

  private static void pick(int index) {
    if (index == selected) return;
    selected = index;
    showTop();
    track();
    PuduBridge.event(SELECTED, tabIds[index], null, 0, null);
  }

  private static void install() {
    if (page != null) return;
    PuduNavigator.close();
    page = new LinearLayout(PuduBridge.activity);
    page.setOrientation(LinearLayout.VERTICAL);
    bar = new Toolbar(PuduBridge.activity);
    bar.setNavigationOnClickListener(pressed -> back());
    area = new FrameLayout(PuduBridge.activity);
    buttons = new LinearLayout(PuduBridge.activity);
    buttons.setOrientation(LinearLayout.HORIZONTAL);
    page.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    page.addView(area, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
    page.addView(buttons, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    PuduBridge.surface.removeAllViews();
    PuduBridge.surface.addView(page, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
  }

  private static void showTop() {
    Stack stack = stacks[selected];
    int last = stack.ids.length - 1;
    View body = stack.bodies[last];
    bar.setTitle(stack.titles[last]);
    bar.setNavigationIcon(last > 0 ? upArrow() : null);
    for (int tab = 0; tab < buttons.getChildCount(); tab++) buttons.getChildAt(tab).setSelected(tab == selected);
    if (area.getChildCount() == 1 && area.getChildAt(0) == body) return;
    area.removeAllViews();
    PuduBridge.detach(body);
    area.addView(body, placement(stack.fills[last]));
  }

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
    made.setOnCancelListener(gone -> {
      if (sheet != made) return;
      sheet = null;
      sheetBody = null;
      track();
      PuduBridge.event(PuduNavigator.DISMISSED, route, null, 0, null);
    });
    sheet = made;
    sheetRoute = route;
    sheetBody = body;
    made.show();
  }

  private static void closeSheet() {
    if (sheet == null) return;
    Dialog closing = sheet;
    sheet = null;
    sheetBody = null;
    closing.dismiss();
  }

  /** On API 33 and later, system back reaches the tabs only while the selected stack can pop. */
  private static void track() {
    if (Build.VERSION.SDK_INT < 33) return;
    OnBackInvokedDispatcher dispatcher = PuduBridge.activity.getOnBackInvokedDispatcher();
    boolean wanted = page != null && sheet == null && stacks.length > 0 && stacks[selected].ids.length > 1;
    if (wanted && backCallback == null) {
      OnBackInvokedCallback callback = PuduTabs::back;
      dispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback);
      backCallback = callback;
    } else if (!wanted && backCallback != null) {
      dispatcher.unregisterOnBackInvokedCallback((OnBackInvokedCallback) backCallback);
      backCallback = null;
    }
  }
}
