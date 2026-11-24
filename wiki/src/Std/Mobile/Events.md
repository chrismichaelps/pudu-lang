---
type: module
path: "@root/lib/Std/Mobile/Events.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Events]
---

# Std Mobile Events

## Purpose and interface

Pure decoder of host events. The host hands the program one 64-bit word per event: the kind in the high 32 bits and the tag in the low 32 bits. Some kinds also carry text, one detail word, or up to four signed words, which the host holds until the program fetches them. This module turns that word and those values into a [[Std Mobile View]] `Event`. It is used only by [[Std Mobile Host]], which performs the fetches.

Exports:
- `carriesText(raw: UInt64) -> Bool`: whether the event's text must be fetched before decoding. True for kinds 3, 18, 27, 30 and 31.
- `carriesDetail(raw: UInt64) -> Bool`: whether the kind is listed in `DETAILED` or `MEASURED`, so the detail word must be fetched first.
- `carriesWords(raw: UInt64) -> Bool`: whether the kind is listed in `MEASURED` or is FETCHED, so its signed words must be fetched first.
- `signed(bits: UInt32) -> Int32`: the two's complement reading of a host word.
- `event(raw: UInt64, text: Str) -> View.Event`: decodes an event that needs no detail or words.
- `eventWithDetail(raw: UInt64, text: Str, detail: UInt32) -> View.Event`: decodes a detailed event with the detail word the host fetched.
- `eventWithWords(raw: UInt64, text: Str, detail: UInt32, values: Array[Int32]) -> View.Event`: decodes an event with its detail word and signed words. A measured kind decodes through `MEASURED`, a detailed kind through `DETAILED`, and every other kind through `event`.

