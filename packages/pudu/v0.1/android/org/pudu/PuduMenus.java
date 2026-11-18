package org.pudu;

import android.app.AlertDialog;
import android.view.Menu;
import android.view.View;
import android.widget.PopupMenu;

/** Alerts, action sheets and context menus. A choice reports CHOSE with the
 *  alert's tag and the choice's index; a menu item reports PICKED with the
 *  menu's tag and the item's index. Roles follow Std.Mobile.Feedback: 0
 *  plain, 1 cancel, 2 destructive. */
final class PuduMenus {
  static final int CHOSE = 10, PICKED = 13;

  private PuduMenus() {}

  /** The shown alert's choice handlers, in order, for a self-test to take one. */
  static Runnable[] choices = new Runnable[0];
  static String title = "";

  /** A centered alert with up to three choices shows them as its buttons,
   *  cancel on the negative side and a destructive one on the neutral side;
   *  an action sheet, or an alert with more choices, lists them. */
  static AlertDialog alert(int tag, int style, String heading, String message, int[] roles, String[] labels) {
    AlertDialog.Builder builder = new AlertDialog.Builder(PuduBridge.activity).setTitle(heading);
    Runnable[] taken = new Runnable[labels.length];
    for (int i = 0; i < labels.length; i++) {
      final int index = i;
      taken[i] = () -> PuduBridge.event(CHOSE, tag, null, index, null);
    }
    if (style == 0 && labels.length <= 3) {
      builder.setMessage(message);
      boolean positive = false, negative = false;
      for (int i = 0; i < labels.length; i++) {
        final int index = i;
        if (roles[i] == 1 && !negative) {
          negative = true;
          builder.setNegativeButton(labels[i], (dialog, which) -> taken[index].run());
        } else if (roles[i] == 0 && !positive) {
          positive = true;
          builder.setPositiveButton(labels[i], (dialog, which) -> taken[index].run());
        } else {
          builder.setNeutralButton(labels[i], (dialog, which) -> taken[index].run());
        }
      }
    } else {
      if (!message.isEmpty()) builder.setTitle(heading.isEmpty() ? message : heading + "\n" + message);
      builder.setItems(labels, (dialog, which) -> taken[which].run());
    }
    builder.setCancelable(false);
    AlertDialog dialog = builder.create();
    dialog.setOnShowListener(seen -> {
      choices = taken;
      title = heading;
    });
    return dialog;
  }

  /** Takes choice `index` of the shown alert as a person would. */
  static String choose(int index) {
    AlertDialog dialog = PuduBridge.shown;
    if (dialog == null || index >= choices.length) return null;
    String heading = title;
    Runnable choice = choices[index];
    dialog.dismiss();
    choice.run();
    return heading;
  }

  static final int R_MENU = 0x7f0f0002;

  /** A long press shows the control's menu; a destructive item says so. */
  static void attach(View view, int tag, int[] roles, String[] labels) {
    view.setTag(R_MENU, new Object[] {tag, labels, roles});
    view.setLongClickable(true);
    view.setOnLongClickListener(pressed -> {
      PopupMenu menu = new PopupMenu(PuduBridge.activity, pressed);
      for (int i = 0; i < labels.length; i++) {
        String label = roles[i] == 2 ? labels[i] + " ⚠" : labels[i];
        menu.getMenu().add(Menu.NONE, i, i, label);
      }
      menu.setOnMenuItemClickListener(item -> {
        pick(pressed, item.getItemId());
        return true;
      });
      menu.show();
      return true;
    });
  }

  static boolean pick(View view, int index) {
    Object[] held = (Object[]) view.getTag(R_MENU);
    if (held == null) return false;
    PuduBridge.event(PICKED, (Integer) held[0], null, index, null);
    return true;
  }
}
