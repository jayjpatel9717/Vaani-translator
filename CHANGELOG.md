# Changelog

All notable changes to Vaani are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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
- **API key storage** in app preferences
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
