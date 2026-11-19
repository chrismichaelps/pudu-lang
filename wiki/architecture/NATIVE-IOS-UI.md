---
type: architecture
status: ACTIVE_DESIGN
tags: [architecture, native, mobile, ios, ui]
aliases: [Pudu Native iOS UI]
---

# Pudu Native on iOS: UI coverage

## Purpose

This page is the normative feature target for applications written in Pudu with FUI on iPhone,
iPad and iPhone Duo. Every feature below is realized through platform controls behind the
language-owned adapter of [[Pudu Native]]; no platform type reaches Pudu; a feature the adapter
cannot realize answers `UnsupportedPlatform`. The "Today" column records the honest state of the
toolchain and is updated as slices land. The iOS Xcode floor, tested version and store rules are in [[Native Platform Adoption]].

## Devices

- **iPhone:** all current and recent models, including Pro and Pro Max sizes. Layouts follow size
  classes and safe areas, never a model table.
- **iPad:** all current models, including Stage Manager and multiple windows. Scenes may be resized
  at any time and may run beside other apps.
- **iPhone Duo:** Apple's foldable, announced 2026-09-09, with a 5.4-inch outer display, a 7.6-inch
  inner display, and iOS 27.1.

Apple's developer announcement names a hinge API (display angle as the device opens and closes),
reserved-region and arrangement APIs (layouts across or beside the fold), scene accessories (content
on both displays), and Xcode 27.1 Device Hub simulation. Exact class names are taken from the iOS
27.1 SDK headers when the toolchain is installed; this page names concepts, not guessed identifiers.

## Feature areas

| Area | Required features | Today |
| --- | --- | --- |
| Layout and adaptivity | Flexible stack layout with native results; safe areas including Dynamic Island, notch, home indicator and the fold; compact, regular and expanded size classes; orientations; keyboard avoidance | partial: columns and rows, safe-area root bounds, safe-area insets reported to the program as values, docked keyboard avoidance, and scene size and size classes reported to the program; size-class layout policy and fold regions remain open |
| iPhone Duo | Fold state and posture reactions; outer, inner and both-display targeting; split view and multiple windows on the inner display; continuity across the fold; keeping interactive elements off the crease; layouts for 5.4 and 7.6 inches | missing |
| Navigation | Stack with interactive pop; tab bars; sidebars; modal styles (full screen, page sheet, form sheet, popover); large and collapsing titles; custom bars and toolbars; deep and universal links | partial: native stack, back actions and page sheets, with user pops and dismissals reported separately from programmatic changes; tab bars, deep links, custom transitions, other modal styles, physical-device frame-timing evidence and Android navigation remain open |
| Lists and scrolling | Recycling lists; sections and compositional layouts; adaptive grids; pull to refresh; prefetching and infinite scroll; nested scrolling | partial: vertical root scrolling, keyed insert/remove/move, recycling lists and equal-column grids with windowed rows, and pull to refresh, whose indicator follows the program's state; sections, compositional layouts beyond equal columns and nested scrolling remain open |
| Input and gestures | Tap, long press, pan, pinch, rotate, swipe; simultaneous and exclusive recognition; pointer; Apple Pencil; keyboard, input accessories and focus; Scribble | partial: tap, long press, pan, pinch, rotation and swipe recognizers, text entry, switch; pointer, Apple Pencil, focus and Scribble remain open |
| Visual system | FUI's seven aspects mapped to iOS values; Dynamic Type; light and dark appearance; materials and vibrancy; SF Symbols; semantic colors; elevation and continuous corners | partial: semantic color roles with platform or fixed light/dark tones, appearance override, Dynamic Type text styles; materials are done (glass on iOS 26 or later with blur fallback); symbols, elevation and continuous corners remain open |
| Feedback and system UI | Alerts, action sheets, confirmation dialogs, context menus and previews, banners, activity and progress indicators; status bar, Dynamic Island and home indicator styling | partial: alerts, action sheets, context menus, haptics, progress and activity indicators; confirmation dialogs, previews, banners and status bar styling remain open |
| Accessibility | VoiceOver; Dynamic Type; Reduce Motion; Increase Contrast; traits, labels, hints and values; keyboard focus; Switch Control | partial: accessible names, all 19 traits, hints and values reach the platform tree; Reduce Motion is honored by layout animation; custom actions, announcements and rotors remain open |
| Animation | Interactive transitions; shared-element transitions; fold-change layout animation; platform springs and curves; gesture-driven animation | partial: spring layout transitions for animated groups, honoring Reduce Motion; interactive, shared-element and gesture-driven transitions remain open |
| Multitasking | Stage Manager, Split View, Slide Over and multiple windows; the Duo inner display | missing |
| Platform conventions | System gestures; rotation and orientation lock; background and foreground transitions; state restoration | partial: background and foreground transitions reported to the program; system gestures, orientation lock and state restoration remain open |

