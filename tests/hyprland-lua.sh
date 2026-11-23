#!/usr/bin/env bash
# Führt config/hypr/hyprland.lua mit einer Attrappe der Hyprland-API aus.
# Prüft: Lua-Syntax, nur dokumentierte hl-Aufrufe, Tastenkürzel nicht doppelt,
# alle Pflicht-Kürzel vorhanden, Autostart-Liste vollständig, Laptop-Werte aus hypr-shell-local.lua.
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

local pflicht = { "SUPER + Q", "SUPER + C", "SUPER + E", "SUPER + R", "ALT + Space", "SUPER + V",
    "SUPER + M", "SUPER + L", "SUPER + left", "SUPER + right", "SUPER + up", "SUPER + down",
    "SUPER + mouse:272", "SUPER + mouse:273", "Print", "SHIFT + Print",
    "XF86AudioRaiseVolume", "XF86AudioLowerVolume", "XF86AudioMute",
    "XF86MonBrightnessUp", "XF86MonBrightnessDown", "XF86AudioPlay", "XF86AudioNext", "XF86AudioPrev",
    "SUPER + ALT + D", "SUPER + W", "SUPER + A" }
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
for _, prog in ipairs({ "waybar", "awww%-daemon", "swaync", "hypridle", "swayosd%-server", "shell%-quickshell" }) do
    pruefe(alles:find(prog) ~= nil, "Autostart fehlt: " .. prog)
end

local ns = {}
for _, r in ipairs(A.layer) do if r.blur then ns[#ns + 1] = r.match.namespace end end
local nsalle = table.concat(ns, " ")
for _, n in ipairs({ "waybar", "hypr%-shell", "rofi", "swaync" }) do
    pruefe(nsalle:find(n) ~= nil, "Blur-Regel fehlt für: " .. n)
end

-- kein fester Benutzer oder Pfad
local f = io.open("config/hypr/hyprland.lua"):read("a")
pruefe(not f:find("/home/"), "fester Pfad /home/ in hyprland.lua")

if fehler > 0 then os.exit(1) end
print("hyprland.lua: " .. #pflicht .. " Pflicht-Kürzel, Autostart und Blur-Regeln in Ordnung.")
LUA

# Laptop-Werte aus hypr-shell-local.lua: neue Datei mit Werten, alte Datei ohne sie
laptop() { # lua-Inhalt der lokalen Datei -> "scale natural_scroll tap_to_click force_zero_scaling"
    mkdir -p "$fake_home/lokal"
    printf '%s\n' "$1" > "$fake_home/lokal/hypr-shell-local.lua"
    HOME="$fake_home" "$lua" - <<'LUA'
package.path = os.getenv("HOME") .. "/lokal/?.lua;./config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
local scale, ns, ttc, zero
for _, a in ipairs(A.aufrufe) do
    if a[1] == "monitor" then scale = a[2].scale end
    if a[1] == "config" and a[2].input then ns = a[2].input.touchpad.natural_scroll; ttc = a[2].input.touchpad.tap_to_click end
    if a[1] == "config" and a[2].xwayland then zero = a[2].xwayland.force_zero_scaling end
end
print(tostring(scale) .. " " .. tostring(ns) .. " " .. tostring(ttc) .. " " .. tostring(zero))
LUA
}
fehler=0
neu="$(laptop 'return { kb_layout = "ch", kb_variant = "de", scale = 1.5, natural_scroll = true, tap_to_click = false }')"
alt="$(laptop 'return { kb_layout = "ch", kb_variant = "de" }')"
if [ "$neu" = "1.5 true false true" ]; then echo "  ok: scale, natural_scroll, tap_to_click aus hypr-shell-local.lua, XWayland ohne Hochskalieren"; else echo "FEHLER: Laptop-Werte: $neu"; fehler=1; fi
if [ "$alt" = "auto false true true" ]; then echo "  ok: ältere hypr-shell-local.lua ohne diese Werte: Standard"; else echo "FEHLER: alte Datei: $alt"; fehler=1; fi
exit "$fehler"
