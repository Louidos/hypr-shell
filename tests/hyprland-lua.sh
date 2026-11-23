#!/usr/bin/env bash
# Führt config/hypr/hyprland.lua mit einer Attrappe der Hyprland-API aus.
# Prüft: Lua-Syntax, nur dokumentierte hl-Aufrufe, Tastenkürzel nicht doppelt,
# alle Pflicht-Kürzel vorhanden, Autostart-Liste vollständig, Werte aus settings.json und der alten
# hypr-shell-local.lua, Standardwerte gleich wie im Schema.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

lua=$(command -v lua5.4 || command -v lua || true)
if [ -z "$lua" ]; then
    echo "Hinweis: lua fehlt, Test übersprungen."
    exit 0
fi

fake_home=$(mktemp -d)
trap 'rm -rf "$fake_home"' EXIT

HOME="$fake_home" "$lua" - <<'LUA'
package.path = "./config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
for _, fn in ipairs(A.start) do fn() end

local fehler = 0
local function pruefe(bed, text) if not bed then print("FEHLER: " .. text); fehler = fehler + 1 end end

local pflicht = { "SUPER + Q", "SUPER + C", "SUPER + E", "SUPER + R", "ALT + Space", "SUPER + Space", "SUPER + V",
    "SUPER + M", "SUPER + L", "SUPER + left", "SUPER + right", "SUPER + up", "SUPER + down",
    "SUPER + mouse:272", "SUPER + mouse:273", "Print", "SHIFT + Print",
    "XF86AudioRaiseVolume", "XF86AudioLowerVolume", "XF86AudioMute",
    "XF86MonBrightnessUp", "XF86MonBrightnessDown", "XF86AudioPlay", "XF86AudioNext", "XF86AudioPrev",
    "SUPER + ALT + D", "SUPER + D", "SUPER + W", "SUPER + A", "SUPER + N", "SUPER + U", "SUPER + Escape", "XF86KbdBrightnessUp", "XF86KbdBrightnessDown", "SUPER + ALT + W" }
for i = 0, 9 do
    table.insert(pflicht, "SUPER + " .. i)
    table.insert(pflicht, "SUPER + SHIFT + " .. i)
end
for _, k in ipairs(pflicht) do pruefe(A.binds[k] ~= nil, "Kürzel fehlt: " .. k) end

local autostart = {}
for _, a in ipairs(A.aufrufe) do
    if a[1] == "exec_cmd" then table.insert(autostart, a[2]) end
end
local alles = table.concat(autostart, "\n")
-- genau ein Benachrichtigungsdienst: der von hypr-shell (Quickshell), swaync wird nicht mehr gestartet
pruefe(alles:find("swaync") == nil, "swaync darf nicht mehr gestartet werden")
-- genau eine Lautstärke-Anzeige: die von hypr-shell (shell-osd), swayosd wird nicht mehr gestartet
pruefe(alles:find("swayosd") == nil, "swayosd darf nicht mehr gestartet werden")
for _, prog in ipairs({ "waybar", "awww%-daemon", "hypridle", "shell%-quickshell" }) do
    pruefe(alles:find(prog) ~= nil, "Autostart fehlt: " .. prog)
end

