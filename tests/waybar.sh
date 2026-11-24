#!/usr/bin/env bash
# Prüft die Waybar-Konfiguration: gültiges JSON(C), alle Module aus dem Auftrag,
# Arbeitsflächen 1–4, aufgerufene Skripte existieren, Farben kommen von matugen.
# shellcheck disable=SC2016,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

cfg="$(sed -E 's#^[[:space:]]*//.*$##' config/waybar/config.jsonc)"
jq empty <<<"$cfg" || { echo "FEHLER: config.jsonc ist kein gültiges JSON"; exit 1; }

fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
j() { jq -r "$1" <<<"$cfg"; }

pruefe '[ "$(j .position)" = top ]' "Leiste oben"
pruefe '[ "$(j ".\"modules-left\" | join(\",\")")" = "custom/distro,hyprland/workspaces,mpris" ]' "links: Distro, Arbeitsflächen, Lied"
pruefe '[ "$(j ".\"modules-center\" | length")" = 0 ]' "Mitte leer"
pruefe '[ "$(j ".\"modules-right\" | join(\",\")")" = "pulseaudio,battery,clock,bluetooth,network,custom/recording,custom/notifications,custom/missa,custom/power" ]' "rechts: Lautstärke, Akku, Uhr, Bluetooth, WLAN, Aufnahme, Glocke, Missa (nur verbunden sichtbar), Ausschalten"
pruefe '[ "$(j ".battery.states.critical")" = 14 ] && grep -q "#battery.critical" config/waybar/style.css' "Akku: Warnfarbe unter 15 %"
pruefe 'j ".battery.format" | grep -q "{capacity}%" && j ".battery.\"format-charging\"" | grep -q "{capacity}%" && [ "$(j ".battery.\"format-icons\" | length")" -ge 5 ]' "Akku: Symbol und Prozent, Ladesymbol am Netz"
pruefe '[ "$(j ".\"hyprland/workspaces\".\"persistent-workspaces\".\"*\" | join(\",\")")" = "1,2,3,4" ]' "Arbeitsflächen 1–4"
pruefe '[ "$(j .clock.format)" = "{:%H:%M}" ]' "Uhr HH:MM"
pruefe 'j ".pulseaudio.format" | grep -q "{volume}%"' "Lautstärke in Prozent"
pruefe 'j ".\"custom/distro\".\"on-click\"" | grep -q "ipc launcher toggle"' "Distro-Symbol öffnet den Starter"

# alle aufgerufenen Skripte aus ~/.local/bin müssen im Repo liegen
while IFS= read -r s; do
    pruefe '[ -x "bin/$s" ]' "Skript vorhanden: $s"
done < <(grep -oE '\.local/bin/[a-z-]+' config/waybar/config.jsonc | sed 's#.*/##' | sort -u)

pruefe 'grep -q "@import \"colors.css\"" config/waybar/style.css' "Farben aus colors.css"
pruefe 'grep -q "waybar/colors.css" config/matugen/config.toml' "matugen erzeugt colors.css für Waybar"
pruefe 'grep -qE "rgba\(10, 10, 12, 0\.25\)" config/waybar/style.css' "Deckkraft etwa 0.25"

# jede @farbe in style.css muss in colors.css definiert sein
for c in $(grep -oE '@[a-z_]+' config/waybar/style.css | grep -vE '@(import|keyframes)' | sort -u | tr -d @); do
    pruefe 'grep -q "@define-color $c " config/waybar/colors.css && grep -q "@define-color $c " config/matugen/templates/colors.css' "Farbe @$c definiert"
done

# Schrift passt in die Leiste: niedrige Leiste mit grosser Schrift → kleinere Schrift, Standard unverändert
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
schrift() {
    local h="$T/h$1"
    mkdir -p "$h/.config/hypr-shell"
    printf '{"bar": {"height": %s}, "theme": {"font": {"scale": %s}}}\n' "$1" "$2" > "$h/.config/hypr-shell/settings.json"
    HOME="$h" KEINE_MELDUNG=1 bin/shell-apply --no-reload >/dev/null 2>&1
    grep -m1 -oE 'font-size: [0-9]+px' "$h/.config/waybar/style.css" | grep -oE '[0-9]+'
}
pruefe '[ "$(schrift 30 1.0)" = 13 ] && [ "$(schrift 40 1.5)" = 20 ]' "Schrift der Leiste: Standard 13 px, mit Faktor 1.5 bei 40 px Höhe 20 px"
pruefe '[ "$(schrift 20 1.5)" -le 11 ] && [ "$(schrift 24 1.0)" -le 13 ]' "niedrige Leiste (20 px, Faktor 1.5): Schrift höchstens 11 px statt 20 px"

# Statusskripte geben gültiges JSON aus
pruefe 'bin/shell-recording status | jq -e .text >/dev/null' "shell-recording liefert JSON"

exit "$fehler"
