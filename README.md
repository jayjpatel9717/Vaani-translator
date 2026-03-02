# Vaani — Speak in Any Indian Language, Type Anywhere

[![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://github.com/jayjpatel9717/Vaani-translator/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/jayjpatel9717/Vaani-translator)](https://github.com/jayjpatel9717/Vaani-translator/releases/latest)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

A tiny macOS menubar app that turns your voice into text — in 23 Indian languages. Speak Hindi into Slack, Tamil into VS Code, Gujarati into Gmail. Text auto-pastes at your cursor.

> **Hold to speak. Release to translate. Done.**

---

## Table of Contents

- [Install](#install)
- [Quick Start](#quick-start)
- [Features](#features)
- [Translation Modes](#translation-modes)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Use Cases](#use-cases)
- [Requirements](#requirements)
- [Project Structure](#project-structure)
- [Security](#security)
- [Built With](#built-with)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [License](#license)

---

## Install

### Homebrew (Recommended)

```bash
brew tap jayjpatel9717/vaani
brew install --cask vaani
```

No Gatekeeper warnings. Updates with `brew upgrade`. Clean uninstall with `brew uninstall --cask vaani`.

### Download DMG

Grab the latest `.dmg` from [Releases](https://github.com/jayjpatel9717/Vaani-translator/releases/latest). Double-click the Quick Install script — zero security warnings.

### Build from Source

```bash
git clone https://github.com/jayjpatel9717/Vaani-translator.git
cd Vaani-translator
./build.sh && open Vaani.app
```

Requires Xcode Command Line Tools and Swift 5.9+.

---

## Quick Start

1. **Launch** — a mic icon appears in your menubar
2. **Add API key** — click mic icon > gear icon > paste your [Sarvam AI](https://dashboard.sarvam.ai/key-management) API key > Save
3. **Grant permissions** — allow Microphone and Accessibility when prompted
4. **Speak** — hold `Ctrl+Space`, say something, release — text appears at your cursor

That's it. No windows to manage, no app switching. Works from any app.

---

## Features

### Core

- **23 Indian languages** — Hindi, Tamil, Telugu, Bengali, Marathi, Gujarati, Kannada, Malayalam, Odia, Punjabi, Assamese, Urdu, Kashmiri, Konkani, Maithili, Manipuri, Nepali, Santali, Sindhi, Dogri, Bodo, Sanskrit, and English
- **5 translation modes** — Translate, Transcribe, Transliterate, Code-mix, Verbatim
- **Auto source detection** — speak any language, Vaani figures it out
- **Global hotkeys** — `Ctrl+Space` or `fn` (globe key), works from any app
- **Auto-paste** — translated text pastes directly at your cursor via `Cmd+V` simulation
- **Translation history** — last 3 results for quick copy

### Experience

- **Dark & Light theme** — follows your system appearance, or force Light/Dark from Settings
- **Compact UI** — small 340px popover that stays out of your way
- **Live audio visualization** — waveform feedback while recording
- **Native SwiftUI** — no Electron, no web views, minimal memory footprint

### Security

- **API key in macOS Keychain** — never stored in plaintext
- **Audio in protected directory** — `chmod 700`, deleted after processing
- **TLS certificate validation** — pinning-ready infrastructure
- **Client-side rate limiting** — 10 requests per minute
- **Sanitized errors** — no server details leaked to UI

---

## Translation Modes

| Mode | What it does | You say (Hindi) | You get |
|------|-------------|-----------------|---------|
| **Transcribe** | Speech to text in original script | "mera phone number hai..." | मेरा फोन नंबर है 9840950950 |
| **Translate** | Speech to another language | "mera phone number hai..." | My phone number is 9840950950 |
| **Transliterate** | Speech to English letters (default) | "mera phone number hai..." | mera phone number hai 9840950950 |
| **Code-mix** | English stays English, rest in native | "mera phone number hai..." | मेरा phone number है 9840950950 |
| **Verbatim** | Exact words, fillers preserved | "mera phone number hai..." | मेरा फोन नंबर है नौ आठ चार zero... |

Default mode is **Transliterate** — great for chatting in Hinglish.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Space` (default) | Hold to record, release to process |
| `fn` (globe key) | Hold to record (enable in Settings) |

Customize your shortcut in Settings > Shortcuts.

---

## Use Cases

- **Developers** — speak Hindi/Tamil/Telugu into Claude Code, VS Code, or any IDE
- **Chat** — type in WhatsApp, Telegram, Slack in any Indian language
- **Email** — compose in your language, auto-types at cursor
- **Notes** — meetings, classes, quick reminders in your mother tongue
- **Social media** — post in regional languages without a keyboard switch

---

## Requirements

- macOS 13.0 (Ventura) or later
- [Sarvam AI API key](https://dashboard.sarvam.ai/key-management) (free tier available)

### Permissions

| Permission | Why |
|-----------|-----|
| **Microphone** | Record your voice |
| **Accessibility** | Auto-paste via `Cmd+V` simulation and global hotkey monitoring |

If hotkeys stop working after a rebuild, reset Accessibility:

```bash
tccutil reset Accessibility com.vaani.app
```

---

## Project Structure

```
Sources/
  main.swift                     # App entry, menubar, hotkeys
  Models/
    Language.swift                # 23 languages + 5 modes
    TranslationResult.swift      # API response models
  ViewModels/
    TranslatorViewModel.swift    # State, recording, API calls, rate limiting
  Views/
    MainView.swift               # Main popover UI
    SettingsView.swift            # Settings (API, shortcuts, appearance)
  Services/
    AudioRecorder.swift          # AVAudioEngine recording
    SaarasAPIClient.swift        # Sarvam AI API client with TLS validation
    KeychainManager.swift        # macOS Keychain storage
    PasteboardManager.swift      # Clipboard + Cmd+V simulation
    FnKeyMonitor.swift           # CGEventTap fn key listener
  Theme/
    AppTheme.swift               # Adaptive design tokens (dark/light)
```

---

## Security

- API keys stored in macOS Keychain (not plaintext, not UserDefaults)
- Audio files in `~/Library/Application Support/com.vaani.app/recordings` with `chmod 700`
- Audio deleted immediately after API processing
- TLS certificate validation with pinning-ready infrastructure
- Client-side rate limiting (10 requests/minute)
- Thread-safe fn key state management with NSLock
- Sanitized error messages (no server response details exposed)

---

## Built With

- Swift 5.9 / SwiftUI
- AVFoundation
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v1.14.0 — by Sindre Sorhus
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) v4.2.2 — by kishikawakatsumi
- [Sarvam AI](https://sarvam.ai) — Saaras v3 (STT) + Mayura v1 (Translation)

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues:

- macOS security warnings (Gatekeeper)
- Microphone or Accessibility permissions
- Hotkeys not responding
- Build errors on Intel Macs
- API key and network issues

---

## Contributing

Contributions are welcome! Please see the [issue templates](.github/ISSUE_TEMPLATE) for reporting bugs or requesting features.

1. Fork the repo
2. Create your branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

---

## License

[MIT](LICENSE) — Jay Patel
