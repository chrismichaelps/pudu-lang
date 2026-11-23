---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduStore.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, storage, keystore]
aliases: [PuduStore, Native Android Storage]
---

# PuduStore

## Purpose and interface

Key-value storage on the Android host: SharedPreferences for plain values and encrypted SharedPreferences entries for secure values. The class is called from [[PuduBridge]] when a STORE_READ, STORE_WRITE or STORE_REMOVE instruction arrives. Its one report is STORED (31) of [[Std Mobile Events]], sent through [[PuduBridge]]. It runs on the main thread, where the activity is.

```java
final class PuduStore
static final int STORED = 31;
static final int PLAIN = 0, SECURE = 1;
static void read(int tag, int place, String key)
static void write(int place, String key, String value)
static void remove(int place, String key)
```

## Behavior

- Plain values live in the SharedPreferences file `org.pudu.store`, read and written as strings.
- Secure values live in the SharedPreferences file `org.pudu.store.secure`. Each value is encrypted with AES-GCM, no padding, under a 256-bit key that the Android Keystore holds under the alias `org.pudu.store`. The key is never exported. It is made on first use with encrypt and decrypt purposes only.
- A stored secure value is the base64 text, without line breaks, of a 12-byte nonce followed by the ciphertext, which carries the 128-bit authentication tag.
- A secure write generates a fresh nonce through the cipher. A failure of the keystore is written to standard error and the value is not stored.
- STORED is sent with the tag, the value as text and detail 1 when a value is present. When nothing is kept it is sent with empty text and detail 0.
- A secure value that cannot be decrypted, or cannot be decoded from base64, reads as absent and is removed from the file. This is the case of a backup restored onto another device, where the key does not exist.
- Plain writes and removals use `apply`, so they are written in the background after the call returns.

## Invariants

- Each STORE_READ sends exactly one STORED under its tag.
- The secure key never leaves the Keystore. The class holds a reference to a `SecretKey` only for the duration of one call.
- Every instruction runs on the main thread in stream order, so a read answers after every earlier write and removal.

## Negative Logic

- No fallback to plain storage when the keystore fails. A secure write that fails stores nothing.
- No key export or key copy. A backup carries the encrypted entries only, which are unreadable without the Keystore key.
- No read of a secure value that cannot be verified. The authentication tag is checked by the cipher; a mismatch is treated as unreadable.
- No value written to the log. The failure text names the keystore error only.

## Dependencies and consumers

Depends on `android.content.SharedPreferences`, `android.security.keystore.KeyGenParameterSpec` and `KeyProperties`, `android.util.Base64`, and the `javax.crypto` cipher classes. Called by [[PuduBridge]]; the activity is [[PuduActivity]]. Its iOS counterpart is [[pudu-ios-storage]]. Program side: [[Std Mobile Storage]].

## Resolved Grill Log

- **Q:** Why AES-GCM with a Keystore key rather than a password? **A:** The key is held by the platform and never exported, so the application holds no secret of its own that could be read from its files. GCM authenticates the ciphertext, so a changed entry is unreadable rather than wrong.
- **Q:** Why store the nonce with the ciphertext? **A:** The nonce is not secret but must be unique per encryption. Keeping it beside the value means one entry holds everything needed to decrypt it, and no second file must stay in step with the first.
- **Q:** Why treat an undecryptable value as absent and remove it? **A:** A value restored from a backup onto another device has no key to open it. Reporting an error would stop the program on data it cannot use. Absence lets the program ask again and store a fresh value, and removal keeps the file from carrying unreadable entries.
- **Q:** Why a separate file for secure values? **A:** The two places have different protection and different backup rules. A separate file keeps a plain read from touching encrypted data, and it lets the backup rules of the application exclude the secure file on its own.

## Referenced by

[[src/android/org/pudu/_MOC]] · [[PuduBridge]] · [[PuduActivity]] · [[pudu-ios-storage]] · [[Std Mobile Storage]] · [[Vault Example]] · [[NATIVE-MOBILE]]
