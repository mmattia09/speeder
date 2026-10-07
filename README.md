# Speeder

[![CI](https://img.shields.io/github/actions/workflow/status/mmattia09/speeder/ci.yml?branch=main&label=CI&style=for-the-badge)](https://github.com/mmattia09/speeder/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?style=for-the-badge)](https://github.com/mmattia09/speeder)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge)](Package.swift)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)

A macOS menu-bar app that shows how fast you are typing. It lives next to the
clock as a small spider, counts keystrokes while you write — in any app — and
turns them into words per minute, live and just after you stop. Open it for the
rest: current burst, session average, peak, and history.

![Speeder session window](Docs/session.png)

*Session window with example statistics. Light and dark appearance follow macOS.*

## What it measures

- **Current** — estimated words per minute over a 5 second sliding window (5
  characters per word, the usual typing-test convention). Typed characters minus deletions determine the rate. It stays visible after you stop, so the last burst stays readable while you think.
- **Burst** — the best rate reached in the run you are typing right now. A pause
  longer than 1.5 seconds closes the burst and the counter starts over.
- **Average** — words typed over the time you were actually typing. Pauses count
  as 1.5 seconds each, so a coffee break does not deflate your average.
- **Peak** — the fastest you have been in this session.
- **History** — the live rate sampled once per second, drawn as a sparkline.

A word counts when a space, return or tab follows at least one character, so
backspacing undoes the word you are typing instead of inflating the count. ⌘, ⌥ and ⌃
shortcuts, function keys and arrows are ignored. Option-modified characters are
excluded too; this is a keystroke estimate, not a count of committed text or
IME output.

## Requirements

macOS 13 or later; Swift 6 or later to build. Speeder needs **Accessibility** permission to see your
keystrokes: the first-launch introduction explains it, and you can also flip the switch from
Settings with *Accessibility Settings…*. Key events are inspected only to classify typing, separators and deletions.
Their text is immediately discarded: only recent timings, numeric deltas and
session statistics stay in memory. No files, network requests or telemetry.
Quitting clears the session.

## Install

Download **Speeder-0.1.0-macos-universal.zip** from the
[latest release](https://github.com/mmattia09/speeder/releases/latest), unzip it,
and move Speeder.app to Applications. It runs on Apple Silicon and Intel Macs
with macOS 13 or later. The app is ad-hoc signed and not notarized, so Gatekeeper
may warn when you first open it.

Or build from source:

```sh
git clone https://github.com/mmattia09/speeder.git
cd speeder
Scripts/build-app.sh          # builds dist/Speeder.app
open dist/Speeder.app         # then grant Accessibility access when asked
```

The app is ad-hoc signed, without a Developer ID or notarization, so macOS may require
*right-click → Open* the first time. For hacking on it, `swift run Speeder`
works too.

## Use

Click the small, monochrome spider for a compact popover: current pace, a recent
sparkline, average, peak and word count. Pause or resume capture with one click.

**Explore your session** opens a resizable window with a time-based speed graph,
a WPM goal reference, burst and session metrics, and progress toward your goal.
Copy the statistics or reset the session from the bottom of this window. Reset
asks for confirmation. Closing the window keeps Speeder in the menu bar.

**Settings** (the gear, or ⌘,) lets you hide the menu-bar number, turn spider
animation off, and choose a goal from 10 to 200 WPM. These preferences persist;
typing statistics still stay in memory only. Animation respects Reduce Motion.

On first launch, a three-step introduction explains how Speeder works before
offering Accessibility access. You can skip permission setup and return to it
later, or replay the introduction from Settings. Quit with the popover's Quit
button or ⌘Q while the app window is active.

## Development

```sh
swift build                   # build everything
Scripts/test.sh               # run metrics and key-classification tests
swift run Speeder             # run the app from the command line
Scripts/build-app.sh          # assemble dist/Speeder.app
Scripts/build-app.sh release universal # Apple Silicon + Intel release bundle
```

With full Xcode, `swift test` works directly. `Scripts/test.sh` also supports
recent Command Line Tools installations that ship `Testing.framework` but omit
its Foundation overlay. Older installations without a test framework need full
Xcode. CI runs the tests and packages an app artifact on every push.

The project is a Swift package with three libraries and one executable:

| Target          | What lives there                                                        |
| --------------- | ----------------------------------------------------------------------- |
| `SpeederCore`   | `TypingSession` and `WPMFormatter`: pure Foundation, no UI, no event taps |
| `SpeederShims`  | a two-line C shim around a CoreFoundation call Swift cannot see reliably |
| `SpeederCapture`| `KeystrokeMonitor` (`CGEventTap` session tap) and `KeyClassifier`         |
| `Speeder`       | the menu-bar item, the animated spider and the detail panel (SwiftUI)     |

The split keeps the interesting part — the maths — free of AppKit, so it can be
tested without a window server. Tests cover the sliding window, the freeze after
a pause, burst and peak handling, backspaces, pause handling in the average, and
history sampling, long sessions, clock changes and key classification.

## Troubleshooting

- **No speed updates:** grant access under System Settings → Privacy & Security →
  Accessibility. Speeder checks for permission changes every two seconds.
- **Still no capture after a rebuild:** remove the old Accessibility entry, add
  the rebuilt app and relaunch it. Keep the app in a stable location.
- **Password fields:** macOS Secure Input can prevent global capture. Speeder
  does not bypass it.
- **History and averages:** history samples are collected during typing; the graph uses their
  actual timestamps, so gaps between bursts appear on the time axis. Average counts completed words;
  Current uses five characters per word and subtracts deletions. They can differ.

### Interface previews

```sh
swift run Speeder --render-previews /tmp/speeder-previews
```

Debug builds can export the actual SwiftUI views in light and dark appearance,
using synthetic statistics and isolated preferences, without starting capture.
This includes the popover, session, settings, introduction and an empty session
at the minimum window size. The export option is absent from release builds.

## Contributing

Questions, bug reports and pull requests are welcome —
[open an issue](https://github.com/mmattia09/speeder/issues).

## Authors and acknowledgment

Made by [@mmattia09](https://github.com/mmattia09). Developed with the help of
[Claude Code](https://claude.com/claude-code) and [Codex](https://openai.com/codex/).

## License

[MIT](LICENSE).
