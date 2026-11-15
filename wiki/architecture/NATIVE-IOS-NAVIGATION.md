---
type: architecture
status: ACTIVE_DESIGN
tags: [architecture, native, mobile, ios, navigation]
aliases: [Native iOS Navigation]
---

# Native iOS Navigation

## Scope

Phase A of [[Pudu Native iOS UI]] adds a native page stack followed by one
page sheet. The platform controls rendering and interactive transitions.
The application controls what routes exist, the visible stack, and the
sheet. Its state can use the root-preserving stack operations of
[[Std Ui Navigation]] and validated by [[Std Mobile Navigation]]. The mobile presenter consumes route bodies
described by [[Std Mobile View]], including a root scroll viewport.

[Pudu Foundation UI](https://github.com/chrismichaelps/pudu-lang-fui) owns any shared
navigation component exposed to app authors across web, iOS, and Android. This specification
governs the mobile route and presentation primitives used by its native renderers.

## State and identity

- The app supplies a root route, ordered pushed routes, and at most one
  page sheet. Each route instance has an application-supplied UInt32 ID,
  title, and body. A sheet has its own instance ID and body. IDs must be
  unique within a presentation and must not be reused while an event for
  the earlier instance can still be pending.
- A body or title edit keeps the route's controller and reconciles the body
  in place. The same route at the same position in the common stack prefix
  retains its controller. Replacing or removing a route ends its instance.
  The wire node ID and application route ID have distinct lifetimes.
- A malformed presentation with duplicate IDs is refused before the host
  mounts any part of that navigation update. The root element cannot be
  removed by back navigation.

## UIKit ownership

The adapter uses a UINavigationController and one child controller per route.
Each route controller applies the existing safe-area and docked-keyboard
policy to its own surface. UIKit draws navigation items and provides the
native back button and interactive pop. The sheet uses the platform page
sheet presentation and its dismissal delegate.

The host mutates the platform stack once per received presentation update.
Inside a platform transition, the host keeps the latest desired presentation
and applies it when the transition completes. It retains controllers and
their mounted nodes until UIKit releases the transition. This keeps a late
completion from addressing a recycled wire node or displaying a removed
route. The update that already requested a destination takes precedence over
an older in-flight user transition.

## Events and reconciliation

- The host compares the final UIKit stack with the prior accepted desired
  stack when the navigation delegate reports a completed show. A user pop
  reports the previous top and the surviving destination instance. The
  destination can be below the immediately preceding route. Cancellation
  produces no event. UIKit callbacks from programmatic requests produce
  no user event.
- Native sheet dismissal reports the dismissed instance once after the
  platform confirms dismissal. A canceled gesture and programmatic dismissal
  produce no event. A pending dismissal for an old instance cannot close
  a replacement sheet.
- The app applies a pop only when its current top matches the reported
  previous top and the destination exists below it. The reducer trims the
  suffix after the destination. The reducer clears a sheet only when its
  current instance is the one reported.
- A current completion is acknowledged through the next presentation update.
  If the application keeps its old state, that update must explicitly
  resend the authoritative stack or sheet. Ordinary empty view edits still
  skip the host crossing. A superseded completion is ignored by the host.

## Frame pacing and acceptance

UIKit owns the timing of pushes, pops and sheet transitions. There is no
per-refresh Pudu view rebuild, extra display link, or fixed timer for
transitions. Collect physical-device traces against the cadence and latency
criteria in [[Pudu Native iOS UI#ProMotion and frame pacing]].

1. Add exact stream and event fixtures for mount, push, title and body edits,
   pop to an earlier route, duplicate-ID refusal, and stale events.
2. Launch a compiler-built simulator app with a scrollable page body. Verify
   that the native back button and a completed interactive pop each produce
   one event. A canceled interactive pop must leave the same top page and
   produce no event. Verify that a programmatic pop generates no echo.
3. Verify page sheet focus, user and programmatic dismissal, cancellation,
   and rapid replacement. Verify that an old callback cannot dismiss the
   replacement sheet. Run existing mobile smoke tests and repository gates.
4. Capture transition timing on a physical ProMotion device and a 60 Hz
   device before claiming frame-pacing coverage.

## Resolved Grill Log

- **Q:** Should UIKit be authoritative for route state? **A:** Pudu's model
  owns route identity and restoration. UIKit reports completed input and
  presents the current desired state.
- **Q:** Report a back event when the swipe begins? **A:** Wait for UIKit
  completion and compare the final stack. An aborted gesture cannot change
  the program's model.
- **Q:** Why identify both ends of a pop? **A:** UIKit may skip several routes
  in a back action. The reducer needs the surviving route and the previous top
  to reject stale completions without removing a newly pushed page.

[UIKit navigation completion](https://developer.apple.com/documentation/uikit/uinavigationcontrollerdelegate/navigationcontroller(_:didshow:animated:)) · [UIKit presentation dismissal](https://developer.apple.com/documentation/uikit/uiadaptivepresentationcontrollerdelegate/presentationcontrollerdiddismiss(_:))

## Referenced by

[[Pudu Native iOS UI]] · [[architecture/_MOC]] · [[Native iOS Navigation Delivery]]
