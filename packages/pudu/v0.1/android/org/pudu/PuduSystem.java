package org.pudu;

import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;

/** What the program asks of the system rather than of a control: opening a
 *  URL in the app that handles it, the share sheet, the clipboard and the
 *  status bar. OPENED reports whether an app opened the URL; SHARED reports
 *  true once the chooser opens, since Android does not say whether the person
 *  shared; PASTED carries the clipboard's text, empty when it holds none. */
final class PuduSystem {
  static final int OPENED = 25, SHARED = 26, PASTED = 27;
  /** Status bar styles: as the platform chooses, light text, dark text. */
  static final int AUTOMATIC = 0, LIGHT_TEXT = 1, DARK_TEXT = 2;

  private PuduSystem() {}

  static void open(int tag, String url) {
    Uri parsed = Uri.parse(url);
    boolean opened = false;
    if (parsed.getScheme() != null) {
      try {
        PuduBridge.activity.startActivity(new Intent(Intent.ACTION_VIEW, parsed));
        opened = true;
      } catch (ActivityNotFoundException | SecurityException none) {
        opened = false;
      }
    }
    PuduBridge.event(OPENED, tag, null, opened ? 1 : 0, null);
  }

  static void share(int tag, String text) {
    Intent send = new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text);
    boolean shown;
    try {
      PuduBridge.activity.startActivity(Intent.createChooser(send, null));
      shown = true;
    } catch (ActivityNotFoundException none) {
      shown = false;
    }
    PuduBridge.event(SHARED, tag, null, shown ? 1 : 0, null);
  }

  static void copy(String text) {
    clipboard().setPrimaryClip(ClipData.newPlainText(null, text));
  }

  static void paste(int tag) {
    ClipData clip = clipboard().getPrimaryClip();
    CharSequence text = clip == null || clip.getItemCount() == 0 ? null : clip.getItemAt(0).coerceToText(PuduBridge.activity);
    PuduBridge.event(PASTED, tag, text == null ? "" : text.toString(), 0, null);
  }

  /** Light text suits dark content and dark text light content; automatic
   *  follows the night mode. */
  static void status(int style, boolean hidden) {
    Window window = PuduBridge.activity.getWindow();
    boolean night = (PuduBridge.activity.getResources().getConfiguration().uiMode
        & android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES;
    boolean darkText = style == DARK_TEXT || (style == AUTOMATIC && !night);
    if (Build.VERSION.SDK_INT >= 30) {
      WindowInsetsController controller = window.getInsetsController();
      if (controller == null) return;
      int light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS;
      controller.setSystemBarsAppearance(darkText ? light : 0, light);
      if (hidden) controller.hide(WindowInsets.Type.statusBars());
      else controller.show(WindowInsets.Type.statusBars());
    } else {
      View decor = window.getDecorView();
      int flags = decor.getSystemUiVisibility();
      flags = darkText ? flags | View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR : flags & ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
      flags = hidden ? flags | View.SYSTEM_UI_FLAG_FULLSCREEN : flags & ~View.SYSTEM_UI_FLAG_FULLSCREEN;
      decor.setSystemUiVisibility(flags);
    }
  }

  private static ClipboardManager clipboard() {
    return (ClipboardManager) PuduBridge.activity.getSystemService(Context.CLIPBOARD_SERVICE);
  }
}
