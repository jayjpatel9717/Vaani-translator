#!/bin/bash
# Creates a local self-signed code-signing identity "Vaani Local Signing" (run once per Mac).
# Ad-hoc signatures change with every build, so macOS re-asks for Microphone/Accessibility
# and the keychain item after each update. Signing with one stable certificate keeps the
# app's identity constant, so those grants survive rebuilds and updates.
set -euo pipefail
NAME="Vaani Local Signing"
KC="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$NAME"; then
    echo "✅ '$NAME' already exists"
    exit 0
fi

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cat > "$T/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CNF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$T/cert.cnf" -keyout "$T/key.pem" -out "$T/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$T/key.pem" -in "$T/cert.pem" \
    -out "$T/identity.p12" -passout pass:vaani

echo "Importing certificate into the login keychain (macOS may ask for your password)..."
security import "$T/identity.p12" -k "$KC" -P vaani -T /usr/bin/codesign -T /usr/bin/security
echo "Trusting it for code signing (macOS may ask for your password)..."
security add-trusted-cert -p codeSign -k "$KC" "$T/cert.pem"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
    echo "✅ '$NAME' ready. ./build.sh will use it automatically."
else
    echo "❌ Identity not valid for code signing; build.sh will fall back to ad-hoc signing."
    exit 1
fi
