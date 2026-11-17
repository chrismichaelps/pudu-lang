package org.pudu;

import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;

/** The gestures a Pudu control carries. Each reports GESTURED with the
 *  wrapper's tag, the gesture's bit as detail and its phase and values as
 *  words, in the units the iOS host uses: points for movement, thousandths
 *  for scale and radians times a thousand for rotation. */
final class PuduGestures extends GestureDetector.SimpleOnGestureListener
    implements View.OnTouchListener, ScaleGestureDetector.OnScaleGestureListener {
  static final int GESTURED = 9;
  static final int PRESS = 1, PAN = 2, PINCH = 4, ROTATION = 8, SWIPE = 16;
  static final int BEGAN = 1, CHANGED = 2, ENDED = 3, CANCELLED = 4;
  static final int R_GESTURES = 0x7f0f0004;

  final View view;
  final int tag, mask;
  final GestureDetector detector;
  final ScaleGestureDetector scaler;
  boolean panning, pressing, turning;
  float startX, startY, startAngle;

  private PuduGestures(View view, int tag, int mask) {
    this.view = view;
    this.tag = tag;
    this.mask = mask;
    this.detector = new GestureDetector(PuduBridge.activity, this);
    this.scaler = new ScaleGestureDetector(PuduBridge.activity, this);
  }

  /** Replaces a control's gestures with those in `mask`. */
  static void attach(View view, int tag, int mask) {
    PuduGestures gestures = new PuduGestures(view, tag, mask);
    view.setTag(R_GESTURES, gestures);
    view.setOnTouchListener(mask == 0 ? null : gestures);
    if (mask != 0) view.setClickable(true);
  }

  static PuduGestures of(View view) { return (PuduGestures) view.getTag(R_GESTURES); }

  /** Reports a gesture the way a recognizer does. */
  void fire(int bit, int first, int second, int third) {
    if ((mask & bit) != 0) PuduBridge.event(GESTURED, tag, null, bit, new int[] {first, second, third});
  }

  private int points(float pixels) { return Math.round(pixels / PuduBridge.activity.getResources().getDisplayMetrics().density); }

  @Override public boolean onTouch(View touched, MotionEvent event) {
    scaler.onTouchEvent(event);
    detector.onTouchEvent(event);
    rotation(event);
    int action = event.getActionMasked();
    if (action == MotionEvent.ACTION_DOWN) {
      startX = event.getRawX();
      startY = event.getRawY();
    } else if (action == MotionEvent.ACTION_MOVE && event.getPointerCount() == 1 && !scaler.isInProgress()) {
      int dx = points(event.getRawX() - startX), dy = points(event.getRawY() - startY);
      fire(PAN, panning ? CHANGED : BEGAN, dx, dy);
      panning = true;
    } else if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
      int phase = action == MotionEvent.ACTION_UP ? ENDED : CANCELLED;
      if (panning) fire(PAN, phase, points(event.getRawX() - startX), points(event.getRawY() - startY));
      if (pressing) fire(PRESS, phase, 0, 0);
      panning = false;
      pressing = false;
    }
    return true;
  }

  private void rotation(MotionEvent event) {
    if (event.getPointerCount() < 2) {
      if (turning) fire(ROTATION, ENDED, 0, 0);
      turning = false;
      return;
    }
    float angle = (float) Math.atan2(event.getY(1) - event.getY(0), event.getX(1) - event.getX(0));
    if (!turning) {
      turning = true;
      startAngle = angle;
      fire(ROTATION, BEGAN, 0, 0);
    } else {
      fire(ROTATION, CHANGED, Math.round((angle - startAngle) * 1000), 0);
    }
  }

  @Override public void onLongPress(MotionEvent event) {
    pressing = true;
    fire(PRESS, BEGAN, 0, 0);
  }

  /** A fling's dominant axis decides its direction: 1 left, 2 right, 3 up, 4 down. */
  @Override public boolean onFling(MotionEvent start, MotionEvent end, float vx, float vy) {
    int direction = Math.abs(vx) > Math.abs(vy) ? (vx < 0 ? 1 : 2) : (vy < 0 ? 3 : 4);
    fire(SWIPE, direction, 0, 0);
    return true;
  }

  @Override public boolean onScaleBegin(ScaleGestureDetector scale) {
    fire(PINCH, BEGAN, 1000, 0);
    return true;
  }

  @Override public boolean onScale(ScaleGestureDetector scale) {
    fire(PINCH, CHANGED, Math.round(scale.getScaleFactor() * 1000), 0);
    return false;
  }

  @Override public void onScaleEnd(ScaleGestureDetector scale) { fire(PINCH, ENDED, Math.round(scale.getScaleFactor() * 1000), 0); }
}
