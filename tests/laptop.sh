#!/usr/bin/env bash
# Prüft die Laptop-Funktionen (shell-laptop) mit Attrappen für asusctl (6.3+ und bis 6.2), supergfxctl
# und /sys: Profilwechsel im Panel landet bei asusctl, Ladegrenze und Tastaturlicht aus den
# Einstellungen, Grafik-Modus nur bekannte Modi, ohne asusctl erscheint nichts davon.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" ASUS_STATE="$T/asus" HYPR_SHELL_SYSFS="$T/sys"
mkdir -p "$HOME/.local/share/hypr-shell" "$T/bin" "$T/sys/class/power_supply/BAT0" "$T/sys/class/leds/asus::kbd_backlight"
echo 100 > "$T/sys/class/power_supply/BAT0/charge_control_end_threshold"
for p in asusctl supergfxctl; do ln -s "$REPO/tests/daten/$p" "$T/bin/$p"; done
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
lap() { PATH="$T/bin:$PATH" "$REPO/bin/shell-laptop" "$@"; }
tg() { PATH="$T/bin:$PATH" "$REPO/bin/shell-toggle" "$@"; }

echo "== Fähigkeiten"
pruefe '[ "$(lap caps)" = "{\"laptop\":true,\"asusctl\":true,\"profile\":true,\"gfx\":true,\"charge\":true,\"kbd\":true,\"aura\":true}" ]' "ROG-Laptop: alles da"

echo "== Leistungsprofil (asusctl 6.3+)"
tg profile next
pruefe '[ "$(cat "$ASUS_STATE/profile")" = Performance ] && [ "$(tg status | jq -r .profile)" = performance ]' "Profilwechsel im Panel = asusctl (Balanced → Performance)"
tg profile next
pruefe '[ "$(cat "$ASUS_STATE/profile")" = Quiet ] && [ "$(PATH="$T/bin:$PATH" asusctl profile get | head -n1)" = "Active profile: Quiet" ]' "… → Quiet, asusctl profile get stimmt überein"

echo "== Ladegrenze und Tastaturlicht aus den Einstellungen"
echo '{"laptop": {"charge_limit": 80, "kbd_light": "low", "kbd_follow_wallpaper": true}}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
mkdir -p "$HOME/.config/hypr-shell"; echo '{"accent": "#8ab4f8"}' > "$HOME/.config/hypr-shell/colors.json"
lap apply
pruefe '[ "$(cat "$ASUS_STATE/charge")" = 80 ] && grep -qx "battery limit 80" "$ASUS_STATE/log"' "Ladegrenze 80 % über asusctl battery limit (asusd behält sie über Neustarts)"
pruefe '[ "$(cat "$ASUS_STATE/kbd")" = low ] && [ "$(cat "$ASUS_STATE/color")" = 8ab4f8 ]' "Tastaturlicht und Farbe aus dem Hintergrundbild"
pruefe 'grep -q "shell-laptop apply" config/hypr/hyprland.lua' "beim Anmelden erneut angewendet"
echo '{}' > "$HOME/.local/share/hypr-shell/settings.effective.json"; : > "$ASUS_STATE/log"
lap apply
pruefe '[ ! -s "$ASUS_STATE/log" ] || ! grep -qE "battery|leds|aura" "$ASUS_STATE/log"' "Standard: nichts wird verändert"
pruefe '! lap charge set 10 2>/dev/null && ! lap kbd set grell 2>/dev/null' "ungültige Werte werden abgelehnt"

echo "== Grafik-Modus"
pruefe '[ "$(lap gfx list)" = "[\"Integrated\",\"Hybrid\",\"AsusMuxDgpu\"]" ] && [ "$(lap gfx get)" = Hybrid ]' "Modi und aktueller Modus"
pruefe '! lap gfx set Erfunden 2>/dev/null' "unbekannter Modus wird abgelehnt"
lap gfx set Integrated >/dev/null
pruefe '[ "$(lap status | jq -r ".gfx, .gfx_pending" | tr "\n" "|")" = "Integrated|Logout required to complete mode change|" ]' "Modus gewechselt, Hinweis auf Abmelden"

echo "== asusctl bis 6.2"
rm -f "$ASUS_STATE/profile"
ASUS_ALT=1 tg profile performance
pruefe '[ "$(cat "$ASUS_STATE/profile")" = Performance ] && [ "$(ASUS_ALT=1 lap profile get)" = performance ]' "alte Schreibweise profile -P / -p"
echo '{"laptop": {"charge_limit": 60}}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
ASUS_ALT=1 lap apply
pruefe '[ "$(cat "$ASUS_STATE/charge")" = 60 ]' "alte Schreibweise -c"

echo "== ohne asusctl"
pruefe '[ "$(PATH="/usr/bin:/bin" HYPR_SHELL_SYSFS="$T/leer" "$REPO/bin/shell-laptop" caps | jq -c "[.laptop, .asusctl, .charge, .kbd, .gfx]")" = "[false,false,false,false,false]" ]' "nichts davon erscheint"
exit "$fehler"
