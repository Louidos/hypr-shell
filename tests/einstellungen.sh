#!/usr/bin/env bash
# Prüft Schema und shell-apply ohne Bildschirm:
#   1. jeder Schlüssel im Schema hat Typ, Standard, Titel, Erklärung, Seite und Abschnitt;
#      Standardwerte sind selbst gültig, kein Schlüssel ist Teil eines anderen
#   2. settings/settings.example.json passt zum Schema (= shell-apply --example)
#   3. jeder Schlüssel wird irgendwo gelesen (Quickshell, hyprland.lua oder shell-apply); jeder
#      Schlüssel, den die Oberfläche liest, steht im Schema, mit gleichem Standard als Rückfall
#   4. shell-apply erzeugt in einem leeren HOME mit den Standardwerten genau die Dateien aus config/
#      (gleiches Aussehen wie vorher) und für drei Beispiel-Einstellungen die erwarteten Dateien
#   5. ein falscher Wert und kaputtes JSON brechen nichts (Standardwert bzw. letzter gültiger Stand)
#   6. eine settings.json von v1.0.0 funktioniert unverändert; Werte aus hypr-shell-local.lua wandern
#      einmalig in settings.json
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
export KEINE_MELDUNG=1

fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
SCHEMA=settings/schema.json
apply() { HOME="$1" "$REPO/bin/shell-apply" "${@:2}"; }
gleich() { [ -f "$1" ] && [ -f "$2" ] && [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ]; }   # cmp fehlt manchmal
neues_home() { local h="$T/$1"; rm -rf "$h"; mkdir -p "$h/.config/hypr-shell"; printf '%s\n' "${2:-{\}}" > "$h/.config/hypr-shell/settings.json"; echo "$h"; }

echo "== 1. Schema"
pruefe 'jq -e ".keys | length > 50" $SCHEMA >/dev/null' "Schema mit $(jq '.keys | length' $SCHEMA) Werten"
fehlend="$(jq -r '.keys[] | select((.key and .type and has("default") and .title and .description and .page and .section) | not) | .key // "?"' $SCHEMA)"
pruefe '[ -z "$fehlend" ]' "jeder Schlüssel hat Typ, Standard, Titel, Erklärung, Seite und Abschnitt ($fehlend)"
seiten="$(jq -r '[.pages[].id] as $p | .keys[] | select(.page as $x | $p | index([$x]) | not) | .key' $SCHEMA)"
pruefe '[ -z "$seiten" ]' "jede Seite gibt es in pages ($seiten)"
pruefe '[ "$(jq -r "[.pages[].id] | join(\",\")" $SCHEMA)" = "home,bar,look,theme,desktop,dashboard,panel,dock,system,laptop,integrations,lock,input,monitors,apps,keybinds,about" ]' "Seiten in der Reihenfolge der App"
doppelt="$(jq -r '[.keys[].key] as $k | $k[] as $a | $k[] | select(startswith($a + ".")) | "\($a) < \(.)"' $SCHEMA)"
pruefe '[ -z "$doppelt" ]' "kein Schlüssel ist Teil eines anderen ($doppelt)"
pruefe '[ "$(jq "[.keys[].key] | length" $SCHEMA)" = "$(jq "[.keys[].key] | unique | length" $SCHEMA)" ]' "keine doppelten Schlüssel"
bereich="$(jq -r '.keys[] | select(.type == "int" or .type == "number") | select(.min == null or .max == null or .step == null) | .key' $SCHEMA)"
pruefe '[ -z "$bereich" ]' "jede Zahl hat Minimum, Maximum und Schritt ($bereich)"
auswahl="$(jq -r '.keys[] | select(.type == "enum" or .type == "list") | select((.values | type) != "array" or (.values | length) == 0) | .key' $SCHEMA)"
pruefe '[ -z "$auswahl" ]' "jede Auswahl und Liste nennt ihre erlaubten Werte ($auswahl)"
pruefe 'apply "$T" --example > "$T/example.json" && apply "$T" --check "$T/example.json"' "alle Standardwerte sind gültig"

