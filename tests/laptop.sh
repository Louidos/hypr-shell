#!/usr/bin/env bash
# Prüft die Laptop-Funktionen (shell-laptop) mit Attrappen für asusctl (6.3+ und bis 6.2), supergfxctl
# und /sys: Profilwechsel im Panel landet bei asusctl, Ladegrenze und Tastaturlicht aus den
# Einstellungen, Ladegrenze zurück auf 100 (nur wenn hypr-shell sie gesetzt hat), Grafik-Modus nur
# bekannte Modi, ohne asusctl erscheint nichts davon.
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
EFF="$HOME/.local/share/hypr-shell/settings.effective.json" MARKE="$HOME/.local/share/hypr-shell/charge-limit-set"
AKKU="$T/sys/class/power_supply/BAT0/charge_control_end_threshold"
einstellung() { echo "$1" > "$EFF"; : > "$ASUS_STATE/log"; }   # neue Einstellungen, leeres asusctl-Protokoll
geschrieben() { grep -qE "^(battery limit|-c) " "$ASUS_STATE/log"; }
einstellung '{"laptop": {"charge_limit": 80, "kbd_light": "low", "kbd_follow_wallpaper": true}}'
mkdir -p "$HOME/.config/hypr-shell"; echo '{"accent": "#8ab4f8"}' > "$HOME/.config/hypr-shell/colors.json"
lap apply
pruefe '[ "$(cat "$ASUS_STATE/charge")" = 80 ] && grep -qx "battery limit 80" "$ASUS_STATE/log"' "Ladegrenze 80 % über asusctl battery limit (asusd behält sie über Neustarts)"
pruefe '[ -f "$MARKE" ]' "… und gemerkt, dass hypr-shell die Grenze gesetzt hat"
pruefe '[ "$(cat "$ASUS_STATE/kbd")" = low ] && [ "$(cat "$ASUS_STATE/color")" = 8ab4f8 ]' "Tastaturlicht und Farbe aus dem Hintergrundbild"
pruefe 'grep -q "shell-laptop apply" config/hypr/hyprland.lua' "beim Anmelden erneut angewendet"

echo "== Ladegrenze zurück auf 100"
einstellung '{"laptop": {"charge_limit": 100}}'
lap apply
pruefe 'grep -qx "battery limit 100" "$ASUS_STATE/log" && [ "$(cat "$ASUS_STATE/charge")" = 100 ] && [ "$(cat "$AKKU")" = 100 ]' "80 → 100 in den Einstellungen: asusctl battery limit 100"
pruefe '[ ! -e "$MARKE" ]' "… und der Merker ist weg"
einstellung '{"laptop": {"charge_limit": 100}}'
lap apply
pruefe '! geschrieben' "nochmal angewendet: kein weiterer Schreibzugriff"
einstellung '{"laptop": {"charge_limit": 80}}'; lap apply
einstellung '{}'
lap apply
pruefe 'grep -qx "battery limit 100" "$ASUS_STATE/log" && [ "$(cat "$AKKU")" = 100 ] && [ ! -e "$MARKE" ]' "Reset (Schlüssel fehlt in settings.json): ebenfalls zurück auf 100"