## ProMotion and frame pacing

Refresh rate is a capability of the active display. On ProMotion devices, the iOS pipeline
supports variable refresh up to 120 Hz. The system can select a lower rate for the display,
power or thermal conditions, accessibility settings, or competing content. The same input
and animation state must progress correctly across those changes and on 60 Hz devices.

- Generated iOS apps set `CADisableMinimumFrameDurationOnPhone` to true so Core Animation
  can honor higher-rate timing hints on capable iPhones. UIKit scrolling and system
  transitions use platform frame pacing.
- View updates preserve ordered input and reconcile state into bounded batches. Reuse mounted
  controls, skip empty batches, and avoid rebuilding, remeasuring, or laying out unaffected
  subtrees during scrolling. Presentation may coalesce superseded intermediate visual state
  while still processing every ordered input and application effect.
- For future custom presentation, use a display link for the active screen with an adaptive
  `preferredFrameRateRange`. Sample motion from monotonic elapsed time and the actual
  presentation target. A display link runs only while there is visual work and stops when
  the app is idle or inactive.
- A 120 Hz refresh interval is about 8.33 ms. That interval covers the entire frame, including
  system work. Observe the actual presentation deadline and measure input handling, view
  reconciliation, encoding, native application, layout, and presentation separately.
- Validate steady scrolling and interactive transitions on named physical 60 Hz and ProMotion
  devices, including rate changes and Low Power Mode. Report observed refresh intervals,
  missed deadlines, frame-time percentiles and input-to-presentation latency. Simulator tests
  validate bundle configuration and behavior. Physical traces establish the performance claim.

Today the app bundle enables higher-rate timing hints, the vertical viewport uses UIKit
scrolling, and empty updates stay on the Pudu side of the host boundary. Custom display-link
scheduling and physical frame-time evidence remain open.

