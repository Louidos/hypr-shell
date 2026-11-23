#!/usr/bin/env bash
# Prüft Sperrbildschirm und automatisches Sperren (ohne den Bildschirm zu sperren):
# hypridle-Zeiten, Keep Awake wird beachtet, hyprlock-Aufbau und Farben aus matugen.
# shellcheck disable=SC2016,SC2034,SC2013
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
idle=config/hypr/hypridle.conf
lock=config/hypr/hyprlock.conf

echo "== hypridle"
pruefe 'grep -A2 "^listener" $idle | grep -q "timeout = 300" && grep -A3 "timeout = 300" $idle | grep -q "lock-session"' "nach 5 Minuten sperren"
pruefe 'grep -A3 "timeout = 900" $idle | grep -q "systemctl suspend"' "nach 15 Minuten Standby"
pruefe 'grep -q "before_sleep_cmd = loginctl lock-session" $idle' "vor dem Standby sperren"
pruefe 'grep -q "lock_cmd = pidof hyprlock || hyprlock" $idle' "nur ein hyprlock gleichzeitig"
pruefe 'grep -q "ignore_systemd_inhibit = false" $idle && grep -q "systemd-inhibit --what=idle:sleep" bin/shell-toggle' "Keep Awake (systemd-inhibit) setzt das Sperren aus"

echo "== hyprlock"
pruefe 'grep -q "path = screenshot" $lock && grep -q "brightness = 0.5" $lock && grep -qE "blur_passes = [1-9]" $lock' "Hintergrund: Bildschirm, unscharf, 50 % dunkler"
pruefe 'grep -q "path = ~/.face" $lock' "Profilbild"
pruefe 'grep -q "path = ~/.local/share/hypr-shell/face.png" $lock && [ "$(grep -n "face.png" $lock | head -n1 | cut -d: -f1)" -lt "$(grep -n "path = ~/.face" $lock | cut -d: -f1)" ]' "Ersatzbild unter ~/.face (Anfangsbuchstabe, wenn ~/.face fehlt)"
pruefe '[ "$(grep -c "font_family = Bebas Neue" $lock)" -ge 2 ] && grep -q "date +%H" $lock && grep -q "date +%M" $lock' "grosse gestapelte Uhr, 24 h"
pruefe 'grep -q "shell-greeting" $lock && [ -x bin/shell-greeting ]' "Begrüssung"
pruefe '[ "$(grep -n "path = ~/.face" $lock | cut -d: -f1)" -lt "$(grep -n "date +%H" $lock | cut -d: -f1)" ] && [ "$(grep -A8 "path = ~/.face" $lock | grep -oE "position = [0-9]+, [0-9]+" | grep -oE "[0-9]+$")" -gt "$(grep -A6 "date +%H" $lock | grep -oE "position = [0-9]+, [0-9]+" | grep -oE "[0-9]+$")" ]' "Profilbild über der Uhr"
pruefe 'grep -B2 -A6 "shell-sysinfo lock" $lock | grep -q "valign = bottom" && bin/shell-sysinfo lock | grep -qE "CPU [0-9]+%.*RAM [0-9]+%"' "unten links CPU und RAM ($(bin/shell-sysinfo lock))"
pruefe 'grep -q "^input-field" $lock && grep -q "outline_thickness = 0" $lock && grep -q "^shape" $lock' "Passwortfeld als schlichte Linie"
pruefe 'grep -q "onclick = systemctl suspend" $lock && grep -q "onclick = systemctl reboot" $lock && grep -q "onclick = systemctl poweroff" $lock' "Standby, Neustart, Herunterfahren"
pruefe 'grep -q "halign = left" $lock && ! grep -qE "halign = (right|center)" $lock' "Inhalt links"
pruefe 'grep -q "source = ~/.config/hypr/hyprlock-colors.conf" $lock && grep -q "hyprlock-colors.conf" config/matugen/config.toml' "Farben aus matugen"
for v in $(grep -oE '\$[a-z_]+' $lock | sort -u | grep -vE '^\$(FAIL|USER|TIME|ATTEMPTS|LAYOUT)$'); do
    pruefe 'grep -q "^\\$v = " $lock && grep -q "^\\$v = " config/matugen/templates/hyprlock-colors.conf && grep -q "^\\$v = " config/hypr/hyprlock-colors.conf' "Farbe $v überall definiert"
done
g="$(bin/shell-greeting)"
pruefe '[[ "$g" =~ ^Good\ (morning|afternoon|evening|night),\  ]]' "shell-greeting: $g"
pruefe 'grep -q "pidof hyprlock || hyprlock" config/hypr/hyprland.lua' "SUPER+L sperrt"

exit "$fehler"
