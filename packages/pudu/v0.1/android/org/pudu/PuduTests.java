package org.pudu;

import android.os.Build;
import android.view.View;
import android.view.ViewGroup;
import java.util.ArrayList;
import java.util.List;

/** The capability self-test, as the iOS host runs it: take the shown alert's
 *  second choice, fire each gesture on the first control carrying them, pick
 *  a context menu's second item, report a resign and a return to active, and
 *  tap Add twice. What the program made of it is reported after it ends. */
final class PuduTests {
  static final int STOPPED = 2, LIFECYCLE = 12;

  private PuduTests() {}

  static void capabilities() {
    String title = PuduMenus.choose(1);
    if (title != null) System.out.println("PUDU_ALERT " + title);
    for (View view : views(PuduBridge.surface)) {
      PuduGestures gestures = PuduGestures.of(view);
      if (gestures != null) {
        gestures.fire(PuduGestures.PRESS, PuduGestures.BEGAN, 0, 0);
        gestures.fire(PuduGestures.PAN, PuduGestures.CHANGED, 12, -7);
        gestures.fire(PuduGestures.PINCH, PuduGestures.CHANGED, 1500, 0);
        gestures.fire(PuduGestures.ROTATION, PuduGestures.CHANGED, 785, 0);
        gestures.fire(PuduGestures.SWIPE, 2, 0, 0);
      }
      PuduMenus.pick(view, 1);
    }
    PuduBridge.event(LIFECYCLE, 0, null, 2, null);
    PuduBridge.event(LIFECYCLE, 0, null, 1, null);
    for (int tap = 0; tap < 2; tap++) {
      for (View view : views(PuduBridge.surface)) {
        if (view instanceof android.widget.Button && "Add".contentEquals(((android.widget.Button) view).getText())) view.callOnClick();
      }
    }
    PuduBridge.event(STOPPED, 0, null, 0, null);
  }

  /** After the program ends: the first control with an accessibility hint. */
  static void reportAccess() {
    for (View view : views(PuduBridge.surface)) {
      Object held = view.getTag(PuduAccess.R_ACCESS);
      if (held instanceof PuduAccess && !((PuduAccess) held).hint.isEmpty()) {
        PuduAccess access = (PuduAccess) held;
        boolean header = Build.VERSION.SDK_INT >= 28 ? view.isAccessibilityHeading() : (access.mask & PuduAccess.HEADER) != 0;
        System.out.println("PUDU_ACCESS header=" + (header ? "yes" : "no") + " hint=" + access.hint + " value=" + access.value);
        break;
      }
    }
    System.out.flush();
  }

  /** Every view under a group, in drawing order. */
  static List<View> views(View top) {
    List<View> found = new ArrayList<>();
    collect(top, found);
    return found;
  }

  private static void collect(View view, List<View> found) {
    found.add(view);
    if (view instanceof ViewGroup) {
      ViewGroup group = (ViewGroup) view;
      for (int i = 0; i < group.getChildCount(); i++) collect(group.getChildAt(i), found);
    }
  }
}