[Apple's ProMotion frame-pacing guidance](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays)

## Phases

| Phase | Scope |
| --- | --- |
| A Foundation | Core layout, primitives, safe areas, variable-rate frame-pacing foundations, theming, basic navigation, accessibility foundation, single-screen iPhone and the Duo outer display |
| B Foldable and large canvas | Duo fold state, display targeting, crease awareness, Split View, inner-display layouts, iPad multiple windows basics |
| C Polish and productivity | Advanced lists, Apple Pencil, rich animation, Stage Manager, context menus, full multitasking |

Phase A and the size-class adaptivity of Phase B build on the generic platform APIs (scenes, trait
collections, safe areas and layout guides) available in the installed SDK. The Duo hinge,
reserved-region and scene-accessory work needs the iOS 27.1 SDK and Xcode 27.1, which this machine
does not have yet (Xcode 26.6, iOS 26.5 SDK).

## Order of work

1. Scrolling and safe areas with docked keyboard avoidance ([[Native iOS Scrolling Delivery]]).
2. Navigation stack and modal sheets. See [[Native iOS Navigation]].
3. Theming: FUI tokens to semantic colors, Dynamic Type, dark mode ([[Native iOS Theming Delivery]]).
4. Recycling lists and grids ([[Native iOS Recycling Delivery]]).
5. Size-class adaptivity and multiple windows.
6. iPhone Duo APIs once the 27.1 SDK is installed.
7. Gestures, animation, context menus and system UI.

## UIKit coverage

Each row lists what the toolchain realizes today and what is next. The measured inventory below the table is generated by [[UIKit Coverage Inventory]] from the installed SDK's headers and the host sources.

| Area | Covered now | Next |
| --- | --- | --- |
| Controls | label, button, field, toggle, progress, activity, material, list and grid | slider, stepper, segmented control, date picker, picker, text view, search field, image and symbols, page control, color well |
| Gestures | long press, pan, pinch, rotation, swipe | tap counts, screen-edge pan, hover, pointer, Pencil |
| Accessibility | names, all 19 traits, hints, values | custom actions, live announcements, rotors, grouping |
| Feedback | alerts, action sheets, haptics (selection, impact, notification), indicators | canvas feedback on Pencil Pro |
| Presentation | navigation stack and page sheets (#920) | detents, popovers, full-screen styles |
| Adaptivity | size classes, scene size, lifecycle | multiple windows, state restoration |
| Visual | semantic colors, appearance, Dynamic Type, materials with glass | SF Symbols, glass button configurations, continuous corners |
| Animation | spring layout transitions honoring Reduce Motion | interactive and shared-element transitions, symbol effects |
| System services | none | pasteboard, share sheet, drag and drop, document and photo pickers, notifications, open URL; reached through platform FFI (#874) where they are not UI |

### Measured inventory

<!-- uikit-coverage:start -->
Measured against `iPhoneSimulator26.5`.

| Category | Covered | In the host | Not in the host |
| --- | --- | --- | --- |
| Controls | 4 of 12 | `UIButton`, `UIRefreshControl`, `UISwitch`, `UITextField` | `UIColorWell`, `UIDatePicker`, `UIPageControl`, `UIPasteControl`, `UISearchTextField`, `UISegmentedControl`, `UISlider`, `UIStepper` |
| Views | 9 of 33 | `UIActivityIndicatorView`, `UICollectionView`, `UICollectionViewCell`, `UILabel`, `UIProgressView`, `UIScrollView`, `UIStackView`, `UIVisualEffectView`, `UIWindow` | `UIActionSheet`, `UIAlertView`, `UIBackgroundExtensionView`, `UICalendarView`, `UICollectionReusableView`, `UICollectionViewListCell`, `UIContentUnavailableView`, `UIControl`, `UIEventAttributionView`, `UIImageView`, `UIInputView`, `UIListContentView`, `UINavigationBar`, `UIPickerView`, `UIPopoverBackgroundView`, `UISearchBar`, `UIStandardTextCursorView`, `UITabBar`, `UITableView`, `UITableViewCell`, `UITableViewHeaderFooterView`, `UITextView`, `UIToolbar`, `UIWebView` |
| Gestures | 5 of 7 | `UILongPressGestureRecognizer`, `UIPanGestureRecognizer`, `UIPinchGestureRecognizer`, `UIRotationGestureRecognizer`, `UISwipeGestureRecognizer` | `UIScreenEdgePanGestureRecognizer`, `UITapGestureRecognizer` |
| Feedback | 3 of 4 | `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, `UISelectionFeedbackGenerator` | `UICanvasFeedbackGenerator` |
| Accessibility traits | 19 of 19 | `UIAccessibilityTraitAdjustable`, `UIAccessibilityTraitAllowsDirectInteraction`, `UIAccessibilityTraitButton`, `UIAccessibilityTraitCausesPageTurn`, `UIAccessibilityTraitHeader`, `UIAccessibilityTraitImage`, `UIAccessibilityTraitKeyboardKey`, `UIAccessibilityTraitLink`, `UIAccessibilityTraitNotEnabled`, `UIAccessibilityTraitPlaysSound`, `UIAccessibilityTraitSearchField`, `UIAccessibilityTraitSelected`, `UIAccessibilityTraitStartsMediaSession`, `UIAccessibilityTraitStaticText`, `UIAccessibilityTraitSummaryElement`, `UIAccessibilityTraitSupportsZoom`, `UIAccessibilityTraitTabBar`, `UIAccessibilityTraitToggleButton`, `UIAccessibilityTraitUpdatesFrequently` | none |
<!-- uikit-coverage:end -->

## Grill Log

- **Q:** Name the Duo's classes now from third-party descriptions? **A:** No. Identifiers come from
  the SDK headers once installed. _Rejected:_ guessed APIs.
- **Q:** Treat the Duo as a special case everywhere? **A:** No. Its displays arrive as scene
  geometry and size-class changes, so adaptive layouts carry most of it; only hinge posture and
  reserved regions need Duo APIs. _Rejected:_ device checks.

- **Q:** Who owns cell reuse? **A:** The platform; Pudu owns identity and the window of row models. See [[iOS Host List]].

- **Q:** When is the root keyboard layout guide installed? **A:** After the UIKit window becomes visible, so the guide observes the active window. See [[iOS Host Layout]].

- **Q:** Should a 120 Hz display rebuild the Pudu tree at every refresh? **A:** UIKit owns native motion. Application state changes produce view commits, and custom animation samples presentation time only while active.

- **Q:** Does a light/dark switch rebuild the Pudu tree? **A:** No; fixed tones are dynamic platform colors and text styles follow content size automatically.

## Referenced by

[[architecture/_MOC]] · [[Pudu Native]] · [[Native iOS Scrolling Delivery]] · [[Native iOS Theming Delivery]] · [[Native iOS Recycling Delivery]] · [[Native iOS Materials Delivery]] · [[Native iOS Capabilities Delivery]] · [[Native iOS Refresh Delivery]]
