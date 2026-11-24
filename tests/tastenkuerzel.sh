#!/usr/bin/env bash
# Prüft die einstellbaren Tastenkürzel (keybinds.* in settings.json) ohne Bildschirm:
#   ohne Einträge gelten genau die bisherigen Kürzel; ein geändertes Kürzel wirkt, das alte ist frei;
#   leeres Kürzel = keine Taste; SUPER+U lässt sich nicht leeren; eigene Kürzel; doppelte Belegung wird
#   von shell-set abgelehnt und benannt, von Hand eingetragen fällt die spätere weg.
#   Die festen Tasten (Lautstärke, Helligkeit, Medien) gelten als belegt; ihre Liste im Schema
#   (fixed_binds) muss genau den festen hl.bind-Aufrufen in hyprland.lua entsprechen.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
lua=$(command -v lua5.4 || command -v lua || true)
if ! command -v jq >/dev/null || [ -z "$lua" ]; then echo "Hinweis: jq oder lua fehlt, übersprungen."; exit 0; fi

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
export KEINE_MELDUNG=1
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }

# binds SETTINGS-JSON -> "Tasten<TAB>Aktion" je Zeile, sortiert
binds() {
    local h="$T/h$RANDOM"
    mkdir -p "$h/.config/hypr-shell"
    printf '%s\n' "$1" > "$h/.config/hypr-shell/settings.json"
    HOME="$h" "$REPO/bin/shell-apply" --no-reload 2>/dev/null
    HOME="$h" "$lua" - <<'LUA' | sort
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
for k, v in pairs(A.binds) do
    local a = v.dsp or "?"
    if type(v.arg) == "string" then a = a .. " " .. v.arg end
    print(k .. "\t" .. a)
end
LUA
}

echo "== ohne Einträge: die bisherigen Kürzel"
# seit 1.9.1 dazu: CTRL + SUPER + Escape (Tastatur zurück, Notfall)
erwartet="ALT + Space
CTRL + SUPER + Escape
CTRL + SUPER + Return
Print
SHIFT + Print
SUPER + A
SUPER + ALT + D
SUPER + ALT + W
SUPER + B
SUPER + C
SUPER + D
SUPER + E
SUPER + F
SUPER + F1
SUPER + Escape
SUPER + L
SUPER + M
SUPER + N
SUPER + Q
SUPER + R
SUPER + Return
SUPER + SHIFT + V
SUPER + Tab
SUPER + Space
SUPER + U
SUPER + V
SUPER + W
SUPER + down
SUPER + left
SUPER + mouse:272
SUPER + mouse:273
SUPER + mouse_down
SUPER + mouse_up
SUPER + right
SUPER + up
XF86AudioLowerVolume
XF86AudioMicMute
XF86AudioMute
XF86AudioNext
XF86AudioPause
XF86AudioPlay
XF86AudioPrev
XF86AudioRaiseVolume
XF86KbdBrightnessDown
XF86KbdBrightnessUp
XF86MonBrightnessDown
XF86MonBrightnessUp"
for i in 0 1 2 3 4 5 6 7 8 9; do erwartet="$erwartet
SUPER + $i
SUPER + SHIFT + $i"; done
erwartet="$(sort <<<"$erwartet")"
std="$(binds '{}' | cut -f1)"
pruefe '[ "$std" = "$erwartet" ]' "genau die bisherigen $(wc -l <<<"$erwartet") Kürzel (mit dem Notfall-Kürzel)"
[ "$std" = "$erwartet" ] || diff <(echo "$erwartet") <(echo "$std") | head
pruefe '[ "$(binds "{\"weather\": {\"location\": \"Bern\"}}" | cut -f1)" = "$erwartet" ]' "settings.json ohne keybinds (v1.1): gleiche Kürzel"
std_binds="$(binds "{}")"
pruefe 'grep -qx "SUPER + Return	exec_cmd kitty" <<<"$std_binds"' "SUPER + Return öffnet das Terminal"
pruefe 'grep -q "^SUPER + Q	close" <<<"$std_binds" && grep -q "^SUPER + C	close" <<<"$std_binds"' "SUPER + Q schliesst das aktive Fenster (SUPER + C bleibt als zweite Taste)"
pruefe 'grep -q "^CTRL + SUPER + Return	exec_cmd .*launcher toggle" <<<"$std_binds"' "CTRL + SUPER + Return öffnet die App-Suche"
pruefe 'grep -q "^SUPER + F	fullscreen" <<<"$std_binds"' "SUPER + F Vollbild"
pruefe '[ -z "$(cut -f1 <<<"$std_binds" | sort | uniq -d)" ]' "kein Kürzel doppelt belegt"
pruefe 'binds "{}" | grep -qx "SUPER + R	exec_cmd $T/h[0-9]*/.local/bin/shell-quickshell ipc launcher toggle" || binds "{}" | grep -q "^SUPER + R	exec_cmd .*shell-quickshell ipc launcher toggle$"' "SUPER + R öffnet den eingebauten Starter"
pruefe 'binds "{}" | grep -q "^SUPER + Space	exec_cmd .*shell-quickshell ipc launcher toggle$"' "SUPER + Space öffnet den Starter"
pruefe 'binds "{\"apps\": {\"launcher\": \"rofi -show drun\"}}" | grep -qx "SUPER + R	exec_cmd rofi -show drun"' "mit eigenem Befehl startet wieder rofi"

