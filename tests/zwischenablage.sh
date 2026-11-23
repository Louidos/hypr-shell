#!/usr/bin/env bash
# Prüft den Verlauf der Zwischenablage (shell-clipboard) mit echtem cliphist und Attrappen für wl-copy
# und hyprctl: Reihenfolge (neueste zuerst), Einfügen des gewählten Eintrags, Bild mit Vorschau-Datei,
# Löschen eines Eintrags, Clear all, abgeschaltet nichts aufzeichnen. Fehlt cliphist, nur der Rest.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CACHE_HOME="$T/cache" XDG_RUNTIME_DIR="$T/run"
mkdir -p "$HOME/.local/share/hypr-shell" "$T/bin" "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
printf '#!/usr/bin/env bash\ncat > "%s/eingefuegt"\n' "$T" > "$T/bin/wl-copy"
printf '#!/usr/bin/env bash\necho "$*" >> "%s/hyprctl"\n' "$T" > "$T/bin/hyprctl"
chmod +x "$T/bin/"*
cb() { PATH="$T/bin:$PATH" "$REPO/bin/shell-clipboard" "$@"; }

echo "== ohne cliphist"
mkdir -p "$T/nix"; for p in bash jq awk cat sed id mkdir chmod rm; do ln -sf "$(command -v "$p")" "$T/nix/$p"; done
pruefe '[ "$(PATH="$T/nix" "$REPO/bin/shell-clipboard" list)" = "[]" ]' "list liefert [] statt eines Fehlers"

if ! command -v cliphist >/dev/null 2>&1; then echo "Hinweis: cliphist fehlt, Rest übersprungen."; exit "$fehler"; fi

echo "== drei Texte und ein Bild"
for t in "erster Text" "zweiter Text" "dritter Text"; do printf '%s' "$t" | cliphist store; done
pruefe '[ "$(cb list | jq -r "map(.text) | join(\",\")")" = "dritter Text,zweiter Text,erster Text" ]' "drei kopierte Texte, neueste zuerst"
id2="$(cb list | jq -r '.[1].id')"
HYPRLAND_INSTANCE_SIGNATURE="test" cb paste "$id2"
pruefe '[ "$(cat "$T/eingefuegt")" = "zweiter Text" ] && grep -q "send_shortcut({ mods = \"CTRL\", key = \"V\" })" "$T/hyprctl"' "Enter fügt den gewählten Eintrag ein (wl-copy + STRG+V)"
if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    "$(command -v magick || command -v convert)" -size 32x32 xc:red png:- | cliphist store
    bild="$(cb list | jq -r '.[0].image')"
    pruefe '[ -s "$bild" ] && [ "$(head -c 4 "$bild" | tail -c 3)" = PNG ]' "Bild: Vorschau-Datei aus dem Verlauf ($bild)"
    pruefe '[ "$(stat -c %a "$(dirname "$bild")")" = 700 ]' "Vorschauen nur für den Benutzer lesbar"
fi
n="$(cb list | jq length)"
cb delete "$id2"
pruefe '[ "$(cb list | jq length)" = "$((n - 1))" ] && ! cb list | jq -e "map(.text) | index(\"zweiter Text\")" >/dev/null' "Entf löscht den Eintrag"
cb clear
pruefe '[ "$(cb list)" = "[]" ]' "Clear all leert den Verlauf"

echo "== Einstellungen"
echo '{"clipboard": {"enabled": false, "max": 50}}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
WAYLAND_DISPLAY=wayland-x cb daemon start
pruefe '[ ! -f "$HOME/.local/share/hypr-shell/clipboard.pids" ]' "abgeschaltet: keine Aufzeichnung"
echo '{"clipboard": {"enabled": true, "max": 2}}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
for t in a b c d; do printf '%s' "$t" | cliphist store; done
pruefe '[ "$(cb list | jq length)" = 2 ]' "Anzahl der Einträge aus clipboard.max"
pruefe 'grep -q "shell-clipboard daemon" config/hypr/hyprland.lua' "Start beim Anmelden"
exit "$fehler"
