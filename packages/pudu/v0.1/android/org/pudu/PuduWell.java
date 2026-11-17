package org.pudu;

import android.app.AlertDialog;
import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.view.View;
import android.widget.GridLayout;

/** A color well: a swatch of the held color; tapping it offers a palette,
 *  and the person's pick reports COLORED with the color packed as RGBA, red
 *  in the high byte, as the iOS well reports it. */
public final class PuduWell extends View {
  static final int COLORED = 15;
  static final int[] PALETTE = {
    0xFF000000, 0xFF7F7F7F, 0xFFFFFFFF, 0xFFFF3B30, 0xFFFF9500, 0xFFFFCC00,
    0xFF34C759, 0xFF00C7BE, 0xFF007AFF, 0xFF5856D6, 0xFFAF52DE, 0xFFFF2D55,
  };
  int argb = 0xFF000000;

  public PuduWell(Context context) {
    super(context);
    int size = (int) (36 * getResources().getDisplayMetrics().density);
    setMinimumWidth(size);
    setMinimumHeight(size);
    setContentDescription("color");
    setOnClickListener(tapped -> palette());
    color(argb);
  }

  /** VALUE: the held color, as an ARGB integer. */
  public void color(int value) {
    argb = value;
    GradientDrawable swatch = new GradientDrawable();
    swatch.setShape(GradientDrawable.OVAL);
    swatch.setColor(value);
    swatch.setStroke((int) getResources().getDisplayMetrics().density, 0x55000000);
    setBackground(swatch);
  }

  private void palette() {
    GridLayout grid = new GridLayout(getContext());
    grid.setColumnCount(6);
    AlertDialog dialog = new AlertDialog.Builder(getContext()).setView(grid).create();
    int size = (int) (40 * getResources().getDisplayMetrics().density);
    for (int color : PALETTE) {
      View swatch = new View(getContext());
      GradientDrawable fill = new GradientDrawable();
      fill.setShape(GradientDrawable.OVAL);
      fill.setColor(color);
      swatch.setBackground(fill);
      swatch.setOnClickListener(tapped -> {
        dialog.dismiss();
        pick(color);
      });
      GridLayout.LayoutParams placed = new GridLayout.LayoutParams();
      placed.width = size;
      placed.height = size;
      placed.setMargins(size / 5, size / 5, size / 5, size / 5);
      grid.addView(swatch, placed);
    }
    dialog.show();
  }

  /** The person's pick: shown, then reported as packed RGBA. */
  public void pick(int value) {
    color(value);
    int alpha = value >>> 24, red = value >> 16 & 0xff, green = value >> 8 & 0xff, blue = value & 0xff;
    PuduBridge.event(COLORED, PuduBridge.tagOf(this), null, red << 24 | green << 16 | blue << 8 | alpha, null);
  }
}
