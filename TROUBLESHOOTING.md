# Troubleshooting Guide

Common issues and their solutions when building or installing Vaani.

## Build Errors

### "xcode-select: error: tool 'xcodebuild' requires Xcode"

**Problem:** Xcode Command Line Tools not installed

**Solution:**
```bash
xcode-select --install
```

Click "Install" in the dialog that appears, wait for installation to complete, then try building again.

---

### "error: unable to resolve dependencies"

**Problem:** Cannot download Swift packages from GitHub

**Possible causes:**
1. No internet connection
2. GitHub is blocked or down
3. Swift package cache is corrupted

**Solutions:**

Try clearing the cache:
```bash
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/.swiftpm
rm -rf .build
swift package clean
```

Then build again:
```bash
./build.sh
```

---

### "error: compiling for macOS 13.0, but module compiled for macOS 14.0"

**Problem:** Swift version or SDK mismatch

**Solution:**

1. Update Xcode from the App Store (free)
2. Select the correct Xcode:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

3. Clean and rebuild:
```bash
rm -rf .build
./build.sh
```

---

### "error: fatalError" or random Swift compiler crashes

**Problem:** Corrupted build cache or low disk space

**Solutions:**

1. Clean everything:
```bash
rm -rf .build
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData
```

2. Check disk space:
```bash
df -h
```
Need at least 5GB free

3. Restart Mac and try again

---

### "No such module 'KeyboardShortcuts'" or "No such module 'KeychainAccess'"

**Problem:** Dependencies not resolved

**Solution:**
```bash
swift package resolve
swift package update
./build.sh
```

---

## Installation Errors

### "Vaani is damaged and can't be opened. You should move it to the Trash"

**Problem:** macOS Gatekeeper blocking the app due to missing code signature

**Solution 1 (Easiest):**
```bash
/usr/bin/xattr -cr /Applications/Vaani.app
```

**Solution 2 (Alternative):**
1. Right-click Vaani.app in Applications
2. Select "Open"
3. Click "Open" in the dialog

**Solution 3 (System Settings):**
1. Try to open Vaani (it will be blocked)
2. Go to System Settings > Privacy & Security
3. Click "Open Anyway" next to Vaani
4. Confirm by clicking "Open"

---

### "App can't be opened because Apple cannot check it for malicious software"

**Same solution as above** - this is the same Gatekeeper issue.

The app is safe. It's not signed because we don't have an Apple Developer certificate ($99/year).

---

### Microphone permission not working

**Problem:** Microphone permission denied or not prompted

**Solution:**

1. Go to System Settings > Privacy & Security > Microphone
2. Find Vaani in the list
3. Toggle it OFF then ON
4. Restart Vaani

If Vaani is not in the list:
```bash
tccutil reset Microphone com.vaani.app
```
Then restart Vaani - it will prompt again

---

### Auto-paste not working

**Problem:** Accessibility permission not granted

**Solution:**

1. Go to System Settings > Privacy & Security > Accessibility
2. Find Vaani in the list and enable it
3. If Vaani is not in the list, click the + button and add it from Applications

Reset if needed:
```bash
tccutil reset Accessibility com.vaani.app
```

---

## Runtime Errors

### "API key invalid or expired"

**Problem:** Sarvam AI API key not set or incorrect

**Solution:**

1. Click the mic icon in menubar
2. Click the gear icon (Settings)
3. Paste your API key in the API Key field
4. Click "Save"

Get an API key at: https://dashboard.sarvam.ai/key-management

---

### "Translation service temporarily unavailable"

**Problem:** Sarvam AI API is down or rate limited

**Solutions:**

1. Wait a minute and try again (rate limit: 10 requests/minute)
2. Check your API quota at sarvam.ai
3. Check internet connection
4. Check https://status.sarvam.ai (if available)

---

### No audio being recorded / audio level shows 0

**Problem:** Microphone not working or wrong input device

**Solutions:**

1. Check System Settings > Sound > Input
2. Select the correct microphone
3. Test the microphone in Voice Memos app
4. Restart Vaani
5. Re-grant microphone permission (see above)

---

### App doesn't appear in menubar

**Problem:** App launched but menubar icon not visible

**Solutions:**

1. Check if Vaani is actually running:
```bash
ps aux | grep Vaani
```

2. Restart the app:
```bash
killall SaarasTranslator
open /Applications/Vaani.app
```

3. Reset menubar:
```bash
killall SystemUIServer
```

4. Check if menubar is too crowded - try hiding other menubar items

---

## Intel Mac Issues

### "Build failed: Universal build not supported"

**Problem:** Building on Intel Mac tries universal binary

**Solution:**

The build script should auto-detect and fall back to native build. If it doesn't:

```bash
swift build -c release
```

Then manually create the app bundle:
```bash
mkdir -p Vaani.app/Contents/MacOS
cp .build/release/SaarasTranslator Vaani.app/Contents/MacOS/
```

---

## Still Having Issues?

1. **Check the logs:**
```bash
# Console.app logs for Vaani
log show --predicate 'process == "SaarasTranslator"' --last 1h
```

2. **Try a clean install:**
```bash
# Remove everything
rm -rf /Applications/Vaani.app
rm -rf ~/Library/Application\ Support/com.vaani.app
rm -rf ~/Library/Caches/com.vaani.app
tccutil reset All com.vaani.app

# Reinstall
open Vaani-v1.0.0-macOS.dmg
# Or rebuild from source
```

3. **Open an issue on GitHub:**
https://github.com/jayjpatel9717/Vaani-translator/issues

Include:
- macOS version
- Mac model (Intel or Apple Silicon)
- Error message or screenshot
- Steps to reproduce
