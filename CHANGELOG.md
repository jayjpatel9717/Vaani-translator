# Changelog

All notable changes to Vaani are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-03-02

### Added
- **23 Indian languages** — Hindi, Bengali, Telugu, Marathi, Tamil, Gujarati, Kannada, Malayalam, Odia, Punjabi, Assamese, Urdu, Kashmiri, Konkani, Maithili, Manipuri, Nepali, Santali, Sindhi, Dogri, Bodo, Sanskrit, English
- **5 translation modes** — Transcribe, Translate, Transliterate, Code-mix, Verbatim
- **Global hotkeys** — configurable keyboard shortcut (default `Ctrl+Space`) and optional `fn` (globe) key enabled by default
- **Auto-paste** — translated text pastes at cursor via `Cmd+V` simulation
- **Translation history** — last 3 results with quick copy buttons
- **Auto source detection** — speaks any language, API detects automatically
- **Dark & Light theme system** — adaptive colors, gradients, and shadows that respond to macOS appearance
- **Appearance selector** in Settings — choose System, Light, or Dark mode override
- **API key validation** — status dot shows green/yellow/red based on actual API health
- **Compact menubar UI** — 340x400 popover with merged header, 48px mic hero, 16pt result text
- **Secure API key storage** in macOS Keychain
- **Audio recording** with AVAudioEngine, files in `chmod 700` protected directory
- **TLS certificate validation** with pinning-ready infrastructure
- **Client-side rate limiting** — 10 requests per minute
- **Universal binary** — runs natively on both Apple Silicon and Intel Macs
- **Native SwiftUI menubar app** — no Electron, no web views
- **Homebrew distribution** — `brew install --cask vaani`
- **DMG installer** with Quick Install script for zero Gatekeeper warnings
- **Build from source** script with prerequisite checks

[1.0.0]: https://github.com/jayjpatel9717/Vaani-translator/releases/tag/v1.0.0
