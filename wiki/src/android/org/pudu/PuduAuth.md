---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduAuth.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, authentication]
aliases: [PuduAuth]
---

# PuduAuth

## Purpose and interface

Device-owner confirmation on the Android host (#989). The class is called from [[PuduBridge]] when an AUTHENTICATE instruction arrives, through the handler registered in [[pudu-android-services]]. The answer is AUTHENTICATED (36) of [[Std Mobile Events]], with detail 1 when the person confirmed and 0 otherwise.

## Behavior

- On API 28 and later, the prompt is a BiometricPrompt. On API 29 and later, the device credential is allowed as well as biometrics.
- Below API 28, the prompt is the confirm-credential activity of KeyguardManager.
- A device with no lock set answers `false` at once, without showing a prompt.
- The result of the prompt returns to [[PuduActivity]] in `onActivityResult`, which routes it here by request code.
- A failed, cancelled or unavailable prompt answers `false`.

## Invariants

- Each AUTHENTICATE sends exactly one AUTHENTICATED under its tag.
- The prompt is shown on the main thread, and the answer is queued in stream order.

## Negative Logic

- No credential is read or stored. The platform returns only the outcome.
- No retry after a failure. The program decides whether to ask again.
- No report of the factor used, since the platforms do not offer one in a common form.

## Dependencies and consumers

Depends on BiometricPrompt, KeyguardManager, the activity result path of [[PuduActivity]] and the permission declaration for biometrics. Called by [[PuduBridge]]. Its counterpart on iOS is the authentication handler of [[pudu-ios-services]]. Program side: [[Std Mobile Auth]].

## Resolved Grill Log

- **Q:** Why is a device with no lock answered `false` without a prompt? **A:** No confirmation can be made, so a prompt would only fail. Answering `false` at once releases the waiting tag.
- **Q:** Why is the credential allowed on API 29 and later? **A:** A person without biometrics can still confirm with the device passcode. Restricting the prompt to biometrics would refuse them with no route through.
- **Q:** Why route the answer by request code? **A:** The activity handles more than one prompt. The request code names which handler the answer belongs to.

## Referenced by

[[src/android/org/pudu/_MOC]] · [[PuduBridge]] · [[PuduActivity]] · [[pudu-android-services]] · [[Std Mobile Auth]] · [[NATIVE-MOBILE]]