echo "== 2. Beispiel-Datei"
norm() { jq -S 'walk(if type == "number" then . + 0 else . end)' "$1"; }
pruefe '[ "$(norm settings/settings.example.json)" = "$(norm "$T/example.json")" ]' "settings.example.json = Standardwerte aus dem Schema"

echo "== 3. jeder Wert wird gelesen"
tot=()
while IFS= read -r k; do
    var="S_$(tr '.-' '__' <<<"$k")"
    if grep -rqF "\"$k\"" quickshell --include='*.qml' \
        || grep -qF "S.$k" config/hypr/hyprland.lua \
        || { [ "${k#keybinds.}" != "$k" ] && grep -qE "K\\.${k#keybinds.}\\b" config/hypr/hyprland.lua; } \
        || { [[ "$k" =~ ^desktop\.(clock|resources)\.(x|y|scale)$ ]] && grep -rqF "Ui.widget(\"${BASH_REMATCH[1]}\", \"${BASH_REMATCH[2]}\"" quickshell; } \
        || grep -qE "(\\\$$var|\\\$\\{?$var\\b|\\\$e\\.$k\\b)" bin/shell-apply \
        || grep -rqF "'.$k " bin || grep -rqF "'.$k'" bin; then :; else tot+=("$k"); fi
done < <(jq -r '.keys[].key' $SCHEMA)
pruefe '[ "${#tot[@]}" -eq 0 ]' "kein Wert ohne Wirkung (${tot[*]:-})"

echo "== 3b. Schema und Oberfläche stimmen überein"
# Jedes Settings.get("schlüssel", rückfall) (und num("schlüssel", rückfall, …) im Dock) nennt einen
# Schlüssel aus dem Schema; ein fester Rückfallwert ist genau der Standard aus dem Schema.
# Rückfälle aus Ausdrücken (z. B. Theme.panelRadius) prüft das nicht.
if command -v python3 >/dev/null; then
    abweichung="$(python3 - "$SCHEMA" quickshell <<'PY'
import json, os, re, sys
keys = {k["key"]: k for k in json.load(open(sys.argv[1]))["keys"]}
muster = re.compile(r'(?:Settings\.get|\bnum)\(\s*"([^"]+)"\s*(?:,\s*((?:[^()]|\([^()]*\))*?))?\s*(?:\)|,)')
for wurzel, _, dateien in os.walk(sys.argv[2]):
    for f in sorted(dateien):
        if not f.endswith((".qml", ".js")):
            continue
        p = os.path.join(wurzel, f)
        s = open(p, encoding="utf-8").read()
        for m in muster.finditer(s):
            k, d = m.group(1), m.group(2)
            ort = "%s:%d" % (p, s[:m.start()].count("\n") + 1)
            if k not in keys:
                if not any(x.startswith(k + ".") for x in keys):
                    print("%s: %s fehlt im Schema" % (ort, k))
                continue
            if d is None:
                continue
            try:
                wert = json.loads(d)
            except ValueError:
                continue
            if wert != keys[k]["default"]:
                print("%s: %s Rückfall %s, Schema %s" % (ort, k, d.strip(), json.dumps(keys[k]["default"])))
PY
)"
    pruefe '[ -z "$abweichung" ]' "jeder Settings.get-Schlüssel steht im Schema, Rückfall = Standard${abweichung:+:
$abweichung}"
else
    echo "  Hinweis: python3 fehlt, Abgleich übersprungen"
fi

echo "== 4. erzeugte Dateien"
h="$(neues_home std "$(cat settings/settings.example.json)")"
apply "$h" --no-reload
for f in waybar/config.jsonc waybar/style.css hypr/hypridle.conf hypr/hyprlock.conf rofi/hypr-shell-settings.rasi; do
    pruefe 'gleich "config/$f" "$h/.config/$f"' "Standardwerte ergeben genau config/$f"
