#!/usr/bin/env bash
# Prüft den gemeinsamen Abruf (shell-fetch) für Homelab, Kalender und Sensor gegen den lokalen
# Testserver (nur 127.0.0.1, Beispielantworten): ausgeschaltet keine Netzanfrage, eingeschaltet ohne
# Einträge eine Anleitung, Daten mit Feldern aus der API von Missa-Core, Termine aus CalDAV, Sensorwert mit
# Warnfarbe, nicht erreichbar schnell und ruhig mit letztem Stand, Zwischenspeicher, kein Token gespeichert.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
for p in jq python3 curl; do command -v "$p" >/dev/null || { echo "Hinweis: $p fehlt, übersprungen."; exit 0; }; done

T="$(mktemp -d)"
pids=()
aufraeumen() { local p; for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$T"; }
trap aufraeumen EXIT
export HOME="$T/home" XDG_CACHE_HOME="$T/cache"
mkdir -p "$HOME/.local/share/hypr-shell"
EFF="$HOME/.local/share/hypr-shell/settings.effective.json"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
port=$(( 24000 + RANDOM % 20000 )); S="http://127.0.0.1:$port"
python3 "$REPO/tests/daten/missa-testserver.py" "$port" "$T/server.log" 2>/dev/null &
pids+=("$!")
for _ in $(seq 1 50); do curl -s -o /dev/null "$S/health" && break; sleep 0.1; done
touch "$T/server.log"
f() { "$REPO/bin/shell-fetch" "$@"; }
alles() { jq -n --arg u "$S" --argjson an "$1" '{missa: {enabled: true, url: $u}, lab: {enabled: $an},
    calendar: {enabled: $an, url: ($u + "/caldav/"), user: "kal"},
    sensor: {enabled: $an, url: ($u + "/sensor.json"), field: "luft.co2", title: "CO2", unit: "ppm", warn: 1000}}' > "$EFF"; }

echo "== ausgeschaltet"
alles false
pruefe '[ "$(f lab | jq -r .error)" = off ] && [ "$(f calendar | jq -r .error)" = off ] && [ "$(f sensor | jq -r .error)" = off ] && [ ! -s "$T/server.log" ]' "Tab, Termine und Kachel aus: keine Netzanfrage"

echo "== eingeschaltet ohne Einträge"
alles true
pruefe '[ "$(f lab | jq -r .error)" = setup ] && [ "$(f calendar | jq -r .error)" = setup ]' "ohne Schlüssel/Passwort: Anleitung (setup) statt Fehler"
echo '{"missa": {"enabled": false}, "lab": {"enabled": true}}' > "$EFF"
pruefe '[ "$(f lab | jq -r .error)" = off ]' "Lab braucht missa.enabled"
alles true
echo test-key | "$REPO/bin/shell-secrets" set MISSA_API_KEY
echo kal-pw | "$REPO/bin/shell-secrets" set CALDAV_PASSWORD

echo "== Daten"
l="$(f lab)"
pruefe '[ "$(jq -c "[.ok, (.data.homelab.vms | length), .data.homelab.vms[0].name, .data.server.werte[0].ziel, (.data.container.hosts.wb01.container | length), .data.alarme.anzahl]" <<<"$l")" = "[true,3,\"rp01\",\"ai01\",2,1]" ]' "Homelab: VMs, Server, Container, Alarme (Felder aus docs/api.md)"
k="$(f calendar)"
pruefe '[ "$(jq -c "[.data.events[].title]" <<<"$k")" = "[\"Zahnarzt\",\"Projekt-Besprechung\",\"Geburtstag Anna\"]" ] && [ "$(jq ".data.events[2].allday" <<<"$k")" = true ]' "Kalender: Termine aus CalDAV, sortiert, ganztägig erkannt"
s="$(f sensor)"
pruefe '[ "$(jq -c ".data" <<<"$s")" = "{\"value\":1234,\"title\":\"CO2\",\"unit\":\"ppm\",\"warn\":true}" ]' "Sensor: Feld, Titel, Einheit, Warnfarbe über dem Grenzwert"

echo "== Zwischenspeicher und nicht erreichbar"
n="$(wc -l < "$T/server.log")"; f lab >/dev/null
pruefe '[ "$(wc -l < "$T/server.log")" = "$n" ]' "zweiter Abruf aus dem Zwischenspeicher"
kill "${pids[0]}"; sleep 0.3
start=$(date +%s%N)
r="$(HYPR_SHELL_FETCH_NOCACHE=1 f lab)"
ms=$(( ($(date +%s%N) - start) / 1000000 ))
pruefe '[ "$(jq -c "[.ok, .stale, .error]" <<<"$r")" = "[false,true,\"not reachable\"]" ] && [ -n "$(jq -r .last_ok <<<"$r")" ] && [ "$ms" -lt 4000 ]' "nicht erreichbar: ruhig, letzter Stand mit Zeitpunkt, nach ${ms} ms (Dashboard bleibt flüssig)"
pruefe '[ "$(HYPR_SHELL_FETCH_NOCACHE=1 f sensor | jq .data.value)" = 1234 ]' "Sensor zeigt weiter den letzten Wert"

echo "== kein Token gespeichert"
pruefe '! grep -rq "test-key\|kal-pw" "$XDG_CACHE_HOME" "$EFF" "$HOME/.local/share/hypr-shell/settings.effective.json"' "Zwischenspeicher und Einstellungen ohne Token"
exit "$fehler"
