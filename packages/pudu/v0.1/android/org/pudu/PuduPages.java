package org.pudu;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;

/** A page control: one dot per page, the current one in the accent color.
 *  Tapping a dot reports VALUED with its page. */
public final class PuduPages extends LinearLayout {
  static final int VALUED = 21;
  int total, page;

  public PuduPages(Context context) {
    super(context);
    setOrientation(HORIZONTAL);
    setGravity(Gravity.CENTER);
  }

  /** COUNT: how many pages show. */
  public void count(int pages) {
    total = Math.max(0, pages);
    removeAllViews();
    int size = (int) (8 * getResources().getDisplayMetrics().density);
    for (int i = 0; i < total; i++) {
      final int index = i;
      View dot = new View(getContext());
      LayoutParams placed = new LayoutParams(size, size);
      placed.setMargins(size / 2, size, size / 2, size);
      dot.setOnClickListener(tapped -> pick(index));
      dot.setContentDescription("page " + (i + 1));
      addView(dot, placed);
    }
    current(Math.min(page, Math.max(0, total - 1)));
  }

  /** VALUE: the current page, clamped to the pages there are. */
  public void current(int index) {
    page = total == 0 ? 0 : Math.max(0, Math.min(total - 1, index));
    for (int i = 0; i < getChildCount(); i++) {
      GradientDrawable dot = new GradientDrawable();
      dot.setShape(GradientDrawable.OVAL);
      dot.setColor(i == page ? PuduList.accent : (PuduList.accent & 0x00FFFFFF) | 0x55000000);
      getChildAt(i).setBackground(dot);
    }
  }

  public void pick(int index) {
    current(index);
    PuduBridge.event(VALUED, PuduBridge.tagOf(this), null, page, null);
  }
}
