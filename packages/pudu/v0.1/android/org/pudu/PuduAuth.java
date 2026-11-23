package org.pudu;

import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.hardware.biometrics.BiometricPrompt;
import android.os.Build;
import android.os.CancellationSignal;

/** Device-owner authentication. API 29 and later show the biometric prompt
 *  with the device credential allowed; API 28 shows it with a cancel button;
 *  earlier versions show the lock screen's confirm-credential activity. A
 *  device with no lock set answers false at once. Each AUTHENTICATE sends
 *  exactly one AUTHENTICATED. */
final class PuduAuth {
  static final int AUTHENTICATED = 36;
  /** The request code of the confirm-credential activity. */
  static final int CONFIRM = 0x5044;
  private static int confirming = -1;

  private PuduAuth() {}

  private static void answer(int tag, boolean confirmed) {
    PuduBridge.event(AUTHENTICATED, tag, null, confirmed ? 1 : 0, null);
  }

  @SuppressWarnings("deprecation")
  static void authenticate(int tag, String reason) {
    KeyguardManager keyguard = (KeyguardManager) PuduBridge.activity.getSystemService(Context.KEYGUARD_SERVICE);
    if (keyguard == null || !keyguard.isDeviceSecure()) {
      answer(tag, false);
      return;
    }
    String shown = reason.isEmpty() ? " " : reason;
    if (Build.VERSION.SDK_INT >= 28) {
      // The cancel button and the error callback can both report one dismissal; the first answers.
      boolean[] answered = { false };
      java.util.function.Consumer<Boolean> once = confirmed -> {
        if (answered[0]) return;
        answered[0] = true;
        answer(tag, confirmed);
      };
      BiometricPrompt.Builder builder = new BiometricPrompt.Builder(PuduBridge.activity).setTitle(shown);
      if (Build.VERSION.SDK_INT >= 29) builder.setDeviceCredentialAllowed(true);
      else builder.setNegativeButton("Cancel", PuduBridge.activity.getMainExecutor(), (dialog, which) -> once.accept(false));
      builder.build().authenticate(new CancellationSignal(), PuduBridge.activity.getMainExecutor(), new BiometricPrompt.AuthenticationCallback() {
        @Override
        public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) { once.accept(true); }

        @Override
        public void onAuthenticationError(int code, CharSequence message) { once.accept(false); }
      });
      return;
    }
    Intent confirm = keyguard.createConfirmDeviceCredentialIntent(shown, null);
    if (confirm == null) {
      answer(tag, false);
      return;
    }
    confirming = tag;
    PuduBridge.activity.startActivityForResult(confirm, CONFIRM);
  }

  /** The confirm-credential activity's result, routed by the activity. */
  static void result(int code, boolean confirmed) {
    if (code != CONFIRM || confirming < 0) return;
    int tag = confirming;
    confirming = -1;
    answer(tag, confirmed);
  }
}