done
pruefe 'head -n1 "$h/.config/hypr/hypr-shell-settings.lua" | grep -q "erzeugt von hypr-shell – nicht von Hand ändern"' "erzeugte Dateien tragen den Hinweis oben"
pruefe 'jq -e ".bar.height == 30 and .look.gaps.inner == 6" "$h/.local/share/hypr-shell/settings.effective.json" >/dev/null' "gültige Werte für Quickshell"
pruefe '[ ! -s "$h/.local/share/hypr-shell/settings.errors" ]' "keine Fehler mit der Beispiel-Datei"
pruefe '[ -z "$(find "$h" -name "*.tmp")" ]' "keine temporären Dateien übrig"
if command -v luac5.4 >/dev/null || command -v luac >/dev/null; then
    pruefe '"$(command -v luac5.4 || command -v luac)" -p "$h/.config/hypr/hypr-shell-settings.lua"' "hypr-shell-settings.lua ist gültiges Lua"
fi

waybar() { sed -E 's#^[[:space:]]*//.*$##' "$1/.config/waybar/config.jsonc" | jq -r "$2"; }
# Beispiel A: Leiste unten, höher, ohne Akku, 12-h-Uhr; längere Sperrzeit; grössere Abstände
h="$(neues_home a '{"bar": {"position": "bottom", "height": 40, "battery": false, "clock": "12h", "workspaces": 6, "modules": {"center": ["window"]}},
  "look": {"gaps": {"inner": 10}, "rounding": 20}, "lock": {"after": 10, "screen_off": 8, "suspend": 0, "avatar": false, "clock": "12h", "dim": 0.3}}')"
apply "$h" --no-reload
pruefe '[ "$(waybar "$h" .position)" = bottom ] && [ "$(waybar "$h" .height)" = 40 ]' "A: Leiste unten, 40 px"
pruefe '! waybar "$h" ".\"modules-right\"[]" | grep -qx battery && [ "$(waybar "$h" ".\"modules-center\" | join(\",\")")" = hyprland/window ]' "A: Akku aus, Fenstertitel in der Mitte"
pruefe '[ "$(waybar "$h" .clock.format)" = "{:%I:%M %p}" ] && [ "$(waybar "$h" ".\"hyprland/workspaces\".\"persistent-workspaces\".\"*\" | length")" = 6 ]' "A: 12-h-Uhr, 6 feste Arbeitsflächen"
idle="$h/.config/hypr/hypridle.conf"
pruefe 'grep -q "timeout = 600" "$idle" && grep -A2 "timeout = 480" "$idle" | grep -q dpms && ! grep -q "systemctl suspend" "$idle"' "A: sperren nach 10 min, Bildschirm aus nach 8 min, kein Standby"
lock="$h/.config/hypr/hyprlock.conf"
pruefe '! grep -q "path = ~/.face" "$lock" && grep -q "date +%I" "$lock" && grep -q "brightness = 0.7" "$lock"' "A: Sperrbildschirm ohne Profilbild, 12 h, weniger dunkel"
pruefe 'grep -q "\[\"inner\"\] = 10" "$h/.config/hypr/hypr-shell-settings.lua" && grep -q "\[\"rounding\"\] = 20" "$h/.config/hypr/hypr-shell-settings.lua"' "A: Abstand und Rundung für Hyprland"

# Beispiel B: andere Schriften, Schriftgrösse, Leiste durchsichtiger, Symbolthema, anderes Terminal
h="$(neues_home b '{"theme": {"font": {"ui": "Noto Sans", "mono": "Hack Nerd Font", "display": "Oswald", "scale": 1.2}, "icons": "Adwaita", "glass": 0.6},
  "bar": {"opacity": 0.5}, "apps": {"terminal": "foot", "launcher": "fuzzel"}}')"
