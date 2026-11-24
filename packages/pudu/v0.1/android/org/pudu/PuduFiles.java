package org.pudu;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

/** The application's read-only file provider. It serves a file to the app
 *  a share was granted to, and only a file whose canonical path lies inside
 *  the cache directory, where pickers, the camera and recordings write; no
 *  other path resolves. Not exported: access comes only from a URI grant. */
public final class PuduFiles extends ContentProvider {
  /** The URI another application reads `file` through, or null when the file is outside the cache directory. */
  static Uri uriOf(File file) {
    File inside = served(PuduBridge.activity, file.getName());
    if (inside == null || !inside.equals(canonical(file))) return null;
    return new Uri.Builder().scheme("content").authority(PuduBridge.activity.getPackageName() + ".files").appendPath(file.getName()).build();
  }

  private static File canonical(File file) {
    try {
      return file.getCanonicalFile();
    } catch (IOException failed) {
      return null;
    }
  }

  /** The cache file named `name`, or null when the name leaves the cache directory. */
  private static File served(android.content.Context context, String name) {
    if (name == null || name.isEmpty() || name.contains("/") || name.equals("..") || context == null) return null;
    File root = canonical(context.getCacheDir());
    File file = canonical(new File(root, name));
    return root != null && file != null && root.equals(file.getParentFile()) && file.isFile() ? file : null;
  }

  @Override
  public boolean onCreate() { return true; }

  @Override
  public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
    File file = served(getContext(), uri.getLastPathSegment());
    if (file == null || !"r".equals(mode)) throw new FileNotFoundException(uri.toString());
    return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
  }

  @Override
  public Cursor query(Uri uri, String[] projection, String selection, String[] arguments, String order) {
    File file = served(getContext(), uri.getLastPathSegment());
    MatrixCursor cursor = new MatrixCursor(new String[] {OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE});
    if (file != null) cursor.addRow(new Object[] {file.getName(), file.length()});
    return cursor;
  }

  @Override
  public String getType(Uri uri) {
    String name = uri.getLastPathSegment();
    String extension = name == null ? "" : MimeTypeMap.getFileExtensionFromUrl(name);
    String type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
    return type == null ? "application/octet-stream" : type;
  }

  @Override
  public Uri insert(Uri uri, ContentValues values) { return null; }

  @Override
  public int delete(Uri uri, String selection, String[] arguments) { return 0; }

  @Override
  public int update(Uri uri, ContentValues values, String selection, String[] arguments) { return 0; }
}
