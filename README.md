# Vaani — Voice to Text for Indian Languages

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://github.com/jayjpatel9717/Vaani-translator/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/jayjpatel9717/Vaani-translator)](https://github.com/jayjpatel9717/Vaani-translator/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

A native macOS menubar app for real-time voice translation across 23 Indian languages. Powered by [Sarvam AI](https://sarvam.ai).

**Hold to speak. Release to translate. Text auto-pastes at your cursor.**

---

## Install

```bash
brew tap jayjpatel9717/vaani
brew install --cask vaani
```

No Gatekeeper warnings. Updates with `brew upgrade`. Uninstall with `brew uninstall --cask vaani`.

### Build from Source

For Intel Macs or if you prefer building yourself:

```bash
git clone https://github.com/jayjpatel9717/Vaani-translator.git
cd Vaani-translator
./build.sh && open Vaani.app
```

Requires Xcode Command Line Tools and Swift 5.9+. Builds the `.app` directly — no DMG step.

---

## Quick Start

1. **Launch** — a mic icon appears in your menubar
2. **Add API key** — click the mic icon > gear icon > paste your [Sarvam AI](https://dashboard.sarvam.ai/key-management) API key
3. **Grant permissions** — allow Microphone and Accessibility when prompted
4. **Use** — hold `Ctrl+Space` (or `fn`), speak, release — text pastes at your cursor

---

## Features

- **23 Indian languages** — Hindi, Tamil, Telugu, Bengali, Marathi, Gujarati, Kannada, Malayalam, Odia, Punjabi, Assamese, Urdu, Kashmiri, Konkani, Maithili, Manipuri, Nepali, Santali, Sindhi, Dogri, Bodo, Sanskrit, and English
- **5 modes** — Translate, Transcribe, Transliterate, Code-mix, Verbatim
- **Auto source detection** — speaks any language, detects automatically
- **Global hotkeys** — configurable shortcut or `fn` (globe) key, works from any app
- **Auto-paste** — translated text pastes directly at your cursor
- **Translation history** — recent results for quick copy
- **Secure** — API key in macOS Keychain, audio in protected directory
- **Native** — SwiftUI, zero Electron, minimal resource usage

## Translation Modes

| Mode | What it does | Input (Hindi speech) | Output |
|------|-------------|---------------------|--------|
| **Transcribe** | Speech to text in original language | "mera phone number hai..." | मेरा फोन नंबर है 9840950950 |
| **Translate** | Speech to another language | "mera phone number hai..." | My phone number is 9840950950 |
| **Transliterate** | Speech to English letters | "mera phone number hai..." | mera phone number hai 9840950950 |
| **Code-mix** | English stays English, rest in native | "mera phone number hai..." | मेरा phone number है 9840950950 |
| **Verbatim** | Exact words, no cleanup | "mera phone number hai..." | मेरा फोन नंबर है नौ आठ चार zero... |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Space` (default) | Hold to record, release to process |
| `fn` (globe key) | Hold to record (enable in Settings) |

Customize in Settings > Shortcuts.

---

## Use Cases

- **Developers** — speak Hindi/Tamil/Telugu into Claude Code, VS Code, or any IDE
- **Chat** — type in WhatsApp, Telegram, Slack in any Indian language
- **Email** — compose in your language, auto-types at cursor
- **Notes** — meetings, classes, quick reminders
- **Social media** — post in regional languages

---

## Requirements

- macOS 13.0 (Ventura) or later
- Sarvam AI API key — [get one free](https://dashboard.sarvam.ai/key-management)

## Permissions

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
    SettingsView.swift            # Settings (API, shortcuts, modes, about)
  Services/
    AudioRecorder.swift          # AVAudioEngine recording
    SaarasAPIClient.swift        # Sarvam AI API client with TLS validation
    KeychainManager.swift        # macOS Keychain storage
    PasteboardManager.swift      # Clipboard + Cmd+V simulation
    FnKeyMonitor.swift           # CGEventTap fn key listener
```

## Security

- API keys stored in macOS Keychain (not plaintext)
- Audio files in `~/Library/Application Support/com.vaani.app/recordings` with `chmod 700`
- TLS certificate validation (pinning-ready)
- Client-side rate limiting (10 req/min)
- Thread-safe fn key state management
- Sanitized error messages

## Built With

- Swift 5.9 / SwiftUI
- AVFoundation
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v1.14.0
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) v4.2.2
- [Sarvam AI](https://sarvam.ai) Saaras v3 API

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues:
- macOS security warnings
- Microphone not working
- Hotkeys not responding
- Build errors

## License

[MIT](LICENSE)
