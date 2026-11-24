package org.pudu;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.VideoView;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;
import java.io.IOException;
import java.util.HashMap;
import java.util.Locale;

/** Web pages and video as nodes, sounds as requests, keyboard dismissal and
 *  the back gesture. A source with an http or https scheme is remote,
 *  about:blank opens an empty page, and any other text names a bundled
 *  asset. LOADED answers each load with the page view's tag; ENDED reports a
 *  video or sound that finished without looping; BACKED reports back while
 *  the program receives it. */
final class PuduWeb {
  static final int LOADED = 42, ENDED = 43, BACKED = 44;

  private static final HashMap<Integer, MediaPlayer> sounds = new HashMap<>();
  private static boolean backHandled;
  private static Object backCallback;

  private PuduWeb() {}

  private static boolean remote(String source) {
    String scheme = Uri.parse(source).getScheme();
    String lowered = scheme == null ? "" : scheme.toLowerCase(Locale.ROOT);
    return lowered.equals("http") || lowered.equals("https") || source.equals("about:blank");
  }

  static WebView makeWeb() {
    WebView view = new WebView(PuduBridge.activity);
    view.getSettings().setJavaScriptEnabled(true);
    view.setMinimumHeight(Math.round(200 * PuduBridge.activity.getResources().getDisplayMetrics().density));
    view.setWebViewClient(new WebViewClient() {
      private boolean failed;

      @Override
      public void onPageStarted(WebView page, String url, android.graphics.Bitmap icon) { failed = false; }

      @Override
      public void onReceivedError(WebView page, WebResourceRequest request, WebResourceError error) {
        if (request.isForMainFrame()) failed = true;
      }

      @Override
      public void onPageFinished(WebView page, String url) { PuduBridge.event(LOADED, PuduBridge.tagOf(page), null, failed ? 0 : 1, null); }
    });
    return view;
  }

  static void load(WebView view, String url) { view.loadUrl(remote(url) ? url : "file:///android_asset/" + url); }

  static VideoView makeVideo() {
    VideoView view = new VideoView(PuduBridge.activity);
    view.setMinimumHeight(Math.round(200 * PuduBridge.activity.getResources().getDisplayMetrics().density));
    return view;
  }

  /** A new source restarts the video; the looping flag and the play state apply to the current one. */
  static void media(VideoView view, boolean playing, boolean looping, String source) {
    if (!source.equals(view.getTag(R_SOURCE))) {
      view.setTag(R_SOURCE, source);
      view.setVideoURI(remote(source) ? Uri.parse(source) : Uri.parse("file:///android_asset/" + source));
    }
    view.setOnPreparedListener(player -> player.setLooping(looping));
    view.setOnCompletionListener(player -> {
      if (!looping) PuduBridge.event(ENDED, PuduBridge.tagOf(view), null, 0, null);
    });
    if (playing) view.start();
    else view.pause();
  }

  /** A key for the source a video view shows; view tags with a key need an id, and this one is unique to the host. */
  private static final int R_SOURCE = 0x7f0f5d01;

  static void audio(int tag, boolean playing, boolean looping, String source) {
    MediaPlayer old = sounds.remove(tag);
    if (old != null) old.release();
    if (!playing) return;
    MediaPlayer player = new MediaPlayer();
    try {
      if (remote(source)) {
        player.setDataSource(source);
      } else {
        try (AssetFileDescriptor asset = PuduBridge.activity.getAssets().openFd(source)) {
          player.setDataSource(asset.getFileDescriptor(), asset.getStartOffset(), asset.getLength());
        }
      }
      player.setLooping(looping);
      player.setOnPreparedListener(MediaPlayer::start);
      player.setOnCompletionListener(done -> {
        if (sounds.get(tag) != done) return;
        sounds.remove(tag);
        done.release();
        PuduBridge.event(ENDED, tag, null, 0, null);
      });
      sounds.put(tag, player);
      player.prepareAsync();
    } catch (IOException | IllegalStateException failed) {
      player.release();
      PuduBridge.event(ENDED, tag, null, 0, null);
    }
  }

  static void keyboard() {
    View focused = PuduBridge.activity.getCurrentFocus();
    if (focused == null) return;
    InputMethodManager input = (InputMethodManager) PuduBridge.activity.getSystemService(Context.INPUT_METHOD_SERVICE);
    input.hideSoftInputFromWindow(focused.getWindowToken(), 0);
    focused.clearFocus();
  }

  /** While on, back is reported instead of performed: through the activity's back press, and on
   *  API 33 and later through a callback above the navigation stack's. */
  static void back(boolean on) {
    backHandled = on;
    if (Build.VERSION.SDK_INT < 33) return;
    OnBackInvokedDispatcher dispatcher = PuduBridge.activity.getOnBackInvokedDispatcher();
    if (on && backCallback == null) {
      OnBackInvokedCallback callback = PuduWeb::backed;
      dispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_OVERLAY, callback);
      backCallback = callback;
    } else if (!on && backCallback != null) {
      dispatcher.unregisterOnBackInvokedCallback((OnBackInvokedCallback) backCallback);
      backCallback = null;
    }
  }

  /** Whether the activity's back press was taken as BACKED. */
  static boolean backPressed() {
    if (!backHandled) return false;
    backed();
    return true;
  }

  private static void backed() { PuduBridge.event(BACKED, 0, null, 0, null); }
}