Kind codes: IMAGED 24 (#973); OPENED 25, SHARED 26 and PASTED 27 (#974); PERMISSIONED 28 (#976); SELECTED 29 (#977); LINKED 30 (#978); STORED 31 (#980); DESCRIBED 32 and NETWORKED 33 (#983); LOCATED 34 (#986); TAPPED 1, Stopped 2 (the host's stop), CHANGED 3, SWITCHED_ON 4, SWITCHED_OFF 5, REACHED 8, GESTURED 9, CHOSE 10, RESIZED 11, LIFECYCLE 12, PICKED 13, POPPED 14, DISMISSED 15, REFRESHED 16, INSETS 17, FETCHED 18, WOKE 19, MEMORY 20, VALUED 21, COLORED 22, DATED 23.

Event payloads by kind:
- POPPED (14): the tag is the route that was on top, and the detail word is the surviving destination route.
- DISMISSED (15): the tag is the dismissed sheet. It is listed in `EVENTS`, so it carries no detail word.
- GESTURED (9) and RESIZED (11) read their signed words through `Gesture.decoded` and `Scene.sized`. A missing word reads as `Stopped`.
- LIFECYCLE (12) reads its phase code through `Scene.phase`.
- REFRESHED (16) carries its tag only and is listed in `EVENTS`. It names the scroll or list whose refresh control the user pulled.
- INSETS (17) reads four signed words through `Scene.insets`, in the order top, left, bottom and right. Fewer than four words read as `Stopped`.
- FETCHED (18) carries the generation as its tag, the status as its detail word, the body as its text, and the Retry-After delay as its first word, -1 when absent. It decodes to `Fetched(generation, status, body, retryAfter)`. A missing status reads as 0 and a missing word as -1.
- WOKE (19) carries nothing and decodes to `Woke`.
- MEMORY (20) carries nothing and decodes to `MemoryLow`.
- VALUED (21): the tag is the value control and the detail word is its value, read as a signed word. A slider or stepper sends low plus index times step, a segmented control or wheel its option index, a page indicator its page index. Decodes to `Valued(tag, value)`.
- COLORED (22): the tag is the color well and the detail word is its RGBA value, red in the high byte. Decodes to `Colored(tag, rgba)`.
- DATED (23): the tag is the date picker. Its seconds are two words, high then low, combined into one 64-bit value. Decodes to `Dated(tag, seconds)`.

Dispatch is three constant tables:
- `EVENTS` maps a kind to its tag-and-text decoder.
- `DETAILED` maps a kind to its tag-and-detail decoder. VALUED (21) and COLORED (22) are listed there.
- `MEASURED` maps a kind to its tag, detail and signed-word decoder. INSETS (17) is listed there. DATED (23) is listed there too: its detail word is fetched and ignored, and its two words are the seconds, high then low.

## Images (#973)

- IMAGED (24): the tag is the image node; the detail word is 1 when the source is shown and 0 when it could not be. Any other detail word is refused and decodes to `Stopped`. Decodes to `Imaged(tag, loaded)`. The `flagged` helper reads the 1 and 0 detail word of IMAGED, OPENED and SHARED alike.

## System reports (#974)

- OPENED (25): the tag is the open request; the detail word is 1 when the platform opened the URL and 0 when it did not. Decodes to `Opened(tag, opened)` through `flagged`.
- SHARED (26): the tag is the share request; the detail word is 1 when the person shared or, on Android, when the chooser opened, and 0 when the sheet closed without a share. Decodes to `Shared(tag, shared)` through `flagged`.
- PASTED (27): the tag is the paste request and its text is the clipboard's text, empty when there was none. PASTED is listed in `EVENTS`, so its text is fetched and it decodes to `Pasted(tag, text)`.
- PERMISSIONED (28): the tag is the permission kind code and the detail word is the state code. Kind codes and state codes are those of [[Std Mobile Permission]]. The kind is read through `kindOf` and the state through `stateOf`, and the event decodes to `Permissioned(kind, state)`. A kind code past 10, or a state code past 6, decodes to `Stopped`. Kind 28 is listed in `DETAILED`, so the detail word is fetched first.
- SELECTED (29): the tag is the picked tab's id, and the event carries no detail word. It decodes to `Selected(tab)`. The host reports only tabs it shows.
- STORED (31): the tag is the read request; the text is the stored value, empty when nothing is kept; the detail word is 1 when a value is present and 0 when it is absent. Decodes to `Stored(tag, Some(text))` or `Stored(tag, None)`. Any other detail word reads as `Stopped`. STORED is listed in `DETAILED` and carries text (#980).
- LINKED (30): the text is the URL the platform handed the application; the tag and detail are not used. It decodes to `Linked(url)`. The host queues it at launch and while the application runs (#978).
- Any other detail word for OPENED or SHARED reads as `Stopped`.

## Device (#983)

- DESCRIBED (32): the tag is the DEVICE request's tag. The text is five lines joined by a newline: the platform (`ios` or `android`), the system version, the hardware model, the preferred language tag (BCP 47), and the time zone (IANA id). The detail word is the preferred text scale in percent, 100 at the default. Text that is not exactly five lines, or names an unknown platform, decodes to `Stopped`. Decodes to `Described(tag, facts)` through `Device.facts`.
- NETWORKED (33): the tag is 0. The detail word is the link code: 0 Offline, 1 Wifi, 2 Cellular, 3 Wired (wired or any other interface). Codes above 3 decode to `Stopped`. Decodes to `Networked(link)` through `Device.linkOf`.
- The host sends NETWORKED once when watching starts, or when NETWORK 1 arrives while watching already with the last known link, and again on each change of link kind.

## Location (#986)

- LOCATED (34): a measured kind. The tag is the LOCATE's tag, or 0 for a report of a TRACK. Detail 1 is followed by exactly four signed words: latitude and longitude in ten-millionths of a degree, horizontal accuracy in meters (rounded up), and altitude in meters. Detail 0 carries no words and means no position is available: the permission is not allowed, location services are off, the platform failed, or no fix arrived within the timeout. Any other shape decodes to `Stopped`. Decodes to `Located(tag, position)` through `Location.position`.

## Invariants

- Pure: the module declares no foreign function and performs no fetch. The host fetches text, detail and words, and passes them in.
- Words the host never writes read as `Stopped`. A measured or detailed kind whose detail or words do not decode also reads as `Stopped`.
- `event` never fails. An unknown kind ends the loop the same way `Stopped` does.
- `carriesDetail` is true only for kinds in `DETAILED` and `MEASURED`, and for FETCHED, STORED and DESCRIBED. `carriesWords` is true only for kinds in `MEASURED` and for FETCHED. `carriesText` is true only for kinds 3, 18, 27, 30, 31 and 32.
- A tap names only its tag. A toggle names its tag and new state. Only `Changed` carries text, and that text is never packed into the 64-bit value.
- `signed` reads a word with its top bit set as negative.

## Negative Logic

- No I/O and no platform call. The foreign boundary is in [[Std Mobile Host]].
- No view tree or reconciliation. Those are in [[Std Mobile View]].
- No fetch of text, detail or words. The predicates say which fetches a value needs; the host performs them.
- No detail is read for a kind outside `DETAILED` and `MEASURED`.

## Dependencies and consumers

Depends on [[Std Mobile View]] for the `Event` type and its constructors, on [[Std Mobile Gesture]] for `Gesture.decoded` (kind 9), on [[Std Mobile Scene]] for `Scene.sized` (kind 11), `Scene.phase` (kind 12) and `Scene.insets` (kind 17). Consumers: [[Std Mobile Host]], whose `wait` calls the three predicates and the decoders in order. [[Std Mobile View]] exports no decoder; the decoders live in this module.

## Resolved Grill Log

- **Q:** Why a module apart from View? **A:** View holds the tree and its reconciliation; decoding the host's words is a separate boundary used only by Std.Mobile.Host, and keeping it apart keeps both modules under the size limit.
- **Q:** Why does a pop carry both routes? **A:** The platform may pop several routes in one back action; the reducer needs the previous top and the destination to refuse a stale report.

- **Q:** Why are seconds two words rather than one? **A:** Seconds since the epoch do not fit one 32-bit word; two words keep the 64-bit value exact. _Rejected:_ a float value.

## Services (#989)

- NOTIFIED 35: tag = the id of a notification the person tapped, also when the tap launched the application. No detail or text. Decodes to `Notified(id)`.
- AUTHENTICATED 36: tag; detail 1 confirmed, 0 not (failed, cancelled, or no biometrics or passcode set). Decodes to `Authenticated(tag, Bool)`.
- BROWSED 37: tag; no detail. Decodes to `Browsed(tag)`.
- SPOKE 38: tag; detail 1 finished, 0 interrupted. Decodes to `Spoke(tag, Bool)`.
- POWERED 39: tag; detail is the charge state (0 unknown, 1 unplugged, 2 charging, 3 full); one word is the level in percent, -1 when unknown. Decodes through `Device.power` to `Powered(tag, Device.Power)`.
- SENSED 40: tag 0; three signed words are the acceleration on x, y and z in milli-g. Decodes through `Device.motion` to `Sensed(Device.Motion)`.
- IMAGE_PICKED 41: tag; detail 1 with the text as the path of a copy in the application's temporary directory, or detail 0 with empty text when the person cancelled. Decodes to `ImagePicked(tag, Option[Str])`. The text is carried by `carriesText`.

Malformed POWERED and SENSED shapes decode to Stopped.

## Web, video and audio (#990)

- LOADED 42: tag = the web node's tag; detail 1 when the page finished loading, 0 when it failed. Decodes to `Loaded(UInt32, Bool)`. One LOADED answers each load the program requested.
- ENDED 43: tag = the video node's or the sound's tag. A non-looping video or sound reached its end. Decodes to `Ended(UInt32)`.
- BACKED 44: tag 0. The person used back while the program receives it. Decodes to `Backed`.
- Malformed shapes of LOADED, ENDED and BACKED decode to `Stopped`.

## Pickers and system touches (#991)

- CONTACT_PICKED 45: tag. Detail 1 with text of three lines: the name, the phone numbers joined by `,`, and the email addresses joined by `,`. Detail 0 with empty text when cancelled.
- FILED 46: tag. Detail 1 with text the path of a file in the temporary directory (a picked document, a photo, or a finished recording). Detail 0 with empty text when cancelled, unavailable or failed.

## System sheets (#994)

- COMPLETED 47: tag; detail 1 when the person finished the sheet (saved the event, sent the mail or message), 0 when they cancelled or the sheet could not open. A platform that cannot see the outcome reports 1 once the sheet opens, as sharing does. Decoded as `Completed` in [[Std Mobile View]]. A detail above 1 is malformed and stops the stream.

## Referenced by
 · [[Viewer Example]] · [[PuduWeb]]
[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Host]] · [[Std Mobile Navigation]] · [[pudu_ios_navigation.h]] · [[pudu_ios_refresh.h]] · [[Std Mobile Control]] · [[pudu-ios-values]]