echo "== Ladegrenze direkt mit asusctl gesetzt"
echo 80 > "$AKKU"   # z. B. asusctl battery limit 80 von Hand, hypr-shell nie dafür benutzt
einstellung '{}'
lap apply
pruefe '[ ! -s "$ASUS_STATE/log" ] || ! grep -qE "battery|leds|aura" "$ASUS_STATE/log"' "Standard: nichts wird verändert"
pruefe '[ ! -e "$MARKE" ] && [ "$(cat "$AKKU")" = 80 ]' "ohne Merker bleibt die mit asusctl gesetzte Grenze (80 %) beim Anmelden"
einstellung '{"laptop": {"charge_limit": 80}}'
lap apply
pruefe '! geschrieben && [ -f "$MARKE" ]' "Einstellung 80 bei schon gesetzten 80 %: nichts geschrieben, aber gemerkt"
einstellung '{"laptop": {"charge_limit": 100}}'
lap apply
pruefe 'grep -qx "battery limit 100" "$ASUS_STATE/log" && [ "$(cat "$AKKU")" = 100 ]' "… danach 100 in den Einstellungen wirkt auch hier"
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
einstellung '{"laptop": {"charge_limit": 60}}'
ASUS_ALT=1 lap apply
pruefe '[ "$(cat "$ASUS_STATE/charge")" = 60 ]' "alte Schreibweise -c"
einstellung '{}'
ASUS_ALT=1 lap apply
pruefe 'grep -qx -- "-c 100" "$ASUS_STATE/log" && [ "$(cat "$AKKU")" = 100 ] && [ ! -e "$MARKE" ]' "alte Schreibweise: zurück auf 100 mit -c 100"
einstellung '{}'
ASUS_ALT=1 lap apply
pruefe '! geschrieben' "… danach kein weiterer Schreibzugriff"

echo "== ohne asusctl"
pruefe '[ "$(PATH="/usr/bin:/bin" HYPR_SHELL_SYSFS="$T/leer" "$REPO/bin/shell-laptop" caps | jq -c "[.laptop, .asusctl, .charge, .kbd, .gfx]")" = "[false,false,false,false,false]" ]' "nichts davon erscheint"
for befehl in "charge set 80" "kbd set low" "kbd color #8ab4f8"; do
    # shellcheck disable=SC2086
    rc=0; out="$(PATH="/usr/bin:/bin" HYPR_SHELL_SYSFS="$T/leer" "$REPO/bin/shell-laptop" $befehl 2>&1)" || rc=$?
    pruefe '[ "$rc" != 0 ] && grep -q "needs asusctl" <<<"$out" && ! grep -q "command not found" <<<"$out"' "$befehl ohne asusctl: klare Meldung ($out)"
done

echo "== Randfälle"
mkdir -p "$T/ppd-leer" "$T/gfx-zitat"
# powerprofilesctl, dessen "list" nichts Lesbares liefert (z. B. eine geänderte Ausgabe)
printf '#!/bin/sh\ncase "$1" in get) echo balanced ;; list) echo ;; set) echo "$2" > "%s/ppd-gesetzt" ;; esac\n' "$T" > "$T/ppd-leer/powerprofilesctl"
# supergfxctl mit Anführungszeichen und Backslash in der Ausgabe
printf '#!/bin/sh\ncase "$1" in -g) echo '"'"'Hybrid "neu" \\ x'"'"' ;; -s) echo "[Integrated, Hybrid]" ;; -p) echo '"'"'Logout "now"'"'"' ;; esac\n' > "$T/gfx-zitat/supergfxctl"
chmod +x "$T/ppd-leer/powerprofilesctl" "$T/gfx-zitat/supergfxctl"
rc=0; out="$(PATH="$T/ppd-leer:/usr/bin:/bin" HYPR_SHELL_SYSFS="$T/leer" "$REPO/bin/shell-laptop" profile next 2>&1)" || rc=$?
pruefe '[ "$rc" != 0 ] && [ ! -e "$T/ppd-gesetzt" ] && ! grep -q "jq:" <<<"$out" && grep -q "no power profiles" <<<"$out"' "profile next ohne lesbare Profile: Meldung, nichts gesetzt ($out)"
st="$(PATH="$T/gfx-zitat:/usr/bin:/bin" HYPR_SHELL_SYSFS="$T/leer" "$REPO/bin/shell-laptop" status 2>&1)" || true
pruefe '[ "$(jq -r .gfx <<<"$st" 2>/dev/null)" = "Hybrid \"neu\" \\ x" ] && [ "$(jq -r .gfx_pending <<<"$st")" = "Logout \"now\"" ]' "status mit Anführungszeichen von supergfxctl bleibt gültiges JSON ($st)"
exit "$fehler"