echo "== jedes Kürzel hat eine Beschreibung mit Gruppe (für den Spickzettel SUPER + F1)"
ohne="$(HOME="$T" "$lua" - <<'LUA'
package.path = "./config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
local gruppen = { Windows = 1, Workspaces = 1, Apps = 1, Panels = 1, Missa = 1, Screenshots = 1, System = 1, Custom = 1 }
for k, f in pairs(A.flags) do
    local g = (f.description or ""):match("^(%a+): .+")
    if not gruppen[g or ""] then print(k .. " (" .. tostring(f.description) .. ")") end
end
LUA
)"
pruefe '[ -z "$ohne" ]' "alle Kürzel beschrieben ($ohne)"

echo "== ändern, leeren, eigene"
b="$(binds '{"keybinds": {"terminal": "SUPER + T", "lock": "", "browser": "SUPER + B", "custom": [{"keys": "SUPER + SHIFT + Return", "command": "kitty -e htop"}]}}')"
pruefe 'grep -qx "SUPER + T	exec_cmd kitty" <<<"$b" && ! grep -q "^SUPER + Return	" <<<"$b"' "geändertes Kürzel wirkt, das alte ist frei"
pruefe '! grep -q "^SUPER + L" <<<"$b"' "leeres Kürzel: Aktion ohne Taste"
pruefe 'grep -qx "SUPER + B	exec_cmd firefox" <<<"$b"' "Browser bekommt eine Taste"
pruefe 'grep -qx "SUPER + SHIFT + Return	exec_cmd kitty -e htop" <<<"$b"' "eigenes Kürzel"
b="$(binds '{"keybinds": {"workspace_mod": "ALT", "move_mod": "ALT + SHIFT", "mouse_mod": ""}}')"
pruefe 'grep -q "^ALT + 1	" <<<"$b" && grep -q "^ALT + SHIFT + 0	" <<<"$b" && ! grep -q "mouse:272" <<<"$b" && ! grep -q "^SUPER + 1	" <<<"$b"' "Modifikatoren für Arbeitsflächen und Maus"

echo "== SUPER+U bleibt erreichbar"
h="$T/su"; mkdir -p "$h/.config/hypr-shell"; echo '{}' > "$h/.config/hypr-shell/settings.json"
out="$(HOME="$h" "$REPO/bin/shell-set" keybinds.settings "" 2>&1 || true)"
pruefe '! HOME="$h" "$REPO/bin/shell-set" keybinds.settings "" >/dev/null 2>&1 && grep -q "must not be empty" <<<"$out"' "shell-set lässt das Kürzel der App nicht leeren"
pruefe 'binds "{\"keybinds\": {\"settings\": \"\"}}" | grep -q "^SUPER + U	"' "von Hand geleert: SUPER + U gilt trotzdem"

