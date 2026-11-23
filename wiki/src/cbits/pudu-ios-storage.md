---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_storage.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, storage, objective-c]
aliases: [iOS Host Storage, pudu-ios-storage]
---

# pudu-ios-storage

## Purpose and interface

Key-value storage of the iOS host: user defaults for plain values and the keychain for secure values. Included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It implements the handlers of instructions STORE_READ (55), STORE_WRITE (56) and STORE_REMOVE (57) of [[Std Mobile Stream]]. Its one report is STORED (31) of [[Std Mobile Events]], queued through [[iOS Host Events]].

```text
static void pudu_do_store_read(pudu_reader *reader)
static void pudu_do_store_write(pudu_reader *reader)
static void pudu_do_store_remove(pudu_reader *reader)
static uint32_t pudu_store_place(pudu_reader *reader)
static NSMutableDictionary *pudu_keychain_item(NSString *key)
```

## Behavior

- Place 0 (Plain) reads and writes `NSUserDefaults.standardUserDefaults`. Place 1 (Secure) reads and writes the keychain.
- The keychain item is a generic password. Its service is the bundle identifier, or `org.pudu` when none is set. Its account is the key. The item is accessible after the first unlock, on this device only (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), so it is not migrated to another device or into a backup.
- Write updates an existing item first. Only when the update finds nothing does it add the item with the value and the accessibility attribute. A failed add is written to standard error with its status.
- STORE_READ 55 names the tag, the place and the key. It queues STORED with the value as text and detail 1 when a value is present. When nothing is kept it queues an empty text with detail 0.
- STORE_WRITE 56 names the place, the key and the value. It reports nothing.
- STORE_REMOVE 57 names the place and the key. It reports nothing. Removing an absent key is not an error.
- A place code of 2 or more is refused as a stream defect with `used unknown store`, through the same path as the other instructions.

## Invariants

- Each STORE_READ queues exactly one STORED under its tag.
- Every handler runs on the main thread in stream order, so a read answers after every earlier write and removal.
- The keychain query is built in one place (`pudu_keychain_item`), so reads, writes and removals name the same item.

## Negative Logic

- No retry of a refused keychain write. The write is reported on standard error, and the program is not told; a later read answers absent.
- No migration of values between places. A value written to one place is not copied to the other.
- No value written to the log. The status is printed; the value is not.
- No keychain access group. The item belongs to the application alone.

## Dependencies and consumers

Depends on Foundation (`NSUserDefaults`, `NSString`, `NSData`), Security (`SecItemCopyMatching`, `SecItemUpdate`, `SecItemAdd`, `SecItemDelete`), [[iOS Host Events]] for the queue, and [[pudu-ios-kinds]] for the instruction table. The application links the Security framework, which the host declares with the other system frameworks. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Storage]], [[Std Mobile Stream]] and [[Std Mobile Events]].

## Resolved Grill Log

- **Q:** Why user defaults for Plain and the keychain for Secure? **A:** User defaults are the platform's settings store and are kept with the application. The keychain is the platform's protected store; its items are encrypted at rest. Using the keychain for settings would make ordinary values as hard to inspect and back up as secrets, for no gain.
- **Q:** Why write updates and then adds? **A:** An update of an existing item keeps its attributes. Adding first would fail on an existing item, and a delete before every write would leave a gap in which a read answers absent.
- **Q:** Why this device only? **A:** A secret carried by a backup to another device is readable there with nothing else. The attribute keeps the item on the device that wrote it.
- **Q:** Why report the failed write on standard error and not as an event? **A:** A write reports nothing by design, as [[Std Mobile Storage]] states. A failure is a platform fault the program cannot act on beyond reading again, and the next read reports absence.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[pudu-ios-system]] · [[Std Mobile Storage]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Vault Example]] · [[Uses Mobile Storage]] · [[NATIVE-MOBILE]]
