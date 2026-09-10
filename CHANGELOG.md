# Changelog

All notable changes to Vaani are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-09-10

### Changed
- **New "Soft Glass" interface.** Mesh-gradient background, frosted cards, a gradient orb that pulses while listening and spins while translating, a full-width result card after each translation, segmented mode control, and a first-run welcome checklist. Popover is now 340×440. Dark mode included. Rounded SF stands in for the Manrope face used in the design.

### Added
- **Floating status pill.** A click-through pill at the bottom of the active screen shows Listening (with level meter), Translating with elapsed time, Pasted / "Copied, press ⌘V", or the error. Works regardless of which display holds the menu bar.
- **First-run setup checklist.** Key with live check, Microphone button, Accessibility button that opens the right pane, and a Try-it step, each with a live tick. "Run setup again" in Settings.
- **Faster turnaround.** The HTTPS connection to Sarvam opens when the key goes down, and audio is recorded straight to 16 kHz mono so no conversion step runs after release (afconvert kept as fallback).
- **Stable signing.** `scripts/make-signing-cert.sh` creates a local certificate; `build.sh` uses it so Microphone, Accessibility, and keychain grants survive updates. DMG instructions now lead with Homebrew and explain right-click → Open on macOS 15+.
- **Errors are visible from the fn-key flow.** A failed translation now opens the popover and tints the menu bar icon orange until the next recording.
- **API key status in Settings** ("Key OK", "Invalid key", "No credits", "No key saved") checked on save and on launch, with "Get API key" and "Add credits" links to the Sarvam dashboard. The main screen status line says "No credits" / "Add API key" / "API key invalid" instead of "API key issue".

### Fixed
- **"Translation failed" with no explanation when the Sarvam account is out of credits.** HTTP 402 now shows a clear "no credits" message. API and pipeline errors are also written to the unified log (`/usr/bin/log show --predicate 'subsystem == "com.vaani.app"' --last 10m`).
- **Crash when opening Settings** (`SIGTRAP` in `NSBundle.module`). SwiftPM's generated resource-bundle accessor only looked at the `.app` root and at the absolute `.build` path of the machine that built the app, so the app crashed on every other machine and after the project folder was moved. `KeyboardShortcuts` is now vendored under `Vendor/` with its bundle lookup patched to check `Contents/Resources` first. Regression check: `Tests/BundleCheck/run.sh`.

## [1.0.0] - 2026-03-02

### Added
- **23 Indian languages** — Hindi, Bengali, Telugu, Marathi, Tamil, Gujarati, Kannada, Malayalam, Odia, Punjabi, Assamese, Urdu, Kashmiri, Konkani, Maithili, Manipuri, Nepali, Santali, Sindhi, Dogri, Bodo, Sanskrit, English
- **5 translation modes** — Transcribe, Translate, Transliterate, Code-mix, Verbatim
- **Unlimited recording** — audio chunked into 28s segments, processed in parallel
- **Direct translation** — source language to target directly, no English middleman for non-English targets
- **Global hotkeys** — configurable keyboard shortcut (default `Ctrl+Space`) and optional `fn` (globe) key enabled by default
- **Smart auto-paste** — multi-strategy insertion at cursor (Accessibility API direct insert, menu-based paste, CGEvent fallback)
- **Translation history** — last 5 results with quick copy buttons and mode badge
- **Auto source detection** — speaks any language, API detects automatically
- **Dark & Light theme** — adaptive colors with appearance toggle on main screen (System/Light/Dark)
- **API key validation** — status dot shows green/yellow/red based on actual API health
- **Compact menubar UI** — 320x380 popover with mic hero, status header, and history
- **Secure API key storage** in macOS Keychain
- **Audio recording** with AVAudioEngine in native mic format, auto-converted to 16kHz mono
- **TLS certificate validation** with pinning-ready infrastructure
- **Client-side rate limiting** — 30 requests per minute
- **Sanitized error messages** — no server details leaked to UI
- **No debug logging in release builds** — paste operations log only in DEBUG
- **Universal binary** — runs natively on both Apple Silicon and Intel Macs
- **Native SwiftUI menubar app** — no Electron, no web views
- **Homebrew distribution** — `brew install --cask vaani`
- **DMG installer** with Quick Install script for zero Gatekeeper warnings
- **Build from source** script with prerequisite checks

[1.0.0]: https://github.com/jayjpatel9717/Vaani-translator/releases/tag/v1.0.0