echo "== doppelte Belegung"
out="$(HOME="$h" "$REPO/bin/shell-set" keybinds.files "SUPER + Return" 2>&1 || true)"
pruefe '! HOME="$h" "$REPO/bin/shell-set" keybinds.files "SUPER + Return" >/dev/null 2>&1 && grep -q "already used by Terminal" <<<"$out" && [ "$(jq -c . "$h/.config/hypr-shell/settings.json")" = "{}" ]' "shell-set lehnt ab und nennt die Aktion ($out)"
out="$(HOME="$h" "$REPO/bin/shell-set" keybinds.terminal "SUPER + E" 2>&1 || true)"
pruefe 'grep -q "also used by File manager" <<<"$out"' "auch in die andere Richtung ($out)"
pruefe '! HOME="$h" "$REPO/bin/shell-set" keybinds.custom "[{\"keys\": \"SUPER + A\", \"command\": \"x\"}]" >/dev/null 2>&1' "eigenes Kürzel auf belegter Taste wird abgelehnt"
pruefe '! HOME="$h" "$REPO/bin/shell-set" keybinds.move_mod SUPER >/dev/null 2>&1' "Modifikator, der Arbeitsflächen-Kürzel doppelt belegt, wird abgelehnt"
b="$(binds '{"keybinds": {"files": "SUPER + Return"}}')"
pruefe '[ "$(grep -c "^SUPER + Return	" <<<"$b")" = 1 ] && grep -qx "SUPER + Return	exec_cmd kitty" <<<"$b" && ! grep -q "nautilus" <<<"$b"' "von Hand doppelt eingetragen: die spätere Aktion verliert die Taste, Hyprland lädt ohne Fehler"
echo '{"keybinds": {"files": "SUPER + Return"}}' > "$T/doppelt.json"
meldung="$(HOME="$h" "$REPO/bin/shell-apply" --check "$T/doppelt.json" || true)"
pruefe 'grep -q "^keybinds.files: SUPER + Q is already used by Terminal" <<<"$meldung" && grep -q "^keybinds.terminal: SUPER + Q is also used by File manager" <<<"$meldung"' "Meldung nennt beide"
out="$(HOME="$h" "$REPO/bin/shell-set" keybinds.terminal "SUPER + SHIFT + 1" 2>&1 || true)"
pruefe 'grep -q "SUPER + SHIFT + 1 is also used by Move window to workspace" <<<"$out"' "Konflikt mit einer Gruppe nennt die kollidierende Kombination ($out)"
echo '{"keybinds": {"terminal": "SUPER + SHIFT + 1"}}' > "$T/gruppe.json"
meldung="$(HOME="$h" "$REPO/bin/shell-apply" --check "$T/gruppe.json" || true)"
pruefe 'grep -q "^keybinds.move_mod: SUPER + SHIFT + 1 is already used by Terminal" <<<"$meldung"' "… auch in der Meldung zur Gruppe ($(head -n1 <<<"$meldung"))"

echo "== feste Tasten (Lautstärke, Helligkeit, Medien)"
fest_lua="$(grep -oE '^hl\.bind\("[^"]+"' config/hypr/hyprland.lua | sed 's/^hl\.bind("//; s/"$//' | sort)"
fest_schema="$(jq -r '.fixed_binds[].keys' settings/schema.json | sort)"
pruefe '[ -n "$fest_lua" ] && [ "$fest_lua" = "$fest_schema" ]' "fixed_binds im Schema = feste hl.bind in hyprland.lua ($(wc -l <<<"$fest_lua") Tasten)"
[ "$fest_lua" = "$fest_schema" ] || diff <(echo "$fest_lua") <(echo "$fest_schema") | head
out="$(HOME="$h" "$REPO/bin/shell-set" keybinds.custom '[{"keys": "XF86AudioRaiseVolume", "command": "x"}]' 2>&1 || true)"
pruefe '! HOME="$h" "$REPO/bin/shell-set" keybinds.custom "[{\"keys\": \"XF86AudioRaiseVolume\", \"command\": \"x\"}]" >/dev/null 2>&1 && grep -q "already used by Volume up" <<<"$out"' "eigenes Kürzel auf der Lautstärke-Taste wird abgelehnt ($out)"
pruefe '! HOME="$h" "$REPO/bin/shell-set" keybinds.lock XF86AudioMute >/dev/null 2>&1' "einstellbares Kürzel auf einer festen Taste wird abgelehnt"
b="$(binds '{"keybinds": {"lock": "XF86AudioMute", "custom": [{"keys": "XF86AudioPlay", "command": "x"}]}}')"
pruefe '[ "$(grep -c "^XF86AudioMute	" <<<"$b")" = 1 ] && grep -q "^XF86AudioMute	exec_cmd .*shell-osd volume mute" <<<"$b" && ! grep -q "	exec_cmd x$" <<<"$b"' "von Hand auf feste Tasten gelegt: die feste Taste bleibt, Hyprland lädt ohne Fehler"

exit "$fehler"
