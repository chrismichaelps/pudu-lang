package org.pudu;

import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ProgressBar;
import java.util.WeakHashMap;

/** Pull to refresh for a scroll or list, built from platform views. A drag
 *  that starts with the content at its top and travels past the pull distance
 *  reports REFRESHED with the tag the program gave. The indicator follows the
 *  program's flag: it shows while the program refreshes and after a pull
 *  until the program has read the pull, and a pull the program reads without
 *  asking to refresh ends by itself. */
final class PuduRefresh implements View.OnTouchListener {
  static final int REFRESHED = 16;
  /** How far a drag travels, in dp, before it counts as a pull. */
  private static final int PULL_DP = 72;
  private static final int INDICATOR_DP = 40;

  private static final WeakHashMap<View, PuduRefresh> attached = new WeakHashMap<>();

  private final ViewGroup target;
  private final ProgressBar indicator;
  private int tag;
  private boolean wanted, pulled, showing, tracking;
  private float startY;

  private PuduRefresh(ViewGroup target) {
    this.target = target;
    indicator = new ProgressBar(target.getContext());
    indicator.setIndeterminate(true);
  }

  /** Gives `view` pull to refresh reporting `reported`, or updates the one it has. */
  static void set(ViewGroup view, int reported, boolean on) {
    PuduRefresh refresh = attached.get(view);
    if (refresh == null) {
      refresh = new PuduRefresh(view);
      attached.put(view, refresh);
      view.setOnTouchListener(refresh);
    }
    refresh.tag = reported;
    refresh.wanted = on;
    if (on) refresh.show();
    else if (!refresh.pulled) refresh.hide();
  }

  /** Ends every pull whose report the program has read, unless it asked to
   *  refresh; `queued` are the tags of pulls still waiting to be read. */
  static void settle(int[] queued) {
    PuduBridge.main.post(() -> {
      for (PuduRefresh refresh : attached.values()) {
        if (!refresh.pulled || contains(queued, refresh.tag)) continue;
        refresh.pulled = false;
        if (!refresh.wanted) refresh.hide();
      }
    });
  }

  @Override public boolean onTouch(View view, MotionEvent event) {
    switch (event.getActionMasked()) {
      case MotionEvent.ACTION_DOWN:
        tracking = !view.canScrollVertically(-1);
        startY = event.getY();
        break;
      case MotionEvent.ACTION_UP:
        if (tracking && !showing && event.getY() - startY >= dp(PULL_DP)) pull();
        tracking = false;
        break;
      case MotionEvent.ACTION_CANCEL:
        tracking = false;
        break;
      default:
        break;
    }
    /* The scroll keeps every touch; the pull only watches. */
    return false;
  }

  private void pull() {
    pulled = true;
    show();
    PuduBridge.event(REFRESHED, tag, null, 0, null);
  }

  /** The indicator sits in the view's overlay at the top center, so the
   *  content's layout never changes for it. */
  private void show() {
    if (showing) return;
    showing = true;
    int size = dp(INDICATOR_DP);
    int left = (target.getWidth() - size) / 2;
    indicator.measure(View.MeasureSpec.makeMeasureSpec(size, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(size, View.MeasureSpec.EXACTLY));
    indicator.layout(left, dp(8), left + size, dp(8) + size);
    target.getOverlay().add(indicator);
  }

  private void hide() {
    if (!showing) return;
    showing = false;
    target.getOverlay().remove(indicator);
  }

  private int dp(int value) { return Math.round(value * target.getResources().getDisplayMetrics().density); }

  private static boolean contains(int[] values, int wanted) {
    for (int value : values) {
      if (value == wanted) return true;
    }
    return false;
  }
}