apply "$h" --no-reload
st="$h/.config/waybar/style.css"
pruefe 'grep -q "font-family: \"Noto Sans\", \"Hack Nerd Font\"" "$st" && grep -q "font-size: 16px" "$st" && grep -q "rgba(42, 42, 47, 0.50)" "$st"' "B: Schrift, Grösse und Deckkraft der Leiste (graues Glas)"
# helles Hintergrundbild: das Glas der Leiste wird so weit dunkler, dass Text lesbar bleibt
mkdir -p "$h/.local/share/hypr-shell"; echo 0.9 > "$h/.local/share/hypr-shell/wallpaper-luma"
apply "$h" --no-reload
pruefe 'grep -qE "background: rgba\(42, 42, 47, 0\.(8|9)[0-9]\)" "$st"' "B: helles Hintergrundbild → Glas automatisch dunkler (Mindestkontrast)"
rm -f "$h/.local/share/hypr-shell/wallpaper-luma"
apply "$h" --no-reload
pruefe 'grep -q "font_family = Oswald" "$h/.config/hypr/hyprlock.conf" && grep -q "font_size = 156" "$h/.config/hypr/hyprlock.conf"' "B: Uhrschrift und Grösse auf dem Sperrbildschirm"
pruefe 'grep -q "icon-theme: *\"Adwaita\"" "$h/.config/rofi/hypr-shell-settings.rasi" && grep -q "Noto Sans 13" "$h/.config/rofi/hypr-shell-settings.rasi" && grep -q "rgba(42, 42, 47, 0.60)" "$h/.config/rofi/hypr-shell-settings.rasi"' "B: Starter mit Symbolthema, Schrift und Glas"
pruefe '[ "$(waybar "$h" ".network.\"on-click\"")" = "\$HOME/.local/bin/shell-quickshell ipc panel page wifi" ] && [ "$(waybar "$h" ".\"custom/distro\".\"on-click\"")" = fuzzel ]' "B: Starter in der Leiste, WLAN öffnet die Unterseite im Panel"

# Beispiel C: Bildschirme
h="$(neues_home c '{"monitors": {"scale": "1.25", "outputs": [{"name": "eDP-1", "resolution": "2560x1600", "refresh": 165, "scale": "1.6"}, {"name": "HDMI-A-1", "position": "2560x0"}]}}')"
apply "$h" --no-reload
pruefe 'jq -e ".monitors.outputs[0].refresh == 165 and .monitors.outputs[1].resolution == \"\" and .monitors.outputs[1].scale == \"\" and .monitors.scale == \"1.25\"" "$h/.local/share/hypr-shell/settings.effective.json" >/dev/null' "C: Bildschirme mit fehlenden Feldern = automatisch"

echo "== 5. falsche Werte und kaputtes JSON"
h="$(neues_home falsch '{"bar": {"height": "abc", "opacity": 0.4}, "look": {"rounding": 99}, "lock": {"after": 7}, "panel": {"corner": "middle"}, "bar_typo": 1}')"
pruefe 'apply "$h" --no-reload 2>"$T/err"' "shell-apply läuft trotz falscher Werte durch"
eff="$h/.local/share/hypr-shell/settings.effective.json"
pruefe 'jq -e ".bar.height == 30 and .look.rounding == 14 and .panel.corner == \"bottom-right\"" "$eff" >/dev/null' "falsche Werte: Standardwert gilt"
pruefe 'jq -e ".bar.opacity == 0.4 and .lock.after == 7" "$eff" >/dev/null && grep -q "timeout = 420" "$h/.config/hypr/hypridle.conf"' "gültige Werte daneben wirken trotzdem"
errs="$h/.local/share/hypr-shell/settings.errors"
pruefe 'grep -q "^bar.height: expected a whole number between 20 and 60" "$errs" && grep -q "^look.rounding: out of range" "$errs" && grep -q "^panel.corner: expected one of" "$errs" && grep -q "^bar_typo: unknown setting" "$errs"' "Meldung nennt Schlüssel und Grund"
pruefe '! apply "$h" --check >/dev/null && { apply "$h" --check || true; } | grep -q "bar.height"' "--check meldet den Fehler mit Rückgabe 1"
vorher="$(cat "$eff")"; lua_vorher="$(cat "$h/.config/hypr/hypr-shell-settings.lua")"
printf '{ "bar": { "height": 40, }\n' > "$h/.config/hypr-shell/settings.json"
pruefe 'apply "$h" --no-reload 2>/dev/null' "kaputtes JSON: shell-apply läuft durch"
pruefe '[ "$vorher" = "$(cat "$eff")" ] && [ "$lua_vorher" = "$(cat "$h/.config/hypr/hypr-shell-settings.lua")" ]' "kaputtes JSON: letzter gültiger Stand bleibt aktiv"
pruefe 'grep -q "not valid JSON" "$errs"' "kaputtes JSON wird gemeldet"
pruefe '! apply "$h" --check >/dev/null' "--check erkennt kaputtes JSON"
printf '[1, 2]\n' > "$h/.config/hypr-shell/settings.json"
pruefe 'apply "$h" --no-reload 2>/dev/null && [ "$vorher" = "$(cat "$eff")" ]' "kein Objekt: letzter gültiger Stand bleibt"
h2="$(neues_home ohne-letzten)"; printf 'kaputt' > "$h2/.config/hypr-shell/settings.json"
pruefe 'apply "$h2" --no-reload 2>/dev/null && jq -e ".bar.height == 30" "$h2/.local/share/hypr-shell/settings.effective.json" >/dev/null' "kaputtes JSON ohne früheren Stand: Standardwerte"
h3="$T/ohne-datei"; mkdir -p "$h3"
pruefe 'apply "$h3" --no-reload && [ -f "$h3/.config/waybar/config.jsonc" ]' "ohne settings.json: Standardwerte"

