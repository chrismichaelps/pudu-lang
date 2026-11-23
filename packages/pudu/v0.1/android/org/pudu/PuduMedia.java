package org.pudu;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Locale;
import java.util.UUID;

/** The browser, speech and the photo picker. BROWSE hands the page to the
 *  platform's browser and answers BROWSED when the activity resumes;
 *  utterances wait until the speech engine is ready, then answer SPOKE when
 *  they finish or are stopped; PICK_IMAGE copies the chosen image into the
 *  cache directory and answers IMAGE_PICKED with its path. */
final class PuduMedia {
  static final int BROWSED = 37, SPOKE = 38, IMAGE_PICKED = 41;
  /** The request code of the picker activity. */
  static final int PICK = 0x5045;
  /** The largest image copied; a larger one answers as cancelled. */
  private static final long MAX_IMAGE_BYTES = 64L * 1024 * 1024;

  private static int browsing = -1, picking = -1;
  private static TextToSpeech speech;
  private static boolean ready;
  /** Utterances asked for before the engine was ready: tag, rate, language, text. */
  private static final ArrayList<Object[]> waiting = new ArrayList<>();

  private PuduMedia() {}

  static void browse(int tag, String url) {
    Uri page = Uri.parse(url);
    String scheme = page.getScheme() == null ? "" : page.getScheme().toLowerCase(Locale.ROOT);
    if (!scheme.equals("http") && !scheme.equals("https")) {
      PuduBridge.event(BROWSED, tag, null, 0, null);
      return;
    }
    try {
      PuduBridge.activity.startActivity(new Intent(Intent.ACTION_VIEW, page));
      browsing = tag;
    } catch (ActivityNotFoundException none) {
      PuduBridge.event(BROWSED, tag, null, 0, null);
    }
  }

  /** The activity is in front again: a page it handed off has closed. */
  static void resumed() {
    if (browsing < 0) return;
    int tag = browsing;
    browsing = -1;
    PuduBridge.event(BROWSED, tag, null, 0, null);
  }

  static void speak(int tag, int rate, String language, String text) {
    if (speech == null) {
      speech = new TextToSpeech(PuduBridge.activity, status -> PuduBridge.activity.runOnUiThread(() -> started(status)));
      speech.setOnUtteranceProgressListener(new UtteranceProgressListener() {
        @Override
        public void onStart(String id) {}

        @Override
        public void onDone(String id) { spoke(id, true); }

        @Override
        public void onStop(String id, boolean interrupted) { spoke(id, false); }

        @Override
        @SuppressWarnings("deprecation")
        public void onError(String id) { spoke(id, false); }
      });
    }
    if (!ready) {
      waiting.add(new Object[] {tag, rate, language, text});
      return;
    }
    utter(tag, rate, language, text);
  }

  private static void started(int status) {
    ready = status == TextToSpeech.SUCCESS;
    for (Object[] utterance : waiting) {
      if (ready) utter((Integer) utterance[0], (Integer) utterance[1], (String) utterance[2], (String) utterance[3]);
      else PuduBridge.event(SPOKE, (Integer) utterance[0], null, 0, null);
    }
    waiting.clear();
  }

  private static void utter(int tag, int rate, String language, String text) {
    if (!language.isEmpty()) speech.setLanguage(Locale.forLanguageTag(language));
    speech.setSpeechRate(Math.max(rate, 10) / 100f);
    speech.speak(text, TextToSpeech.QUEUE_ADD, new Bundle(), Integer.toString(tag));
  }

  /** Progress arrives on the engine's thread; the answer is sent on the main thread. */
  private static void spoke(String id, boolean finished) {
    int tag = Integer.parseInt(id);
    PuduBridge.activity.runOnUiThread(() -> PuduBridge.event(SPOKE, tag, null, finished ? 1 : 0, null));
  }

  static void hush() {
    if (speech != null) speech.stop();
    for (Object[] utterance : waiting) PuduBridge.event(SPOKE, (Integer) utterance[0], null, 0, null);
    waiting.clear();
  }

  static void pickImage(int tag) {
    Intent choose = new Intent(Intent.ACTION_GET_CONTENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE);
    try {
      picking = tag;
      PuduBridge.activity.startActivityForResult(choose, PICK);
    } catch (ActivityNotFoundException none) {
      picking = -1;
      PuduBridge.event(IMAGE_PICKED, tag, "", 0, null);
    }
  }

  /** The picker's result, routed by the activity: the image is copied so its path outlives the grant. */
  static void result(int code, boolean chosen, Intent data) {
    if (code != PICK || picking < 0) return;
    int tag = picking;
    picking = -1;
    Uri source = chosen && data != null ? data.getData() : null;
    String copied = source == null ? null : copy(source);
    PuduBridge.event(IMAGE_PICKED, tag, copied == null ? "" : copied, copied == null ? 0 : 1, null);
  }

  /** Only an image another application's provider serves is accepted: a file URI or one of this
   *  application's own providers could name its private files. */
  private static boolean acceptable(Uri source) {
    if (!"content".equals(source.getScheme()) || source.getAuthority() == null) return false;
    if (source.getAuthority().startsWith(PuduBridge.activity.getPackageName())) return false;
    String type = PuduBridge.activity.getContentResolver().getType(source);
    return type != null && type.startsWith("image/");
  }

  private static String copy(Uri source) {
    if (!acceptable(source)) return null;
    File target = new File(PuduBridge.activity.getCacheDir(), "pudu-image-" + UUID.randomUUID());
    try (InputStream in = PuduBridge.activity.getContentResolver().openInputStream(source); OutputStream out = new FileOutputStream(target)) {
      if (in == null) return null;
      byte[] buffer = new byte[64 * 1024];
      long total = 0;
      for (int read = in.read(buffer); read > 0; read = in.read(buffer)) {
        total += read;
        if (total > MAX_IMAGE_BYTES) {
          out.close();
          target.delete();
          return null;
        }
        out.write(buffer, 0, read);
      }
      return target.getAbsolutePath();
    } catch (IOException | SecurityException failed) {
      target.delete();
      return null;
    }
  }
}
