package org.pudu;

import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.BaseAdapter;
import android.widget.FrameLayout;
import android.widget.GridView;

/** A recycling list or grid. The platform owns cells and scrolling; each cell
 *  hosts the window row the host answers for its position. When the visible
 *  range comes within a quarter window of an edge the window does not already
 *  touch, the first visible index is reported, as on iOS. */
final class PuduList extends BaseAdapter implements AbsListView.OnScrollListener {
  static final int REACHED = 8;
  static int accent;
  static int cellsMade;

  final GridView view;
  final int node;
  int total, first, rows, reported = -1;

  private PuduList(GridView view, int node) {
    this.view = view;
    this.node = node;
  }

  static GridView make(int node) {
    GridView grid = new GridView(PuduBridge.activity);
    PuduList list = new PuduList(grid, node);
    grid.setNumColumns(1);
    grid.setAdapter(list);
    grid.setOnScrollListener(list);
    grid.setTag(PuduListener.R_LISTENER, list);
    return grid;
  }

  static void shape(GridView grid, int total, int first, int rows, int columns) {
    PuduList list = (PuduList) grid.getTag(PuduListener.R_LISTENER);
    if (list.first != first || list.total != total) list.reported = -1;
    list.total = total;
    list.first = first;
    list.rows = rows;
    grid.setNumColumns(columns);
    list.notifyDataSetChanged();
  }

  @Override public int getCount() { return total; }
  @Override public Object getItem(int position) { return null; }
  @Override public long getItemId(int position) { return position; }

  /** A cell shows its row, or stays empty when the window does not reach it. */
  @Override public View getView(int position, View reused, ViewGroup parent) {
    FrameLayout cell = reused instanceof FrameLayout ? (FrameLayout) reused : made();
    View row = PuduBridge.rowView(node, position);
    if (cell.getChildCount() == 1 && cell.getChildAt(0) == row) return cell;
    cell.removeAllViews();
    if (row != null) {
      PuduBridge.detach(row);
      cell.addView(row);
    }
    return cell;
  }

  private FrameLayout made() {
    cellsMade += 1;
    FrameLayout cell = new FrameLayout(PuduBridge.activity);
    int inset = (int) (8 * PuduBridge.activity.getResources().getDisplayMetrics().density);
    cell.setPadding(inset, inset, inset, inset);
    return cell;
  }

  @Override public void onScrollStateChanged(AbsListView list, int state) {}

  /** The margin never exceeds what the window holds beyond the visible span,
   *  so a window too small for the screen cannot alternate between edges. */
  @Override public void onScroll(AbsListView list, int low, int visible, int count) {
    if (visible <= 0) return;
    int high = low + visible - 1;
    int margin = Math.max(0, Math.min(rows / 4, (rows - visible) / 2));
    int end = first + rows;
    boolean early = first > 0 && low < first + margin;
    boolean late = end < total && high >= end - margin;
    if (!(early || late) || low == reported) return;
    reported = low;
    PuduBridge.event(REACHED, PuduBridge.tagOf(view), null, low, null);
  }
}