local ns = {}
for _, r in ipairs(A.layer) do if r.blur then ns[#ns + 1] = r.match.namespace end end
local nsalle = table.concat(ns, " ")
for _, n in ipairs({ "waybar", "hypr%-shell", "rofi" }) do
    pruefe(nsalle:find(n) ~= nil, "Blur-Regel fehlt für: " .. n)
end

-- kein fester Benutzer oder Pfad
local f = io.open("config/hypr/hyprland.lua"):read("a")
pruefe(not f:find("/home/"), "fester Pfad /home/ in hyprland.lua")

if fehler > 0 then os.exit(1) end
print("hyprland.lua: " .. #pflicht .. " Pflicht-Kürzel, Autostart und Blur-Regeln in Ordnung.")
LUA

# Werte aus settings.json (über die erzeugte hypr-shell-settings.lua) und der alten hypr-shell-local.lua
werte() { # local-lua-inhalt settings-json -> "scale natural_scroll tap_to_click force_zero_scaling layout gaps_in rounding"
    rm -rf "$fake_home/lokal"; mkdir -p "$fake_home/lokal/.config/hypr-shell"
    mkdir -p "$fake_home/lokal/.config/hypr"
    [ -n "$1" ] && printf '%s\n' "$1" > "$fake_home/lokal/.config/hypr/hypr-shell-local.lua"
    if [ -n "$2" ]; then
        printf '%s\n' "$2" > "$fake_home/lokal/.config/hypr-shell/settings.json"
        HOME="$fake_home/lokal" bin/shell-apply --no-reload --no-migrate 2>/dev/null || true
    fi
    HOME="$fake_home/lokal" "$lua" - <<'LUA'
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
local scale, ns, ttc, zero, layout, gaps, rounding
for _, a in ipairs(A.aufrufe) do
    if a[1] == "monitor" and a[2].output == "" then scale = a[2].scale end
    if a[1] == "config" and a[2].input then ns = a[2].input.touchpad.natural_scroll; ttc = a[2].input.touchpad.tap_to_click; layout = a[2].input.kb_layout end
    if a[1] == "config" and a[2].xwayland then zero = a[2].xwayland.force_zero_scaling end
    if a[1] == "config" and a[2].general then gaps = a[2].general.gaps_in end
    if a[1] == "config" and a[2].decoration then rounding = a[2].decoration.rounding end
end
print(table.concat({ tostring(scale), tostring(ns), tostring(ttc), tostring(zero), tostring(layout), tostring(gaps), tostring(rounding) }, " "))
LUA
}
fehler=0
pruef() { if [ "$1" = "$2" ]; then echo "  ok: $3"; else echo "FEHLER: $3: $1 (erwartet: $2)"; fehler=1; fi; }
pruef "$(werte '' '')" "auto false true true us 6 12" "ohne Dateien: Standardwerte"
pruef "$(werte 'return { kb_layout = "ch", kb_variant = "de", scale = 1.5, natural_scroll = true, tap_to_click = false }' '')" \
    "1.5 true false true ch 6 12" "alte hypr-shell-local.lua (v1.1) wirkt weiter"
pruef "$(werte 'return { kb_layout = "ch", kb_variant = "de" }' '')" "auto false true true ch 6 12" "ältere hypr-shell-local.lua ohne Laptop-Werte: Standard"
pruef "$(werte '' '{"look": {"gaps": {"inner": 10}, "rounding": 20}, "input": {"layout": "de"}, "monitors": {"scale": "2"}}')" \
    "2 false true true de 10 20" "settings.json wirkt über hypr-shell-settings.lua"
pruef "$(werte 'return { kb_layout = "ch", scale = 1.5 }' '{"input": {"layout": "fr"}}')" \
    "1.5 false true true fr 6 12" "settings.json gewinnt, hypr-shell-local.lua füllt Lücken"

# Standardwerte in hyprland.lua = Standardwerte im Schema: mit und ohne erzeugte Datei gleiche Aufrufe
aufrufe() { # mit-datei(0/1)
    rm -rf "$fake_home/std"; mkdir -p "$fake_home/std/.config/hypr"
    [ "$1" = 1 ] && HOME="$fake_home/std" bin/shell-apply --no-reload --no-migrate
    HOME="$fake_home/std" "$lua" - <<'LUA'
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
local function ser(v)
    if type(v) ~= "table" then return type(v) == "number" and string.format("%g", v) or tostring(v) end
    local k = {}
    for x in pairs(v) do k[#k + 1] = x end
    table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
    local r = {}
    for _, x in ipairs(k) do r[#r + 1] = tostring(x) .. "=" .. ser(v[x]) end
    return "{" .. table.concat(r, ",") .. "}"
end
for _, a in ipairs(A.aufrufe) do print(ser(a)) end
local b = {}
for k, v in pairs(A.binds) do b[#b + 1] = k .. "=" .. ser(v) end
table.sort(b)
print(table.concat(b, "\n"))
LUA
}
if command -v jq >/dev/null 2>&1; then
    ohne="$(aufrufe 0)"; mit="$(aufrufe 1)"
    if [ "$ohne" = "$mit" ]; then echo "  ok: Standardwerte in hyprland.lua passen zum Schema"
    else echo "FEHLER: Standardwerte in hyprland.lua weichen vom Schema ab:"; diff <(echo "$ohne") <(echo "$mit") | head -n 20; fehler=1; fi
fi
exit "$fehler"
