# Speeder

[![CI](https://img.shields.io/github/actions/workflow/status/mmattia09/speeder/ci.yml?branch=main&label=CI&style=for-the-badge)](https://github.com/mmattia09/speeder/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?style=for-the-badge)](https://github.com/mmattia09/speeder)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge)](Package.swift)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)

A macOS menu-bar app that shows how fast you are typing. It lives next to the
clock as a small spider, counts keystrokes while you write — in any app — and
turns them into words per minute, live and just after you stop. Open it for the
rest: current burst, session average, peak, and history.

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
keystrokes: the first launch asks for it, and you can also flip the switch from
the menu with *Open Accessibility Settings…*. Key events are inspected only to classify typing, separators and deletions.
Their text is immediately discarded: only recent timings, numeric deltas and
session statistics stay in memory. No files, network requests or telemetry.
Quitting clears the session.

## Install

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

Click the spider in the menu bar to open the panel: current rate with a
sparkline of up to 180 samples collected while typing, burst, average, peak, word and keystroke
counts, and how long you have been typing. From the same menu you can reset the
session, copy the summary to the clipboard, open the Accessibility settings, or
quit (⌘Q).

## Development

```sh
swift build                   # build everything
Scripts/test.sh               # run metrics and key-classification tests
swift run Speeder             # run the app from the command line
Scripts/build-app.sh          # assemble dist/Speeder.app
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
- **History and averages:** history samples are collected during typing, so its
  horizontal axis is samples, not wall-clock time. Average counts completed words;
  Current uses five characters per word and subtracts deletions. They can differ.

## Contributing

Questions, bug reports and pull requests are welcome —
[open an issue](https://github.com/mmattia09/speeder/issues).

## Authors and acknowledgment

Made by [@mmattia09](https://github.com/mmattia09). Developed with the help of
[Claude Code](https://claude.com/claude-code) and [Codex](https://openai.com/codex/).

## License

[MIT](LICENSE).
