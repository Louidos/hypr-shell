#!/usr/bin/env bash
# Prüft den Rechenteil der Seite Monitors (quickshell/settings/monitore.js) mit dem qml-Werkzeug
# von Qt, ohne Bildschirm (QT_QPA_PLATFORM=offscreen). Fehlt qml, wird der Test übersprungen.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

qml="$(command -v qml6 || command -v qml || ls /usr/lib/qt6/bin/qml 2>/dev/null || true)"
[ -n "$qml" ] || { echo "Hinweis: qml fehlt, Test übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export XDG_RUNTIME_DIR="$T" QT_QPA_PLATFORM=offscreen

echo "== Auflösungen auf der Seite Monitors"
if ! timeout 60 "$qml" tests/daten/monitore-test.qml > "$T/log" 2>&1; then
    sed 's/^qml: //' "$T/log"
    echo "FEHLER: monitore.js"
    exit 1
fi
sed 's/^qml: //' "$T/log"
if grep -qE "FEHLER|Error|error:|TypeError|ReferenceError" "$T/log"; then echo "FEHLER: monitore.js"; exit 1; fi
# ohne eine einzige Prüfung (z. B. Ausgabe verschluckt) gilt der Test nicht als bestanden
grep -q "ok:" "$T/log" || { echo "FEHLER: monitore.js – keine Ausgabe vom qml-Werkzeug"; exit 1; }
