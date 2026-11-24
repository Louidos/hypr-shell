#!/usr/bin/env bash
# Prüft den einheitlichen Glas-Look ohne Bildschirm:
#   1. Voreinstellungen glass (Standard), minimal, gaming: shell-look wendet sie an, ein Schritt im Verlauf
#   2. Fenster in hyprland.lua: weisser Rand mit theme.border.opacity (aktiv/inaktiv), Akzentfarbe als
#      Option, Rundung, Transparenz aktiv/inaktiv, Ausnahmen (Spiele, Videos, Bildbearbeitung) undurchsichtig
#   3. Leiste und rofi im selben Glas (Farbe, Rand, Rundung), Glas wird bei hellem Bild dunkler
#   Dazu das Leuchten (theme.border.glow): Fenster-Schatten in Randfarbe, ohne Ausnahmen und Vollbild;
#   Karten, Pillen und Leuchten der Oberfläche prüft tests/oberflaeche.sh (Abschnitt Design-Werte)
# shellcheck disable=SC2016,SC2034,SC2329
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" KEINE_MELDUNG=1
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
mkdir -p "$HOME/.config/hypr-shell" "$HOME/.local/share/hypr-shell" "$HOME/.local/bin"
for b in "$REPO"/bin/*; do ln -s "$b" "$HOME/.local/bin/"; done
cp "$REPO/settings/schema.json" "$HOME/.local/share/hypr-shell/schema.json"
echo '{}' > "$HOME/.config/hypr-shell/settings.json"
S="$HOME/.config/hypr-shell/settings.json"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
wert() { jq -c "$1" "$S"; }

echo "== 1. Voreinstellungen"
pruefe '[ "$("$REPO/bin/shell-look" presets | jq -c "map(.name) | sort")" = "[\"gaming\",\"glass\",\"minimal\"]" ]' "glass, minimal und gaming"
pruefe '[ "$(jq -r ".keys[] | select(.key == \"look.preset\") | .default" settings/schema.json)" = glass ]' "Standard ist glass"
for f in settings/presets/look/*.json; do
    n="$(basename "$f" .json)"
    jq '[to_entries[] | select(.key | startswith("_") | not)] | reduce .[] as $e ({}; setpath($e.key | split("."); $e.value))' "$f" > "$T/p.json"
    pruefe '"$REPO/bin/shell-apply" --check "$T/p.json" >/dev/null 2>&1' "$n: alle Werte gültig"
done
glass_abw="$(jq -r --slurpfile s settings/schema.json 'to_entries[] | select(.key | startswith("_") | not) | select(.key != "look.preset") | . as $e | ($s[0].keys[] | select(.key == $e.key) | .default) as $d | select($d != $e.value) | "\($e.key)=\($e.value) (Standard \($d))"' settings/presets/look/glass.json)"
pruefe '[ -z "$glass_abw" ]' "glass = genau die Standardwerte (Look wie die Vorlage)${glass_abw:+: $glass_abw}"
pruefe 'jq -e "[\"theme.border.glow\", \"theme.card.opacity\", \"theme.spacing.gap\", \"theme.font.title_scale\"] - keys == []" settings/presets/look/minimal.json settings/presets/look/gaming.json >/dev/null' "minimal und gaming nennen auch die neuen Design-Werte"
pruefe 'jq -e ".\"theme.border.glow\" == false" settings/presets/look/minimal.json settings/presets/look/gaming.json >/dev/null' "minimal und gaming: kein Leuchten"
pruefe 'jq -e ".\"look.blur.enabled\" == false and .\"look.blur.size\" < 12 and .\"look.blur.passes\" < 2" settings/presets/look/gaming.json >/dev/null && [ "$(jq ".\"theme.radius.panel\"" settings/presets/look/minimal.json)" -lt 26 ]' "gaming: weniger Blur; minimal: kleinere Radien"
"$REPO/bin/shell-look" preset gaming >/dev/null
pruefe '[ "$(wert ".look.preset")" = "\"gaming\"" ] && [ "$(wert ".look.blur.enabled")" = false ] && jq -e ".look.opacity.active == 1" "$S" >/dev/null' "gaming: kein Blur, alles undurchsichtig"
"$REPO/bin/shell-set" undo >/dev/null
pruefe '[ "$(wert ".look.preset")" = null ]' "ein Schritt im Verlauf (undo nimmt die ganze Voreinstellung zurück)"
pruefe '! "$REPO/bin/shell-look" preset gibtsnicht 2>/dev/null' "unbekannte Voreinstellung: Meldung"
"$REPO/bin/shell-set" reset all >/dev/null 2>&1

echo "== 2. Fenster"
lua=$(command -v lua5.4 || command -v lua || true)
fenster() { # settings-json -> "aktiv|inaktiv|opacity_aktiv|opacity_inaktiv|rundung|ausnahmen"
    printf '%s\n' "$1" > "$S"; "$REPO/bin/shell-apply" --no-reload --no-migrate >/dev/null 2>&1
    HYPR_SHELL_INPUT_DEVICES=/nonexistent "$lua" - <<'LUA'
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
local r = {}
for _, a in ipairs(A.aufrufe) do
    if a[1] == "config" and a[2].general and a[2].general.col then r.a = a[2].general.col.active_border; r.i = a[2].general.col.inactive_border end
    if a[1] == "config" and a[2].decoration then r.oa = a[2].decoration.active_opacity; r.oi = a[2].decoration.inactive_opacity; r.ro = a[2].decoration.rounding end
    if a[1] == "window_rule" and a[2].name == "hypr-shell-opaque" then r.ex = a[2].match.class .. " " .. a[2].opacity end
    if a[1] == "config" and a[2].decoration and a[2].decoration.shadow then local sh = a[2].decoration.shadow; r.sh = tostring(sh.enabled) .. " " .. tostring(sh.color) .. " " .. tostring(sh.range) end
    if a[1] == "window_rule" and a[2].name == "hypr-shell-glow-aus" and a[2].no_shadow then r.ga = a[2].match.class end
    if a[1] == "window_rule" and a[2].name == "hypr-shell-glow-vollbild" and a[2].no_shadow and a[2].match.fullscreen then r.gv = "vollbild" end
end
print(table.concat({ tostring(r.a), tostring(r.i), tostring(r.oa), tostring(r.oi), tostring(r.ro), tostring(r.ex), tostring(r.sh), tostring(r.ga), tostring(r.gv) }, "|"))
LUA
}
if [ -n "$lua" ]; then
    f="$(fenster '{}')"
    pruefe '[[ "$f" == "rgba(ffffffcc)|rgba(ffffff4d)|0.95|0.88|18|"* ]]' "Standard wie die Vorlage: heller Rand 0.8/0.3, Transparenz 0.95/0.88, Rundung 18 ($f)"
    pruefe '[[ "$f" == *"|true rgba(ffffff40) 10|^(steam_app_[0-9]+|"*"|vollbild" ]]' "Standard: Fenster leuchten (Schein in Randfarbe, 10 px, 0.25), Spiele, Videos und Vollbild nicht ($f)"
    pruefe '[[ "$f" == *"steam_app_[0-9]+"*"mpv"*"gimp"*"1.0 override 1.0 override|"* ]]' "Spiele, Videos, Bildbearbeitung bleiben undurchsichtig"
    f="$(fenster '{"look": {"border_color": "accent"}}')"
    pruefe '[[ "$f" == "rgba(d4d4d4ee)|"* ]]' "Akzentfarbe als Option ($f)"
    f="$(fenster '{"theme": {"border": {"color": "#ff0000", "opacity": 0.5, "opacity_inactive": 0.1}}, "look": {"opacity": {"exceptions": []}}}')"
    pruefe '[[ "$f" == "rgba(ff000080)|rgba(ff00001a)|"*"|nil|"* ]]' "eigene Randfarbe und Deckkraft; leere Ausnahmeliste = keine Regel ($f)"
    f="$(fenster '{"theme": {"border": {"glow": false}}}')"
    pruefe '[[ "$f" == *"|true 1712986650 14|nil|nil" ]]' "ohne Leuchten: normaler dunkler Schatten, keine Leucht-Regeln ($f)"
    f="$(fenster '{"theme": {"border": {"color": "#ff8800", "glow": true, "glow_size": 12, "glow_opacity": 0.5}}}')"
    pruefe '[[ "$f" == *"|true rgba(ff880080) 12|^(steam_app_[0-9]+|"*"gimp"*")\$|vollbild" ]]' "theme.border.glow: Schatten in Randfarbe (Deckkraft glow_opacity, Grösse glow_size), nicht für Spiele, Videos, Bildbearbeitung und Vollbild ($f)"
    f="$(fenster '{"look": {"shadow": false}, "theme": {"border": {"glow": true}}}')"
    pruefe '[[ "$f" == *"|true rgba(ffffff40) 10|"* ]]' "Leuchten auch ohne Schatten (look.shadow aus), Standard 10 px und 0.25 ($f)"
else
    echo "  Hinweis: lua fehlt, übersprungen"
fi

echo "== 3. Leiste und rofi"
echo '{}' > "$S"; "$REPO/bin/shell-apply" --no-reload >/dev/null 2>&1
st="$HOME/.config/waybar/style.css"; ro="$HOME/.config/rofi/hypr-shell-settings.rasi"
pruefe 'grep -q "background: rgba(26, 26, 29, 0.46)" "$st" && grep -q "border: 2px solid rgba(255, 255, 255, 0.80)" "$st" && grep -q "border-radius: 26px" "$st"' "Leiste: graues Glas, heller Rand 2 px, Rundung 26"
pruefe 'grep -q "background-color: rgba(26, 26, 29, 0.46)" "$ro" && grep -q "border-color:     rgba(255, 255, 255, 0.80)" "$ro" && grep -q "border-radius:    26px" "$ro"' "rofi: dasselbe Glas"
pruefe '[ "$(sed -E "s#^[[:space:]]*//.*\$##" "$HOME/.config/waybar/config.jsonc" | jq -c "[.\"margin-top\", .\"margin-left\"]")" = "[6,12]" ]' "schwebende Leiste mit Abstand zum Rand"
echo 0.95 > "$HOME/.local/share/hypr-shell/wallpaper-luma"; "$REPO/bin/shell-apply" --no-reload >/dev/null 2>&1
pruefe 'grep -qE "background: rgba\(26, 26, 29, 0\.(8|9)[0-9]\)" "$st"' "sehr helles Hintergrundbild: Glas automatisch dunkler"
exit "$fehler"
