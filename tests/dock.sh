#!/usr/bin/env bash
# Prüft die Dock-Werte ohne Oberfläche: Schema (Standard und Grenzen), Voreinstellungen (nur
# dock.*-Werte, nie dock.items), Export → Reset all → Import (genau derselbe Stand), kaputte
# Dateien werden abgelehnt, Zahlen ausserhalb des Bereichs begrenzt, shell-set für jeden Wert.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
unset XDG_CONFIG_HOME HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/hypr-shell" "$HOME/.config/hypr-shell"
for b in "$REPO"/bin/*; do ln -s "$b" "$HOME/.local/bin/"; done
cp "$REPO/settings/schema.json" "$HOME/.local/share/hypr-shell/schema.json"
echo '{}' > "$HOME/.config/hypr-shell/settings.json"
export KEINE_MELDUNG=1
S="$REPO/settings/schema.json"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
eff() { jq -c "$1" "$HOME/.local/share/hypr-shell/settings.effective.json"; }
set_() { "$HOME/.local/bin/shell-set" "$@" >/dev/null 2>&1; }
"$HOME/.local/bin/shell-apply" --no-reload >/dev/null 2>&1

echo "== Schema"
tabelle="enabled position monitor running_per_monitor mode layer margin icon_size icon_min_size padding spacing radius max_length glass_opacity blur border_width border_color shadow color_mode custom_color icon_style labels indicator indicator_color show_running badges previews magnify magnify_factor magnify_range anim_ms bounce_on_launch autohide show_delay_ms hide_delay_ms hide_on_fullscreen avoid_bar launcher_button trash items preset"
fehlt=""
for k in $tabelle; do jq -e --arg k "dock.$k" 'any(.keys[]; .key == $k)' "$S" >/dev/null || fehlt="$fehlt $k"; done
pruefe '[ -z "$fehlt" ]' "jeder Wert aus der Tabelle steht im Schema (${fehlt:-alle})"
ohne="$(jq -r '.keys[] | select(.key | startswith("dock.")) | select(.default == null or .title == null or .description == null) | .key' "$S")"
pruefe '[ -z "$ohne" ]' "jeder dock.*-Wert hat Standard, Titel und Erklärung"
zahl="$(jq -r '.keys[] | select(.key | startswith("dock.")) | select(.type == "int" or .type == "number") | select(.min == null or .max == null or .step == null or .clamp != true) | .key' "$S")"
pruefe '[ -z "$zahl" ]' "jede Dock-Zahl hat Grenzen und wird begrenzt"
pruefe '[ "$(jq -r ".keys[] | select(.key == \"dock.icon_size\") | .default" "$S")" = 48 ] && [ "$(jq -c ".dock.items | map(.type)" "$REPO/settings/settings.example.json")" = "[\"app\",\"app\",\"app\",\"separator\",\"folder\",\"separator\",\"trash\"]" ]' "Standardwerte und Standardliste"

echo "== Voreinstellungen"
for f in "$REPO"/settings/presets/dock/*.json; do
    n="$(basename "$f" .json)"
    pruefe 'jq -e "type == \"object\" and ._name == \"$n\" and (._description | type) == \"string\"" "$f" >/dev/null' "$n: gültig"
    pruefe '[ -z "$(jq -r "keys[] | select(startswith(\"_\") | not) | select(startswith(\"dock.\") | not or . == \"dock.items\" or . == \"dock.preset\")" "$f")" ]' "$n: nur dock.*-Werte, nie dock.items"
    jq '[to_entries[] | select(.key | startswith("dock.")) | {key: (.key | ltrimstr("dock.")), value}] | from_entries | {dock: .}' "$f" > "$T/p.json"
    pruefe '"$HOME/.local/bin/shell-apply" --check "$T/p.json" >/dev/null 2>&1' "$n: alle Werte gültig"
done
set_ dock.items '[{"type":"app","desktop_id":"kitty","path":""}]'
items="$(eff .dock.items)"
"$HOME/.local/bin/shell-dock" preset minimal >/dev/null 2>&1
pruefe '[ "$(eff "[.dock.icon_size, .dock.magnify, .dock.autohide, .dock.indicator, .dock.shadow, .dock.preset]")" = "[36,false,\"always\",\"line\",\"soft\",\"minimal\"]" ]' "minimal: 36 px, ohne Vergrösserung, versteckt, Linie, schwacher Schatten"
pruefe '[ "$(eff .dock.items)" = "$items" ]' "minimal lässt dock.items in Ruhe"
pruefe '[ "$(jq "[paths | select(.[0] != \"dock\")] | length" "$HOME/.config/hypr-shell/settings.json")" = 0 ]' "nur dock.*-Werte geändert"
"$HOME/.local/bin/shell-dock" preset island >/dev/null 2>&1
pruefe '[ "$(eff "[.dock.icon_size, .dock.radius, .dock.spacing, .dock.shadow, .dock.magnify, .dock.autohide]")" = "[56,100,16,\"strong\",true,\"smart\"]" ]' "island setzt die übrigen Werte auf den Standard zurück"
"$HOME/.local/bin/shell-dock" preset full >/dev/null 2>&1
pruefe '[ "$(eff "[.dock.max_length, .dock.margin, .dock.radius, .dock.mode]")" = "[100,0,0,\"reserve\"]" ]' "full: ganze Breite, kein Abstand, reserviert Platz"
"$HOME/.local/bin/shell-dock" preset compact >/dev/null 2>&1
pruefe '[ "$(eff "[.dock.icon_size, .dock.spacing, .dock.radius, .dock.labels]")" = "[40,4,14,\"never\"]" ]' "compact: 40 px, Abstand 4, Rundung 14, ohne Namen"
"$HOME/.local/bin/shell-dock" preset mac >/dev/null 2>&1
pruefe '[ "$(eff "[.dock.icon_size, .dock.preset, .dock.radius]")" = "[48,\"mac\",22]" ] && [ "$(eff .dock.items)" = "$items" ]' "mac: Werte wie in der Tabelle"
pruefe '! "$HOME/.local/bin/shell-dock" preset "../x" >/dev/null 2>&1' "unbekannte Voreinstellung wird abgelehnt"

echo "== shell-set und Grenzen"
set_ dock.icon_size 64
pruefe '[ "$("$HOME/.local/bin/shell-set" get dock.icon_size)" = 64 ] && [ "$(eff .dock.icon_size)" = 64 ]' "shell-set dock.icon_size 64"
jq '.dock.icon_size = 500 | .dock.margin = -3' "$HOME/.config/hypr-shell/settings.json" > "$T/s" && cp "$T/s" "$HOME/.config/hypr-shell/settings.json"
"$HOME/.local/bin/shell-apply" --no-reload > "$T/apply.log" 2>&1 || true
pruefe '[ "$(eff "[.dock.icon_size, .dock.margin]")" = "[128,0]" ] && grep -q "using 128 instead" "$T/apply.log"' "ausserhalb des Bereichs: auf die Grenze gesetzt, mit Hinweis"
set_ dock.icon_size 64; set_ dock.margin 10
fehlschlag=""
while IFS=$'\t' read -r k v; do
    "$HOME/.local/bin/shell-set" "$k" "$v" >/dev/null 2>&1 || fehlschlag="$fehlschlag $k"
done < <(jq -r '.keys[] | select(.key | startswith("dock.")) | [.key, (.default | if type == "string" then . else tojson end)] | @tsv' "$S")
pruefe '[ -z "$fehlschlag" ]' "shell-set funktioniert für jeden dock.*-Wert (${fehlschlag:-alle})"
set_ dock.icon_size 64

echo "== Export, Reset all, Import"
set_ set dock.spacing 9 dock.shadow strong dock.items '[{"type":"app","desktop_id":"firefox","path":""},{"type":"trash","desktop_id":"","path":""}]'
vorher="$(eff .dock)"
"$HOME/.local/bin/shell-dock" export "$T/dock.json" >/dev/null
pruefe '[ "$(jq -c "keys" "$T/dock.json")" = "[\"dock\"]" ] && [ "$(jq -c .dock "$T/dock.json")" = "$vorher" ]' "Export: nur dock.* (mit dock.items)"
"$HOME/.local/bin/shell-dock" reset >/dev/null 2>&1
pruefe '[ "$(eff .dock.icon_size)" = 48 ] && [ "$(eff ".dock.items | length")" = 7 ]' "Reset all: Standard"
"$HOME/.local/bin/shell-dock" import "$T/dock.json" >/dev/null 2>&1
pruefe '[ "$(eff .dock)" = "$vorher" ]' "Import: genau derselbe Stand"
stand="$(cat "$HOME/.config/hypr-shell/settings.json")"
echo '{"dock": ' > "$T/kaputt1.json"
echo '{"dock": {"icon_size": 64, "nicht_da": 1}}' > "$T/kaputt2.json"
echo '{"dock": {"icon_size": 64, "position": "middle"}}' > "$T/kaputt3.json"
echo '{"look": {"rounding": 3}}' > "$T/kaputt4.json"
for i in 1 2 3 4; do
    pruefe '! "$HOME/.local/bin/shell-dock" import "$T/kaputt$i.json" >/dev/null 2>&1 && [ "$(cat "$HOME/.config/hypr-shell/settings.json")" = "$stand" ]' "kaputte Datei $i abgelehnt, nichts halb übernommen"
done
exit "$fehler"
