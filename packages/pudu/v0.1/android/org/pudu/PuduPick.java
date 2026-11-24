package org.pudu;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.media.MediaRecorder;
import android.net.Uri;
import android.provider.ContactsContract;
import android.view.WindowManager;
import android.widget.Toast;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.UUID;

/** Pickers and system touches. Each picker sends exactly one answer under
 *  its tag: CONTACT_PICKED with the shared contact or nothing, FILED with the
 *  path of a copy in the cache directory or nothing. The contact picker
 *  shares one phone row, so the contact carries that number and no email
 *  addresses. Picked documents are accepted only from other applications'
 *  providers and only up to a size cap. */
final class PuduPick {
  static final int CONTACT_PICKED = 45, FILED = 46;
  /** Request codes of the picker activities. */
  static final int CONTACT = 0x5046, DOCUMENT = 0x5047, PHOTO = 0x5048;
  private static final long MAX_FILE_BYTES = 64L * 1024 * 1024;

  private static int contactTag = -1, documentTag = -1, photoTag = -1;
  private static MediaRecorder recorder;
  private static File recording;

  private PuduPick() {}

  private static void filed(int tag, String path) { PuduBridge.event(FILED, tag, path == null ? "" : path, path == null ? 0 : 1, null); }

  private static File cacheFile(String extension) { return new File(PuduBridge.activity.getCacheDir(), "pudu-" + UUID.randomUUID() + extension); }

  /** Starts `intent` for a result, or answers at once when nothing can handle it. */
  private static boolean started(Intent intent, int code) {
    try {
      PuduBridge.activity.startActivityForResult(intent, code);
      return true;
    } catch (ActivityNotFoundException | SecurityException none) {
      return false;
    }
  }

  static void contact(int tag) {
    contactTag = tag;
    if (started(new Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI), CONTACT)) return;
    contactTag = -1;
    PuduBridge.event(CONTACT_PICKED, tag, "", 0, null);
  }

  static void document(int tag, String types) {
    Intent open = new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*");
    String[] mimes = types.isEmpty() ? new String[0] : types.split(",");
    for (int i = 0; i < mimes.length; i++) mimes[i] = mimes[i].trim();
    if (mimes.length > 0) open.putExtra(Intent.EXTRA_MIME_TYPES, mimes);
    documentTag = tag;
    if (started(open, DOCUMENT)) return;
    documentTag = -1;
    filed(tag, null);
  }

  static void photo(int tag) {
    photoTag = tag;
    if (started(new Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE), PHOTO)) return;
    photoTag = -1;
    filed(tag, null);
  }

  /** The result of a picker activity, routed by the activity by request code. */
  static void result(int code, boolean chosen, Intent data) {
    Uri picked = chosen && data != null ? data.getData() : null;
    if (code == CONTACT && contactTag >= 0) {
      int tag = contactTag;
      contactTag = -1;
      String text = picked == null ? null : contactText(picked);
      PuduBridge.event(CONTACT_PICKED, tag, text == null ? "" : text, text == null ? 0 : 1, null);
    } else if (code == DOCUMENT && documentTag >= 0) {
      int tag = documentTag;
      documentTag = -1;
      filed(tag, picked == null ? null : copy(picked));
    } else if (code == PHOTO && photoTag >= 0) {
      int tag = photoTag;
      photoTag = -1;
      Object thumbnail = chosen && data != null && data.getExtras() != null ? data.getExtras().get("data") : null;
      filed(tag, thumbnail instanceof Bitmap ? saved((Bitmap) thumbnail) : null);
    }
  }

  /** Whether `source` names content another application's provider serves: the provider is resolved
   *  and its package compared, since an authority string can carry a user prefix or mimic a name. */
  static boolean foreign(Uri source) {
    String authority = source.getAuthority();
    if (!"content".equals(source.getScheme()) || authority == null || authority.contains("@")) return false;
    android.content.pm.ProviderInfo provider = PuduBridge.activity.getPackageManager().resolveContentProvider(authority, 0);
    return provider != null && !provider.packageName.equals(PuduBridge.activity.getPackageName());
  }

  /** Whether `row` is a phone row of the system contacts provider. */
  private static boolean phoneRow(Uri row) {
    String phones = ContactsContract.CommonDataKinds.Phone.CONTENT_URI.getPath();
    return "content".equals(row.getScheme()) && ContactsContract.AUTHORITY.equals(row.getAuthority()) && row.getPath() != null
        && phones != null && row.getPath().startsWith(phones);
  }

  private static String contactText(Uri row) {
    if (!phoneRow(row)) return null;
    String[] columns = { ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER };
    try (Cursor cursor = PuduBridge.activity.getContentResolver().query(row, columns, null, null, null)) {
      if (cursor == null || !cursor.moveToFirst()) return null;
      String name = cursor.getString(0), number = cursor.getString(1);
      return (name == null ? "" : name.replace('\n', ' ')) + "\n" + (number == null ? "" : number.replace(",", " ")) + "\n";
    } catch (SecurityException refused) {
      return null;
    }
  }

  private static String saved(Bitmap photo) {
    File target = cacheFile(".jpg");
    try (OutputStream out = new FileOutputStream(target)) {
      return photo.compress(Bitmap.CompressFormat.JPEG, 90, out) ? target.getAbsolutePath() : null;
    } catch (IOException failed) {
      return null;
    }
  }

  /** Copies a picked document from another application's provider, up to the cap. */
  private static String copy(Uri source) {
    if (!foreign(source)) return null;
    File target = cacheFile("");
    try (InputStream in = PuduBridge.activity.getContentResolver().openInputStream(source); OutputStream out = new FileOutputStream(target)) {
      if (in == null) return null;
      byte[] buffer = new byte[64 * 1024];
      long total = 0;
      for (int read = in.read(buffer); read > 0; read = in.read(buffer)) {
        total += read;
        if (total > MAX_FILE_BYTES) {
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

  /** RECORD: starting replaces any recording in progress; stopping answers its file. */
  @SuppressWarnings("deprecation")
  static void record(int tag, boolean on) {
    MediaRecorder running = recorder;
    File file = recording;
    recorder = null;
    recording = null;
    if (running != null) {
      boolean kept;
      try {
        running.stop();
        kept = true;
      } catch (RuntimeException empty) {
        kept = false;
      }
      running.release();
      if (!on) {
        filed(tag, kept ? file.getAbsolutePath() : null);
        return;
      }
    } else if (!on) {
      filed(tag, null);
      return;
    }
    MediaRecorder started = new MediaRecorder();
    File target = cacheFile(".m4a");
    try {
      started.setAudioSource(MediaRecorder.AudioSource.MIC);
      started.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
      started.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
      started.setOutputFile(target.getAbsolutePath());
      started.prepare();
      started.start();
      recorder = started;
      recording = target;
    } catch (IOException | RuntimeException failed) {
      started.release();
      filed(tag, null);
    }
  }

  static void secure(boolean on) {
    if (on) PuduBridge.activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
    else PuduBridge.activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
  }

  static void toast(String text) { Toast.makeText(PuduBridge.activity, text, Toast.LENGTH_SHORT).show(); }
}
