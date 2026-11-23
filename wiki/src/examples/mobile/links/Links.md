---
type: module
path: "@root/examples/mobile/links/Links.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, link]
aliases: [Links Example]
---

# Links Example

## Purpose and interface

A program that shows the last link that opened it. Its own `pudu.toml` declares the application under `[app]`: name `Pudu Links`, identifier `dev.pudu.links`, version `2.3.1`, build `42`, and the scheme `pudulinks`. The build checks each value with [[Pudu Backend Identity]] and writes it into the bundle and the package.

The view is one label, `Link: <url>`. It reads `Link: none` until a link arrives. The program uses [[Std Mobile View]] for the tree and the `Linked` event, and [[Std Mobile Host]] for the apply and wait calls. A `Linked(url)` event replaces the stored link and the label is rebuilt from it. A `Stopped` event ends the program.

The example has no other state and no timer. A link that arrives while the application runs replaces the label; a link that launches it is the first event the program reads.

## Manifest

```toml
[app]
name = "Pudu Links"
identifier = "dev.pudu.links"
version = "2.3.1"
build = 42
schemes = ["pudulinks"]
```

The identifier is declared, so the Android package is `dev.pudu.links` and the iOS bundle identifier is the same string. The scheme is the only URL scheme the bundle and the Android activity open.

## Simulator expectations

The iOS simulator run is scripted by the harness of `test/ios-simulator.mjs`. The harness's `mobileApp` takes a bundle identifier as its fifth argument, so an example that declares its own identifier is installed and launched under it. The entry for this example is:

| Environment | Labels | Layout |
|---|---|---|
| `PUDU_UI_SELFTEST=0`, `PUDU_UI_LINK_TEST=pudulinks://hello?from=test` | `Link: pudulinks://hello?from=test` | `PUDU_SYSTEM link opened` |

The self-test opens the URL from the application itself through [[pudu-ios-system]]. The system hands the URL back to the application, which queues it as LINKED. The label then shows the URL, and the self-test asks the program to stop.

The launch and running paths on Android are not covered by the harness. They are checked by opening a `pudulinks://` link on a device, which the handoff [[Native App Identity]] records as the next action.

## Invariants

- The label is computed from the stored link, which changes only on a `Linked` event.
- The program never parses the URL. It shows the text the platform gave.
- The view is rebuilt from the stored link after each event, so a link that arrives during a wait updates the screen.

## Negative Logic

- No validation of the URL. The program accepts any text a link delivers and does not decide whether it is safe to open.
- No history. Only the last link is kept, and it is not stored between launches.
- No navigation. A link does not open a page; it only sets the label.

## Dependencies and consumers

Depends on [[Std Mobile View]], [[Std Mobile Host]] and [[Std Mobile Events]] through the view and the host. Hosts: the iOS host ([[iOS Host Adapter]]) and the Android activity ([[Native Android Activity]]). Manifest check: [[Pudu Backend Identity]]. Platform text: [[Backend Toolchain App]] and [[Backend Toolchain Android]]. Harness entry: `test/ios-simulator.mjs`.

## Resolved Grill Log

- **Q:** Why does the self-test open the link from the application rather than from a second program? **A:** A second program would need its own identity and a person's tap in the system. The application opening its own scheme goes through the same system path as an outside link: the system calls back into the application with the URL. _Rejected:_ a launcher script that calls `simctl openurl`, which is not part of the application and would not show the label.
- **Q:** Why keep only the last link rather than a list? **A:** The example shows the path a link takes into the program. A list would add a view that hides whether each event arrived. One label shows the most recent link and makes a missed event visible at once.
- **Q:** Why declare the identifier in this example when the harness could use the derived one? **A:** The derived identifier is `org.pudu.links`. Declaring `dev.pudu.links` checks the declared path in the build, the Android package with its hyphen rule, and the harness's bundle argument, which the derived path does not exercise.

## Referenced by

[[src/_MOC]] · [[Pudu Backend Identity]] · [[Identity Spec]] · [[Native App Identity]] · [[NATIVE-MOBILE]]
