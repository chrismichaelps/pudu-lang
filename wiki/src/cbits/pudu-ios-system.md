---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_system.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, system, objective-c]
aliases: [iOS Host System, pudu-ios-system]
---

# pudu-ios-system

## Purpose and interface

System requests of the iOS host: opening a URL, the share sheet, the clipboard and the status bar. Included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It implements the handlers of instructions OPEN (46), SHARE (47), COPY (48), PASTE (49) and STATUS (50) of [[Std Mobile Stream]]. Its reports are OPENED (25), SHARED (26) and PASTED (27) of [[Std Mobile Events]], queued through [[iOS Host Events]]. The status bar style is drawn by the root controller of [[pudu-ios-scene]].

```text
static void pudu_system_open(uint32_t tag, NSString *url)
static void pudu_system_share(uint32_t tag, NSString *text)
static void pudu_system_copy(NSString *text)
static void pudu_system_paste(uint32_t tag)
static void pudu_system_status(uint32_t style, uint32_t hidden)
static void pudu_ui_system_test(void)
```

## Behavior

- OPEN 46 names the tag and the URL text. A URL that does not parse, or has no scheme the system can open, reports OPENED with 0 at once. Otherwise the URL is opened through the shared application's `openURL` with a completion handler; the completion reports OPENED with 1 when the system accepted it and 0 when it refused.
- SHARE 47 names the tag and the text. The activity controller is presented from the top presented controller of the root. On iPad the popover is anchored at the centre of the screen. The completion handler reports SHARED with 1 when the controller reports the activity as completed and 0 when it was dismissed.
- COPY 48 writes the text to the general pasteboard. It reports nothing.
- PASTE 49 reads the general pasteboard's string. It reports PASTED with the string as text. When the pasteboard holds no string, the text is empty.
- STATUS 50 takes a style code 0 to 2 and a hidden flag 0 or 1. The style is applied by the root controller of [[pudu-ios-scene]]; the hidden flag sets the controller's status bar hidden state and asks the system to update it.
- The refusals are reported as defects through the same path as the other instructions: a style code of 3 or more is refused with `used unknown status bar style`, and a hidden flag other than 0 or 1 with `set the status bar hidden to`.

Self-test: `PUDU_UI_SYSTEM_TEST` presents the share sheet once and sets the status bar to light text, then prints `PUDU_SYSTEM share shown` and `PUDU_SYSTEM status light shown`. It does not wait for a person to choose a target.

## Invariants

- Each OPEN, SHARE and PASTE request reports exactly one answer under its tag.
- A SHARE is never presented while another activity controller is on top of the root; the request is refused rather than stacked.
- The status bar style is only written from the main thread.

## Negative Logic

- No retry of a refused URL. The program decides whether to ask again.
- No read of the pasteboard except by PASTE. COPY and PASTE never change anything else on the device.
- No outcome for COPY and STATUS. They are applied and reported nothing.
- No share target choice. The system sheet decides the target; the host sees only the completion.

## Dependencies and consumers

Depends on UIKit (the activity controller, the pasteboard, the status bar and the popover presentation), Foundation's URL and the shared application's `openURL`, [[iOS Host Events]] for the queue, and [[pudu-ios-kinds]] for the instruction table. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile System]], [[Std Mobile Stream]] and [[Std Mobile Events]]. Status bar drawing: [[pudu-ios-scene]].

## Resolved Grill Log

- **Q:** Why does SHARE report completion rather than "presented"? **A:** The iOS controller reports whether the person completed an activity, so the outcome is known. Presenting is only the start of the request.
- **Q:** Why anchor the popover at the screen centre? **A:** An iPad presents a share sheet as a popover, which needs an anchor. The request names no view, so the centre is the one anchor that is always on screen.
- **Q:** Why refuse a second share rather than stack it? **A:** Two sheets over one controller leave the first one's completion waiting behind the second. The program receives one answer per request, so the second is refused.
- **Q:** Why does the status bar live in the root controller? **A:** The root controller does not defer the style to a child, so the scene keeps one setting and no child changes it behind the program.

## Link self-test (#978)

`pudu_test_link` opens the URL named by `PUDU_UI_LINK_TEST` with `openURL:options:completionHandler:`, prints `PUDU_SYSTEM link opened` or `refused` from the completion, and waits 1.5 seconds so the link can return to the program as LINKED. Then the done block queues STOPPED. The URL must use a scheme the application declares; [[Links Example]] passes `pudulinks://hello?from=test`. Hosted by [[iOS Host Adapter]].

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[pudu-ios-scene]] · [[pudu-ios-kinds]] · [[Std Mobile System]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Services Example]] · [[Uses Mobile System]] · [[NATIVE-MOBILE]]
