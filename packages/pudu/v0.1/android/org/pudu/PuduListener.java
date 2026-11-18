package org.pudu;

import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.CompoundButton;
import android.widget.NumberPicker;
import android.widget.RadioGroup;
import android.widget.SeekBar;
import android.widget.TextView;

/** One control's listener: it reports the person's change as the event kind
 *  the host chose, with the control's current tag. A value the host sets
 *  arrives while {@link PuduBridge#quiet} is set and is not reported. */
final class PuduListener implements View.OnClickListener, TextWatcher, CompoundButton.OnCheckedChangeListener,
    SeekBar.OnSeekBarChangeListener, NumberPicker.OnValueChangeListener, RadioGroup.OnCheckedChangeListener {
  static final int TAPPED = 1, CHANGED = 3, SWITCHED_ON = 4, SWITCHED_OFF = 5, VALUED = 14;

  final View view;
  final int kind;
  /** A slider's or stepper's least value and step: an index maps to low + index * step. */
  int low, step = 1;
  /** The stepped value a slider last reported; a drag reports once per step. */
  long reported = Long.MIN_VALUE;

  private PuduListener(View view, int kind) {
    this.view = view;
    this.kind = kind;
  }

  static PuduListener of(View view) { return (PuduListener) view.getTag(R_LISTENER); }

  /** The key a control's listener is kept under; the plain tag is the Pudu tag. */
  static final int R_LISTENER = 0x7f0f0001;

  static void attach(View view, int kind) {
    PuduListener listener = new PuduListener(view, kind);
    view.setTag(R_LISTENER, listener);
    if (view instanceof SeekBar) ((SeekBar) view).setOnSeekBarChangeListener(listener);
    else if (view instanceof NumberPicker) ((NumberPicker) view).setOnValueChangedListener(listener);
    else if (view instanceof RadioGroup) ((RadioGroup) view).setOnCheckedChangeListener(listener);
    else if (view instanceof CompoundButton) ((CompoundButton) view).setOnCheckedChangeListener(listener);
    else if (kind == CHANGED && view instanceof TextView) ((TextView) view).addTextChangedListener(listener);
    else view.setOnClickListener(listener);
  }

  void steps(int low, int step) {
    this.low = low;
    this.step = step;
  }

  private void send(int kind, String text, int detail) {
    if (!PuduBridge.quiet) PuduBridge.event(kind, PuduBridge.tagOf(view), text, detail, null);
  }

  @Override public void onClick(View clicked) { send(TAPPED, null, 0); }

  @Override public void beforeTextChanged(CharSequence text, int start, int count, int after) {}
  @Override public void onTextChanged(CharSequence text, int start, int before, int count) {}
  @Override public void afterTextChanged(Editable text) { send(CHANGED, text.toString(), 0); }

  @Override public void onCheckedChanged(CompoundButton button, boolean on) { send(on ? SWITCHED_ON : SWITCHED_OFF, null, 0); }

  /* A slider's index is its step; only a change of the stepped value reports. */
  @Override public void onProgressChanged(SeekBar bar, int index, boolean byPerson) { slid(bar, index, byPerson); }

  void slid(SeekBar bar, int index, boolean byPerson) {
    long value = (long) low + (long) index * step;
    if (!byPerson || value == reported) return;
    reported = value;
    send(VALUED, null, (int) value);
  }

  @Override public void onStartTrackingTouch(SeekBar bar) {}
  @Override public void onStopTrackingTouch(SeekBar bar) {}

  /* A stepper reports its value; a wheel, which has no step, its row. */
  @Override public void onValueChange(NumberPicker picker, int before, int after) {
    send(VALUED, null, (int) ((long) low + (long) after * step));
  }

  /* A segment's id is its index plus one. */
  @Override public void onCheckedChanged(RadioGroup group, int id) {
    if (id > 0) send(VALUED, null, id - 1);
  }
}