echo "== 5b. Namen von Schriften, Mauszeiger, Symbolen und Programmen"
h="$(neues_home namen '{}')"
ss() { HOME="$h" "$REPO/bin/shell-set" "$@"; }
for v in 'Inter"' "Inter\\" 'Inter; x' 'Inter{' 'Inter}' '' '   '; do
    pruefe '! ss theme.font.ui "$v" >/dev/null 2>&1 && [ "$(jq -c . "$h/.config/hypr-shell/settings.json")" = "{}" ]' "Schriftname »$v« wird abgelehnt"
done
pruefe '! ss theme.cursor.name "Bibata\"" >/dev/null 2>&1 && ! ss theme.icons "" >/dev/null 2>&1 && ! ss theme.font.display "  " >/dev/null 2>&1' "Mauszeiger, Symbole und Anzeigeschrift ebenso"
pruefe 'ss theme.font.ui "Noto Sans CJK JP" >/dev/null && ss theme.font.mono "JetBrainsMono Nerd Font" >/dev/null && ss theme.cursor.name Bibata-Modern-Ice >/dev/null && ss theme.icons Papirus-Dark >/dev/null && ss theme.font.clock "Font Awesome 6 Free (Solid)" >/dev/null' "übliche Namen bleiben gültig"
for k in terminal files browser launcher; do
    pruefe '! ss "apps.$k" "  " >/dev/null 2>&1' "apps.$k aus Leerzeichen wird abgelehnt"
done
pruefe 'ss apps.terminal "foot -e tmux" >/dev/null && ss apps.launcher "rofi -show drun" >/dev/null' "Befehle mit Leerzeichen bleiben gültig"
# von Hand eingetragen: der Standard gilt, die Leiste bleibt lesbares CSS
h="$(neues_home schrift-hand '{"theme": {"font": {"ui": "Inter\"; } * { color: red; } x {", "mono": "Hack\\"}}}')"
apply "$h" --no-reload 2>/dev/null
pruefe 'grep -q "^  font-family: \"Inter\", \"JetBrainsMono Nerd Font\", sans-serif;" "$h/.config/waybar/style.css" && ! grep -q "color: red" "$h/.config/waybar/style.css"' "von Hand eingetragener kaputter Name: Standardschrift in der Leiste"
pruefe 'grep -q "^theme.font.ui: invalid format" "$h/.local/share/hypr-shell/settings.errors" && grep -q "^theme.font.mono: invalid format" "$h/.local/share/hypr-shell/settings.errors"' "… und gemeldet"
# zweite Sicherung: auch ein Wert, den das Schema durchliesse, bricht nicht aus der CSS-Zeichenkette aus
jq '(.keys[] | select(.key | startswith("theme.font."))) |= del(.pattern)' "$SCHEMA" > "$T/schema-ohne-muster.json"
h="$(neues_home schrift-maskiert '{"theme": {"font": {"ui": "Inter\"; } * { color: red; } x {"}}}')"
HYPR_SHELL_SCHEMA="$T/schema-ohne-muster.json" apply "$h" --no-reload 2>/dev/null
pruefe 'grep -qF "  font-family: \"Inter\\\"; } * { color: red; } x {\", \"JetBrainsMono Nerd Font\", sans-serif;" "$h/.config/waybar/style.css"' "Anführungszeichen werden im CSS maskiert"

