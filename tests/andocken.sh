#!/usr/bin/env bash
# Prüft Andocken und Fenster-Modus ohne Bildschirm (hyprctl-Attrappe):
#   1. Zonen: oben = maximiert, links/rechts = Hälfte, Ecken = Viertel; ohne Leiste/Dock (reserviert)
#      und mit den Abständen; Skalierung, Hochformat; zwischen zwei Bildschirmen kein Andocken
#   2. Tastatur: SUPER + Pfeile (Hälfte, Viertel, maximieren, wiederherstellen, minimieren)
#   3. Ziehen: Ende an der linken Kante → linke Hälfte; Wegziehen bringt die alte Grösse zurück
#   4. hyprland.lua: schwebend (Standard) bzw. kacheln, Kürzel, Ziehen mit Beginn/Ende
# shellcheck disable=SC2016,SC2034,SC2329
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" KEINE_MELDUNG=1 XDG_RUNTIME_DIR="$T/run" HYPR_SHELL_INPUT_DEVICES=/nonexistent
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
mkdir -p "$HOME/.config/hypr-shell" "$HOME/.local/share/hypr-shell" "$HOME/.local/bin" "$T/bin" "$XDG_RUNTIME_DIR"
for b in "$REPO"/bin/*; do ln -s "$b" "$HOME/.local/bin/"; done
cp "$REPO/settings/schema.json" "$HOME/.local/share/hypr-shell/"
echo '{}' > "$HOME/.config/hypr-shell/settings.json"
"$REPO/bin/shell-apply" --no-reload >/dev/null 2>&1
ln -s "$REPO/tests/daten/hyprctl" "$T/bin/hyprctl"
export PATH="$T/bin:$PATH"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
S="$REPO/bin/shell-snap"
mon() { printf '%s\n' "$1" > "$T/m.json"; }
z() { HYPRLAND_INSTANCE_SIGNATURE=t HYPRCTL_MONITORS="$T/m.json" "$S" zone "$1" "$2"; }

echo "== 1. Zonen"
mon '[{"id":0,"name":"A","x":0,"y":0,"width":1920,"height":1080,"scale":1,"transform":0,"reserved":[0,36,0,0]}]'
pruefe '[ "$(z 960 2)" = "max 12 48 1896 1020 A" ]' "oben in der Mitte: maximiert unter der Leiste (36 px) mit Rand 12"
pruefe '[ "$(z 1 500)" = "left 12 48 945 1020 A" ] && [ "$(z 1918 500)" = "right 963 48 945 1020 A" ]' "linke und rechte Hälfte, Abstand 6 dazwischen"
pruefe '[ "$(z 1 40)" = "tl 12 48 945 507 A" ] && [ "$(z 1918 1078)" = "br 963 561 945 507 A" ] && [ "$(z 30 1078)" = "bl 12 561 945 507 A" ]' "Ecken: Viertel"
pruefe '[ -z "$(z 960 500)" ] && [ -z "$(z 960 1078)" ]' "Mitte und untere Kante: nichts"
mon '[{"id":0,"name":"A","x":0,"y":0,"width":1920,"height":1080,"scale":1,"transform":0,"reserved":[0,36,0,80]}]'
pruefe '[ "$(z 960 2)" = "max 12 48 1896 940 A" ]' "Dock mit reserviertem Platz unten: maximiert zwischen Leiste und Dock"
mon '[{"id":0,"name":"L","x":0,"y":0,"width":2560,"height":1600,"scale":1.6,"transform":0,"reserved":[0,0,0,0]}]'
pruefe '[ "$(z 1 500)" = "left 12 12 785 976 L" ]' "Skalierung 1.6: logische 1600×1000"
mon '[{"id":0,"name":"P","x":0,"y":0,"width":2560,"height":1600,"scale":1,"transform":1,"reserved":[0,0,0,0]}]'
pruefe '[ "$(z 800 2)" = "max 12 12 1576 2536 P" ]' "Hochformat (gedreht): 1600×2560"
mon '[{"id":0,"name":"A","x":0,"y":0,"width":1920,"height":1080,"scale":1,"transform":0,"reserved":[0,0,0,0]},{"id":1,"name":"B","x":1920,"y":0,"width":1920,"height":1080,"scale":1,"transform":0,"reserved":[0,0,0,0]}]'
pruefe '[ -z "$(z 1919 500)" ] && [ -z "$(z 1921 500)" ]' "zwischen zwei Bildschirmen: kein Andocken (Fenster wechselt den Bildschirm)"
pruefe '[ "$(z 1 500 | cut -d" " -f1)" = left ] && [ "$(z 3839 500 | cut -d" " -f1,6)" = "right B" ]' "Aussenkanten docken an"

echo "== 2. Tastatur"
export HYPRLAND_INSTANCE_SIGNATURE=t
mon '[{"id":0,"name":"HEADLESS-1","x":0,"y":0,"width":1920,"height":1080,"scale":1,"transform":0,"reserved":[0,0,0,0]}]'
export HYPRCTL_MONITORS="$T/m.json"
taste() { : > "$T/log"; HYPRCTL_LOG="$T/log" "$S" key "$1"; }
taste left
pruefe 'grep -q "window.float({ window = \"address:0x55d3c0a1b2c0\", action = \"set\" })" "$T/log" && grep -q "x = 945, y = 1056" "$T/log" && grep -q "x = 12, y = 12" "$T/log"' "SUPER + links: schwebend, linke Hälfte"
taste up
pruefe 'grep -q "x = 945, y = 525" "$T/log"' "danach SUPER + oben: Viertel oben links"
taste down
pruefe 'grep -q "x = 945, y = 1056" "$T/log"' "SUPER + unten aus dem Viertel: wieder die Hälfte"
taste right
pruefe 'grep -q "resize({ window = \"address:0x55d3c0a1b2c0\", x = 940, y = 1026 })" "$T/log"' "von links nach rechts: erst zurück an die alte Grösse"
taste up
pruefe 'grep -q "x = 1896, y = 1056" "$T/log"' "SUPER + oben: maximiert"
taste down
pruefe 'grep -q "x = 940, y = 1026" "$T/log" && grep -q "x = 12, y = 42" "$T/log" && [ "$(jq length "$XDG_RUNTIME_DIR/hypr-shell/snap.json")" = 0 ]' "SUPER + unten: alte Grösse und Lage zurück"
taste down
pruefe 'grep -q "special:minimiert" "$T/log"' "SUPER + unten, nicht angedockt: minimieren"

echo "== 3. Ziehen"
: > "$T/log"
HYPRCTL_LOG="$T/log" HYPRCTL_CURSOR='{"x": 1, "y": 500}' "$S" drag-start; sleep 0.5
HYPRCTL_LOG="$T/log" "$S" drag-end
pruefe 'grep -q "x = 945, y = 1056" "$T/log" && grep -q "move({ window = \"address:0x55d3c0a1b2c0\", x = 12, y = 12 })" "$T/log"' "losgelassen an der linken Kante: linke Hälfte"
: > "$T/log"
HYPRCTL_LOG="$T/log" HYPRCTL_CURSOR='{"x": 900, "y": 500}' "$S" drag-start; sleep 0.3
HYPRCTL_LOG="$T/log" "$S" drag-end
pruefe 'grep -q "resize({ window = \"address:0x55d3c0a1b2c0\", x = 940, y = 1026 })" "$T/log" && ! grep -q "move(" "$T/log"' "Wegziehen aus der Hälfte: alte Grösse zurück, Lage folgt der Maus"
pruefe '[ ! -f "$XDG_RUNTIME_DIR/hypr-shell/snap.pid" ] && ! pgrep -f "shell-snap drag-start" >/dev/null' "nach dem Loslassen verfolgt nichts mehr den Mauszeiger"

echo "== 4. hyprland.lua und Modus"
lua=$(command -v lua5.4 || command -v lua || true)
regeln() {
    printf '%s\n' "$1" > "$HOME/.config/hypr-shell/settings.json"; "$REPO/bin/shell-apply" --no-reload >/dev/null 2>&1
    "$lua" - <<'LUA'
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
for _, a in ipairs(A.aufrufe) do if a[1] == "window_rule" and a[2].name == "hypr-shell-schwebend" then print("schwebend") end end
for _, n in ipairs(A.neben) do print("neben " .. n.keys .. " " .. tostring(n.action.arg)) end
for _, k in ipairs({ "SUPER + left", "SUPER + up", "SUPER + ALT + left", "SUPER + SHIFT + T" }) do local b = A.binds[k]; print("bind " .. k .. " " .. tostring(b and b.dsp) .. " " .. tostring(b and type(b.arg) == "string" and b.arg or "")) end
LUA
}
if [ -n "$lua" ]; then
    r="$(regeln '{}')"
    pruefe 'grep -qx schwebend <<<"$r"' "Standard schwebend: neue Fenster schwebend und mittig"
    pruefe 'grep -q "neben SUPER + mouse:272 .*shell-snap drag-start" <<<"$r" && grep -q "neben SUPER + mouse:272 .*shell-snap drag-end" <<<"$r"' "Ziehen mit SUPER + linker Maustaste meldet Beginn und Ende"
    pruefe 'grep -q "bind SUPER + left .*shell-snap key left" <<<"$r" && grep -q "bind SUPER + up .*shell-snap key up" <<<"$r" && grep -q "bind SUPER + ALT + left focus " <<<"$r" && grep -q "bind SUPER + SHIFT + T .*shell-snap modus toggle" <<<"$r"' "SUPER + Pfeile docken an, Fokus auf SUPER + ALT + Pfeile, SUPER + SHIFT + T"
    r="$(regeln '{"fenster": {"modus": "kacheln"}}')"
    pruefe '! grep -qx schwebend <<<"$r"' "kacheln: keine Regel (wie bisher)"
    r="$(regeln '{"andocken": {"enabled": false}}')"
    pruefe '! grep -q "neben" <<<"$r"' "Andocken aus: kein Verfolgen beim Ziehen"
fi
echo '{}' > "$HOME/.config/hypr-shell/settings.json"; "$REPO/bin/shell-apply" --no-reload >/dev/null 2>&1
: > "$T/log"; HYPRCTL_LOG="$T/log" "$S" modus toggle >/dev/null
pruefe '[ "$(jq -r .fenster.modus "$HOME/.config/hypr-shell/settings.json")" = kacheln ] && grep -q "action = \"unset\"" "$T/log"' "SUPER + SHIFT + T: kacheln, offene Fenster werden gekachelt"
: > "$T/log"; HYPRCTL_LOG="$T/log" "$S" modus toggle >/dev/null
pruefe '[ "$(jq -r .fenster.modus "$HOME/.config/hypr-shell/settings.json")" = schwebend ] && grep -q "action = \"set\"" "$T/log" && grep -q "window.center" "$T/log"' "zurück: schwebend und mittig, ohne Neustart"
pruefe '! "$S" modus quer 2>/dev/null' "unbekannter Modus: Meldung"
exit "$fehler"
