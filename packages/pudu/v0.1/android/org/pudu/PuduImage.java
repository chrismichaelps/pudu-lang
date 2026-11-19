package org.pudu;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.LruCache;
import android.widget.ImageView;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.WeakHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

/** Images from the application's assets and from the network. A source is
 *  decoded on a worker thread at the largest power-of-two sample size that
 *  still covers the view's pixel size, so a large file never reaches the
 *  screen or the memory cache at full size. Decoded images are kept in a
 *  cache bounded by bytes and emptied when the platform is short of memory;
 *  remote bytes go through the platform client and its installed response
 *  cache. A view given a new source cancels its load in flight, and an answer
 *  for a source the view no longer shows is dropped, so a reused view never
 *  shows another source's image. Each source set reports IMAGED once. */
final class PuduImage {
  static final int IMAGED = 24;
  private static final int WORKERS = 3;
  /** The most bytes one source may have; a larger file is refused while it is read. */
  static final int MAX_BYTES = 32 * 1024 * 1024;
  private static final int CONNECT_MS = 15_000, READ_MS = 30_000;
  private static final ImageView.ScaleType[] SCALINGS = {
    ImageView.ScaleType.CENTER_CROP, ImageView.ScaleType.FIT_CENTER, ImageView.ScaleType.FIT_XY };

  private static final LruCache<String, Bitmap> cache = new LruCache<String, Bitmap>(cacheBytes()) {
    @Override protected int sizeOf(String key, Bitmap bitmap) { return bitmap.getAllocationByteCount(); }
  };
  private static ExecutorService workers;
  private static final WeakHashMap<ImageView, Shown> shownBy = new WeakHashMap<>();

  /** What one view shows: the source key and the load in flight. */
  private static final class Shown {
    String key;
    Future<?> load;
  }

  private PuduImage() {}

  /** An eighth of the heap the application may use, the platform's usual share for images. */
  private static int cacheBytes() { return (int) Math.min(Runtime.getRuntime().maxMemory() / 8, Integer.MAX_VALUE); }

  static ImageView make() {
    ImageView view = new ImageView(PuduBridge.activity);
    view.setAdjustViewBounds(true);
    shownBy.put(view, new Shown());
    return view;
  }

  /** Shows a source: origin 0 is an asset name, 1 a URL; the host has checked both words. */
  static void source(ImageView view, int origin, int scaling, String location) {
    Shown shown = shownBy.get(view);
    int pixels = pixels(view);
    String key = origin + ":" + location + "@" + pixels;
    view.setScaleType(SCALINGS[scaling]);
    if (key.equals(shown.key)) return;
    if (shown.load != null) shown.load.cancel(true);
    shown.load = null;
    shown.key = key;
    Bitmap cached = cache.get(key);
    if (cached != null) {
      land(view, key, cached);
      return;
    }
    view.setImageDrawable(null);
    if (workers == null) workers = Executors.newFixedThreadPool(WORKERS);
    shown.load = workers.submit(() -> {
      Bitmap decoded = decode(origin, location, pixels);
      PuduBridge.main.post(() -> land(view, key, decoded));
    });
  }

  /** Empties the cache; the platform is short of memory. */
  static void trim() { cache.evictAll(); }

  private static void land(ImageView view, String key, Bitmap bitmap) {
    Shown shown = shownBy.get(view);
    if (!key.equals(shown.key)) return;
    shown.load = null;
    if (bitmap != null) cache.put(key, bitmap);
    view.setImageBitmap(bitmap);
    PuduBridge.event(IMAGED, PuduBridge.tagOf(view), null, bitmap != null ? 1 : 0, null);
  }

  /** The longest side the view can show in pixels, rounded up to a power of
   *  two; the screen's longest side before the view is laid out. */
  private static int pixels(ImageView view) {
    int longest = Math.max(view.getWidth(), view.getHeight());
    if (longest <= 0) {
      android.util.DisplayMetrics metrics = view.getResources().getDisplayMetrics();
      longest = Math.max(metrics.widthPixels, metrics.heightPixels);
    }
    int bucket = 64;
    while (bucket < longest) bucket *= 2;
    return bucket;
  }

  private static Bitmap decode(int origin, String location, int pixels) {
    try {
      byte[] bytes = origin == 0 ? asset(location) : remote(location);
      if (bytes == null) return null;
      BitmapFactory.Options bounds = new BitmapFactory.Options();
      bounds.inJustDecodeBounds = true;
      BitmapFactory.decodeByteArray(bytes, 0, bytes.length, bounds);
      if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null;
      BitmapFactory.Options options = new BitmapFactory.Options();
      options.inSampleSize = 1;
      while (Math.max(bounds.outWidth, bounds.outHeight) / (options.inSampleSize * 2) >= pixels) options.inSampleSize *= 2;
      return BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);
    } catch (IOException | RuntimeException failed) {
      return null;
    }
  }

  /** An asset's bytes, or null when its name leaves the assets directory. */
  private static byte[] asset(String name) throws IOException {
    if (name.isEmpty() || name.startsWith("/") || ("/" + name + "/").contains("/../")) return null;
    try (InputStream in = PuduBridge.activity.getAssets().open(name)) {
      return read(in);
    }
  }

  private static byte[] remote(String address) throws IOException {
    URL url = new URL(address);
    String scheme = url.getProtocol();
    if (!scheme.equals("https") && !scheme.equals("http")) return null;
    HttpURLConnection connection = (HttpURLConnection) url.openConnection();
    try {
      connection.setUseCaches(true);
      connection.setConnectTimeout(CONNECT_MS);
      connection.setReadTimeout(READ_MS);
      int status = connection.getResponseCode();
      if (status < 200 || status >= 300 || connection.getContentLengthLong() > MAX_BYTES) return null;
      try (InputStream in = connection.getInputStream()) {
        return read(in);
      }
    } finally {
      connection.disconnect();
    }
  }

  private static byte[] read(InputStream in) throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    byte[] chunk = new byte[16 * 1024];
    for (int read = in.read(chunk); read >= 0; read = in.read(chunk)) {
      if (Thread.currentThread().isInterrupted()) throw new IOException("cancelled");
      if (out.size() + read > MAX_BYTES) throw new IOException("larger than " + MAX_BYTES + " bytes");
      out.write(chunk, 0, read);
    }
    return out.toByteArray();
  }
}
