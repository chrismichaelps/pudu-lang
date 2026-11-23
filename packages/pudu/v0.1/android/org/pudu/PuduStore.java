package org.pudu;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Key-value storage. Plain values live in the application's preferences.
 *  Secure values are encrypted with AES-GCM under a key the Android Keystore
 *  holds and never exports, and stored as the nonce and ciphertext; a backup
 *  restored elsewhere cannot be decrypted without that key, so such a value
 *  reads as absent and is removed. Every instruction runs on the main thread
 *  in stream order, so a read answers after every earlier write and removal. */
final class PuduStore {
  static final int STORED = 31;
  static final int PLAIN = 0, SECURE = 1;
  private static final String KEY = "org.pudu.store";
  private static final int NONCE_BYTES = 12, TAG_BITS = 128;

  private PuduStore() {}

  private static SharedPreferences preferences(int place) {
    return PuduBridge.activity.getSharedPreferences(place == PLAIN ? "org.pudu.store" : "org.pudu.store.secure", Context.MODE_PRIVATE);
  }

  static void read(int tag, int place, String key) {
    String value = place == PLAIN ? preferences(PLAIN).getString(key, null) : decrypted(key);
    PuduBridge.event(STORED, tag, value == null ? "" : value, value == null ? 0 : 1, null);
  }

  static void write(int place, String key, String value) {
    if (place == PLAIN) {
      preferences(PLAIN).edit().putString(key, value).apply();
      return;
    }
    try {
      Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
      cipher.init(Cipher.ENCRYPT_MODE, secret());
      byte[] sealed = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
      byte[] nonce = cipher.getIV();
      byte[] stored = ByteBuffer.allocate(nonce.length + sealed.length).put(nonce).put(sealed).array();
      preferences(SECURE).edit().putString(key, Base64.encodeToString(stored, Base64.NO_WRAP)).apply();
    } catch (GeneralSecurityException failed) {
      System.err.println("pudu: the keystore refused a write: " + failed);
    }
  }

  static void remove(int place, String key) { preferences(place).edit().remove(key).apply(); }

  private static String decrypted(String key) {
    String stored = preferences(SECURE).getString(key, null);
    if (stored == null) return null;
    try {
      byte[] bytes = Base64.decode(stored, Base64.NO_WRAP);
      Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
      cipher.init(Cipher.DECRYPT_MODE, secret(), new GCMParameterSpec(TAG_BITS, bytes, 0, NONCE_BYTES));
      return new String(cipher.doFinal(bytes, NONCE_BYTES, bytes.length - NONCE_BYTES), StandardCharsets.UTF_8);
    } catch (GeneralSecurityException | IllegalArgumentException unreadable) {
      remove(SECURE, key);
      return null;
    }
  }

  /** The store's key in the Android Keystore, made on first use. */
  private static SecretKey secret() throws GeneralSecurityException {
    KeyStore store = KeyStore.getInstance("AndroidKeyStore");
    try {
      store.load(null);
    } catch (java.io.IOException unloadable) {
      throw new GeneralSecurityException(unloadable);
    }
    KeyStore.Entry entry = store.getEntry(KEY, null);
    if (entry instanceof KeyStore.SecretKeyEntry) return ((KeyStore.SecretKeyEntry) entry).getSecretKey();
    KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
    generator.init(new KeyGenParameterSpec.Builder(KEY, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .setKeySize(256)
        .build());
    return generator.generateKey();
  }
}
