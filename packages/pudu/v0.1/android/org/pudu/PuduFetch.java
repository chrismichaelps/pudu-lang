package org.pudu;

import android.net.http.HttpResponseCache;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.HashMap;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

/** Requests the program sends and the wake it asks for. Requests run on a
 *  small pool of worker threads through the platform client and its response
 *  cache, so a cached response revalidates with its validators. Every answer
 *  crosses to the main thread, where a generation no longer in flight was
 *  cancelled and is dropped; an answer reaches the program as FETCHED with
 *  the status (0 when nothing arrived), the body or the failure, and the
 *  delay Retry-After asked for in milliseconds, or -1. */
final class PuduFetch {
  static final int FETCHED = 18, WOKE = 19;
  /** What START answers the host: sent, a generation already in flight, or a URL it cannot read. */
  static final int SENT = 0, REPEATED = 1, UNREADABLE = 2;
  private static final int WORKERS = 4;
  private static final long CACHE_BYTES = 16L * 1024 * 1024;

  private static final HashMap<Integer, Future<?>> flights = new HashMap<>();
  private static ExecutorService workers;
  private static Runnable wake;

  private PuduFetch() {}

  /** Sends a request under `generation`; headers alternate name and value. */
  static int start(int generation, String method, String address, String[] headers, String body) {
    URL url;
    try {
      url = new URL(address);
    } catch (IOException unreadable) {
      return UNREADABLE;
    }
    if (flights.containsKey(generation)) return REPEATED;
    if (workers == null) {
      workers = Executors.newFixedThreadPool(WORKERS);
      install();
    }
    flights.put(generation, workers.submit(() -> {
      String[] answer = exchange(url, method, headers, body);
      PuduBridge.main.post(() -> {
        if (flights.remove(generation) == null) return;
        PuduBridge.event(FETCHED, generation, answer[1], Integer.parseInt(answer[0]), new int[] {Integer.parseInt(answer[2])});
      });
    }));
    return SENT;
  }

  /** Cancels a generation; one already answered or unknown is ignored. */
  static void cancel(int generation) {
    Future<?> flight = flights.remove(generation);
    if (flight != null) flight.cancel(true);
  }

  /** One WOKE after `delay` milliseconds, replacing any earlier wake. */
  static void wake(long delay) {
    if (wake != null) PuduBridge.main.removeCallbacks(wake);
    wake = () -> {
      wake = null;
      PuduBridge.event(WOKE, 0, null, 0, null);
    };
    PuduBridge.main.postDelayed(wake, delay);
  }

  /** The response cache in the application's cache directory, installed once. */
  private static void install() {
    if (HttpResponseCache.getInstalled() != null) return;
    try {
      HttpResponseCache.install(new File(PuduBridge.activity.getCacheDir(), "pudu-http"), CACHE_BYTES);
    } catch (IOException unavailable) {
      /* Without a cache every request goes to the network, as it would on first use. */
    }
  }

  /** Status, text and Retry-After milliseconds, as decimal strings and text. */
  private static String[] exchange(URL url, String method, String[] headers, String body) {
    HttpURLConnection connection = null;
    try {
      connection = (HttpURLConnection) url.openConnection();
      connection.setUseCaches(true);
      connection.setRequestMethod(method);
      for (int i = 0; i + 1 < headers.length; i += 2) connection.setRequestProperty(headers[i], headers[i + 1]);
      if (!body.isEmpty()) {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        connection.setDoOutput(true);
        connection.setFixedLengthStreamingMode(bytes.length);
        try (OutputStream out = connection.getOutputStream()) {
          out.write(bytes);
        }
      }
      int status = connection.getResponseCode();
      InputStream stream = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
      String text = stream == null ? "" : read(stream);
      return new String[] {Integer.toString(status), text, Long.toString(retryAfter(connection.getHeaderField("Retry-After")))};
    } catch (IOException | RuntimeException failed) {
      String reason = failed.getMessage();
      return new String[] {"0", reason == null ? failed.getClass().getSimpleName() : reason, "-1"};
    } finally {
      if (connection != null) connection.disconnect();
    }
  }

  private static String read(InputStream stream) throws IOException {
    try (InputStream in = stream) {
      ByteArrayOutputStream out = new ByteArrayOutputStream();
      byte[] chunk = new byte[16 * 1024];
      for (int read = in.read(chunk); read >= 0; read = in.read(chunk)) out.write(chunk, 0, read);
      return out.toString(StandardCharsets.UTF_8.name());
    }
  }

  /** Retry-After in milliseconds, from delay seconds or an HTTP date; -1 when
   *  absent or unreadable, capped at the largest signed word. */
  static long retryAfter(String value) {
    if (value == null || value.trim().isEmpty()) return -1;
    String trimmed = value.trim();
    try {
      return Math.min(Math.max(Long.parseLong(trimmed), 0L), Integer.MAX_VALUE / 1000L) * 1000L;
    } catch (NumberFormatException notSeconds) {
      try {
        SimpleDateFormat format = new SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US);
        long delay = format.parse(trimmed).getTime() - System.currentTimeMillis();
        return Math.min(Math.max(delay, 0L), Integer.MAX_VALUE);
      } catch (ParseException notDate) {
        return -1;
      }
    }
  }
}
