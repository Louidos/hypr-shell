#!/usr/bin/env bash
# Prüft die Unterseiten und neuen Schalter des Panels ohne Bildschirm, mit Attrappen (tests/daten):
# WLAN-Liste (stärkstes je Netz, verbundenes zuerst), verbinden mit Passwort über stdin (nicht in der
# Befehlszeile von shell-net), Fehler verständlich; Bluetooth-Geräte mit Akku, koppeln; ohne Adapter
# fehlt der Schalter (null); Leistungsprofil schaltet weiter; Nachtlicht mit hyprsunset.
# shellcheck disable=SC2016,SC2034
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'pkill -f "$T/bin/hyprsunset" 2>/dev/null || true; rm -rf "$T"' EXIT
export HOME="$T/home" NMCLI_LOG="$T/nmcli.log" BT_LOG="$T/bt.log" PPD_STATE="$T/ppd" HYPRSUNSET_LOG="$T/sunset.log"
mkdir -p "$HOME/.local/share/hypr-shell" "$T/bin" "$T/sys/class/bluetooth/hci0"
for p in nmcli bluetoothctl powerprofilesctl hyprsunset; do ln -s "$REPO/tests/daten/$p" "$T/bin/$p"; done
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
net() { PATH="$T/bin:$PATH" HYPR_SHELL_SYSFS="$T/sys" "$REPO/bin/shell-net" "$@"; }
tg() { PATH="$T/bin:$PATH" HYPR_SHELL_SYSFS="$T/sys" "$REPO/bin/shell-toggle" "$@"; }

echo "== WLAN"
w="$(net wifi list)"
pruefe '[ "$(jq -r "map(.ssid) | join(\",\")" <<<"$w")" = "Heimnetz,Café: Gäste,Nachbar" ]' "Netze: verbundenes zuerst, jedes nur einmal, Doppelpunkt im Namen bleibt"
pruefe '[ "$(jq -c ".[0] | [.active, .signal, .secure]" <<<"$w")" = "[true,82,true]" ] && [ "$(jq ".[1].secure" <<<"$w")" = false ]' "Stärke und Schutz je Netz"
pruefe 'echo "geheim123" | net wifi connect Nachbar | jq -e .ok >/dev/null && grep -q "device wifi connect Nachbar password geheim123" "$T/nmcli.log"' "verbinden mit Passwort aus dem Passwortfeld (stdin)"
pruefe 'net wifi connect "Café: Gäste" </dev/null | jq -e .ok >/dev/null && grep -qx "device wifi connect Café: Gäste" "$T/nmcli.log"' "offenes Netz ohne Passwort"
r="$(echo falsch | net wifi connect Heimnetz || true)"
pruefe 'jq -e ".ok == false and (.error | test(\"Secrets were required\"))" <<<"$r" >/dev/null' "falsches Passwort: verständliche Meldung ($(jq -r .error <<<"$r"))"
pruefe 'net wifi disconnect | jq -e .ok >/dev/null && grep -qx "device disconnect wlan0" "$T/nmcli.log"' "trennen"
pruefe '! grep -q "password" "$REPO/quickshell/panel/WifiPage.qml" || grep -q "stdinText" "$REPO/quickshell/panel/WifiPage.qml"' "Panel gibt das Passwort über stdin weiter"

echo "== Bluetooth"
b="$(net bt list)"
pruefe '[ "$(jq -c "map([.name, .paired, .connected, .battery])" <<<"$b")" = "[[\"Kopfhörer\",true,true,85],[\"Maus\",true,false,null],[\"Lautsprecher\",false,false,null]]" ]' "verbundene, gekoppelte und neue Geräte mit Akkustand"
pruefe 'net bt pair AA:BB:CC:DD:EE:03 | jq -e .ok >/dev/null && grep -q "pair AA:BB:CC:DD:EE:03" "$T/bt.log" && grep -q "connect AA:BB:CC:DD:EE:03" "$T/bt.log"' "koppeln (und verbinden)"
pruefe '! net bt connect "AA:BB; rm -rf /" >/dev/null' "ungültige Adresse wird abgelehnt"
pruefe '[ "$(tg status | jq .bluetooth)" = true ]' "mit Adapter: Bluetooth-Schalter da"
rm -rf "$T/sys/class/bluetooth/hci0"
pruefe '[ "$(tg status | jq .bluetooth)" = null ] && [ "$(net bt list)" = "[]" ]' "ohne Adapter: Schalter fehlt (null), kein Fehler"

echo "== Leistungsprofil"
pruefe '[ "$(tg status | jq -r .profile)" = balanced ]' "aktuelles Profil"
tg profile next
pruefe '[ "$(cat "$PPD_STATE")" = performance ]' "ein Klick schaltet weiter: balanced → performance"
tg profile next
pruefe '[ "$(cat "$PPD_STATE")" = power-saver ]' "… → power-saver"
pruefe '[ "$(PATH="/usr/bin:/bin" HYPR_SHELL_SYSFS="$T/sys" "$REPO/bin/shell-toggle" status | jq .profile)" = null ]' "ohne powerprofilesctl fehlt der Schalter"

echo "== Nachtlicht"
echo '{"nightlight": {"temperature": 3500}}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
tg nightlight on; sleep 0.3
pruefe '[ "$(tg status | jq .nightlight)" = true ] && [ "$(cat "$T/sunset.log")" = "-t 3500" ]' "Nachtlicht an mit der eingestellten Wärme"
tg nightlight
pruefe '[ "$(tg status | jq .nightlight)" = false ]' "Nachtlicht wieder aus"

echo "== Leiste"
h="$T/apply"; mkdir -p "$h/.config/hypr-shell"; echo '{}' > "$h/.config/hypr-shell/settings.json"
HOME="$h" KEINE_MELDUNG=1 "$REPO/bin/shell-apply" --no-reload 2>/dev/null
j() { tail -n +2 "$h/.config/waybar/config.jsonc" | jq -r "$1"; }
pruefe '[ "$(j ".network.\"on-click\"")" = "\$HOME/.local/bin/shell-quickshell ipc panel page wifi" ] && [ "$(j ".bluetooth.\"on-click\"")" = "\$HOME/.local/bin/shell-quickshell ipc panel page bluetooth" ] && [ "$(j ".pulseaudio.\"on-click\"")" = "\$HOME/.local/bin/shell-quickshell ipc panel page audio" ]' "Klick auf WLAN, Bluetooth, Ton öffnet die Unterseite statt eines Terminals"
exit "$fehler"
