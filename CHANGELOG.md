# Changelog

All notable changes to Vaani are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-03-02

### Added
- **Dark & Light theme system** — adaptive colors, gradients, and shadows that respond to macOS appearance
- **Appearance selector** in Settings — choose System, Light, or Dark mode override
- **Card borders** for better visual separation in dark mode
- **Adaptive status colors** — brighter indicators in dark mode for readability

### Changed
- **Compact UI overhaul** — popover shrunk from 380x500 to 340x400 for a snappier feel
- **Merged header row** — title, status dot, and status text now share a single compact line
- **Mic hero** reduced from 64px to 48px — less decorative, more functional
- **Result text bumped to 16pt** — the most important content is now the most readable
- **Section labels bumped to 11-12pt** — easier to read across the board
- **Tighter padding** — 16px instead of 20px throughout for efficient space use

### Removed
- **Footer bar** ("Hold to speak. Instant translation." + Quit button) — redundant with status line; Quit available via right-click menu
- **Subtitle** ("Translate & Transcribe") from header — saves vertical space
- **Modes Guide** from Settings — was eating ~200px; users learn modes by using them

---

## [1.0.0] - 2026-02-15

### Added
- Initial release of Vaani
- **23 Indian languages** — Hindi, Bengali, Telugu, Marathi, Tamil, Gujarati, Kannada, Malayalam, Odia, Punjabi, Assamese, Urdu, Kashmiri, Konkani, Maithili, Manipuri, Nepali, Santali, Sindhi, Dogri, Bodo, Sanskrit, English
- **5 translation modes** — Transcribe, Translate, Transliterate, Code-mix, Verbatim
- **Global hotkeys** — configurable keyboard shortcut (default `Ctrl+Space`) and optional `fn` (globe) key
- **Auto-paste** — translated text pastes at cursor via `Cmd+V` simulation
- **Translation history** — last 3 results with quick copy buttons
- **Auto source detection** — speaks any language, API detects automatically
- **Secure API key storage** in macOS Keychain
- **Audio recording** with AVAudioEngine, files in `chmod 700` protected directory
- **TLS certificate validation** with pinning-ready infrastructure
- **Client-side rate limiting** — 10 requests per minute
- **Native SwiftUI menubar app** — no Electron, no web views
- **Homebrew distribution** — `brew install --cask vaani`
- **DMG installer** with Quick Install script for zero Gatekeeper warnings
- **Build from source** script with prerequisite checks

[1.1.0]: https://github.com/jayjpatel9717/Vaani-translator/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/jayjpatel9717/Vaani-translator/releases/tag/v1.0.0
