#!/usr/bin/env bash
# Prüft ohne Bildschirm, dass die Tastatur nie bei der Shell hängen bleibt:
#   1. Notfall-Kürzel (keybinds.emergency, Standard CTRL + SUPER + Escape) ist in hyprland.lua belegt,
#      wirkt in jeder Submap (submap_universal) und ruft "shell-diag freigeben" auf
#   2. shell-diag freigeben: Submap verlassen und Fokus auf das Fenster unter der Maus (hyprctl-Attrappe)
#   3. shell-diag tastatur nennt Submap, aktives Fenster und Flächen der Shell
#   4. dock.keyboard_timeout_s steht im Schema (Standard 10, 0 = nie)
# Der Tastatur-Modus des Docks selbst wird in tests/oberflaeche.sh geprüft.
# shellcheck disable=SC2016,SC2034
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
ln -s "$REPO/tests/daten/hyprctl" "$T/bin/hyprctl"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }

echo "== 1. Notfall-Kürzel"
lua=$(command -v lua5.4 || command -v lua || true)
if [ -n "$lua" ]; then
    n="$(HOME="$T" HYPR_SHELL_INPUT_DEVICES=/nonexistent "$lua" - <<'LUA'
package.path = "./config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
local k = "CTRL + SUPER + Escape"
local a, f = A.binds[k], A.flags[k] or {}
print(tostring(a and a.arg) .. "|" .. tostring(f.submap_universal) .. "|" .. tostring(f.description))
LUA
)"
    pruefe '[[ "$n" == *"shell-diag freigeben|true|"* ]]' "CTRL + SUPER + Escape ruft shell-diag freigeben auf, auch in jeder Submap ($n)"
else
    echo "  Hinweis: lua fehlt, übersprungen"
fi
pruefe '[ "$(jq -r ".keys[] | select(.key == \"keybinds.emergency\") | .default" settings/schema.json)" = "CTRL + SUPER + Escape" ]' "keybinds.emergency im Schema (änderbar, Standard CTRL + SUPER + Escape)"

echo "== 2. shell-diag freigeben"
export HYPRLAND_INSTANCE_SIGNATURE=test PATH="$T/bin:$PATH"
aus="$(HYPRCTL_LOG="$T/log1" "$REPO/bin/shell-diag" freigeben)"
pruefe 'grep -q "hl.dsp.submap(\"reset\")" "$T/log1"' "verlässt jede Submap"
pruefe 'grep -q "address:0x55d3c0a1b2c0" "$T/log1"' "Fokus auf das Fenster unter der Maus (links: kitty)"
HYPRCTL_LOG="$T/log2" HYPRCTL_CURSOR='{"x": 1200, "y": 500}' "$REPO/bin/shell-diag" freigeben >/dev/null
pruefe 'grep -q "address:0x55d3c0a1b3d0" "$T/log2"' "Fokus auf das Fenster unter der Maus (rechts: Firefox)"
HYPRCTL_LOG="$T/log3" HYPRCTL_CURSOR='{"x": 5000, "y": 5000}' "$REPO/bin/shell-diag" freigeben >/dev/null
pruefe '! grep -q "hl.dsp.focus" "$T/log3"' "kein Fenster unter der Maus: kein Fokuswechsel"
pruefe 'grep -q "Oberfläche antwortet nicht" <<<"$aus"' "ohne laufende Oberfläche: Hinweis statt Fehler"
pruefe '(unset HYPRLAND_INSTANCE_SIGNATURE; "$REPO/bin/shell-diag" freigeben | grep -q "Hyprland läuft nicht")' "ohne Hyprland: Hinweis statt Fehler"

echo "== 3. shell-diag tastatur"
aus="$(HYPRCTL_SUBMAP=resize "$REPO/bin/shell-diag" tastatur)"
pruefe 'grep -q "Submap \"resize\"" <<<"$aus" && grep -q "kitty – Terminal" <<<"$aus" && grep -q "hypr-shell-dock" <<<"$aus" && grep -q "CTRL + SUPER + Escape" <<<"$aus"' "nennt Submap, aktives Fenster, Flächen der Shell und den Ausweg"
pruefe '! "$REPO/bin/shell-diag" xyz 2>/dev/null' "unbekannter Befehl: Meldung"

echo "== 4. Einstellung"
pruefe '[ "$(jq -c ".keys[] | select(.key == \"dock.keyboard_timeout_s\") | [.default, .min, .max]" settings/schema.json)" = "[10,0,120]" ]' "dock.keyboard_timeout_s: Standard 10 s, 0 = nie, höchstens 120"
exit "$fehler"