echo "== 6. ältere Versionen"
v100='{"weather": {"location": "Zürich", "units": "metric"}, "desktop": {"screen": "", "clock": {"enabled": true, "x": 0.02, "y": 0.045, "scale": 1.0},
  "resources": {"enabled": false, "x": 0.015, "y": 0.56, "scale": 1.0}}, "dashboard": {"width": 1000, "edge": true, "opacity": 0.42},
  "panel": {"enabled": true, "corner": "top-left", "trigger": 6, "width": 420, "radius": 26, "opacity": 0.44,
  "sections": ["awake", "apps", "media", "shot", "toggles"], "apps": ["kitty", "firefox"], "toggles": ["wifi", "bluetooth", "dnd", "gaming", "settings"]}}'
h="$(neues_home v100 "$v100")"
pruefe 'apply "$h" --check' "settings.json von v1.0.0 ist ohne Fehler"
apply "$h" --no-reload
pruefe 'jq -e ".panel.corner == \"top-left\" and .desktop.resources.enabled == false and .weather.location == \"Zürich\" and .bar.height == 30" "$h/.local/share/hypr-shell/settings.effective.json" >/dev/null' "v1.0.0: eigene Werte bleiben, neue Werte mit Standard"
# hypr-shell-local.lua (v1.1) -> settings.json, einmalig
h="$(neues_home umzug '{"weather": {"location": "Bern"}, "input": {"variant": "fr"}}')"
mkdir -p "$h/.config/hypr"
printf 'return {\n    kb_layout      = "ch",   -- Tastaturlayout\n    kb_variant     = "de",\n    scale          = 1.5,\n    natural_scroll = true,\n    tap_to_click   = false,\n}\n' > "$h/.config/hypr/hypr-shell-local.lua"
apply "$h" --no-reload --no-migrate
pruefe '[ "$(jq -c . "$h/.config/hypr-shell/settings.json")" = "{\"weather\":{\"location\":\"Bern\"},\"input\":{\"variant\":\"fr\"}}" ]' "--no-migrate (Installer) ändert settings.json nicht"
pruefe 'jq -e ".input.layout == \"ch\" and .input.variant == \"fr\" and .monitors.scale == \"1.5\"" "$h/.local/share/hypr-shell/settings.effective.json" >/dev/null' "Werte aus hypr-shell-local.lua gelten trotzdem (settings.json gewinnt)"
apply "$h" --no-reload
s="$h/.config/hypr-shell/settings.json"
pruefe 'jq -e ".input.layout == \"ch\" and .input.variant == \"fr\" and .input.touchpad.natural_scroll == true and .input.touchpad.tap_to_click == false and .monitors.scale == \"1.5\" and .weather.location == \"Bern\"" "$s" >/dev/null' "Umzug: fehlende Werte stehen jetzt in settings.json, eigene bleiben"
jq '.input.layout = "de"' "$s" > "$s.neu" && mv "$s.neu" "$s"
apply "$h" --no-reload
pruefe '[ "$(jq -r .input.layout "$s")" = de ] && [ -f "$h/.local/share/hypr-shell/local-migrated" ]' "Umzug nur einmal"

exit "$fehler"
