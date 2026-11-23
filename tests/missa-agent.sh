#!/usr/bin/env bash
# Prüft den Missa-Agenten (shell-missa-agent) gegen den lokalen Testserver nach dem Vertrag
# "Geräte-Anschluss v1" (tests/daten/missa-testserver.py, nur 127.0.0.1): Anmeldung mit allen
# Werkzeugen und Stufen, "letzte PDF im Download-Ordner öffnen", jede Zugriffsstufe, gesperrte Ordner,
# Ablehnung und Rückfrage, Zeitlimit, Abbruch, Neuverbinden, jede ID höchstens einmal, Meldungen,
# Verlauf, gesperrter Bildschirm; Schalter aus: kein Agent.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
for p in jq python3 curl; do command -v "$p" >/dev/null || { echo "Hinweis: $p fehlt, übersprungen."; exit 0; }; done

T="$(mktemp -d)"
pids=()
aufraeumen() { local p; for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; pkill -f "$T/bin/hyprlock" 2>/dev/null || true; rm -rf "$T"; }
trap aufraeumen EXIT
export HOME="$T/home" XDG_RUNTIME_DIR="$T/run" HYPR_SHELL_NO_SYSTEMD=1 HYPRCTL_LOG="$T/hyprctl.log"
unset HYPRLAND_INSTANCE_SIGNATURE
[ "$(id -u)" -eq 0 ] && export HYPR_SHELL_ALLOW_ROOT=1
mkdir -p "$HOME/.local/share/hypr-shell" "$XDG_RUNTIME_DIR" "$T/bin" "$HOME/Downloads" "$HOME/.ssh"
EFF="$HOME/.local/share/hypr-shell/settings.effective.json"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
printf '#!/bin/sh\necho "$*" >> "%s/xdg-open.log"\n' "$T" > "$T/bin/xdg-open"
printf '#!/bin/sh\necho "$*" >> "%s/notify.log"\n' "$T" > "$T/bin/notify-send"
ln -s "$REPO/tests/daten/hyprctl" "$T/bin/hyprctl"
ln -s "$(command -v sleep)" "$T/bin/hyprlock"
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH"
port=$(( 23000 + RANDOM % 20000 ))
S="http://127.0.0.1:$port"
python3 "$REPO/tests/daten/missa-testserver.py" "$port" "$T/server.log" 2>"$T/server.err" &
pids+=("$!")
for _ in $(seq 1 50); do curl -s -o /dev/null "$S/health" && break; sleep 0.1; done
einstellen() { jq -n --arg u "$S" --argjson x "$1" '{missa: ({enabled: true, agent_enabled: true, url: $u, device: "testgeraet", access: "ask"} + $x)}' > "$EFF"; }
ag() { "$REPO/bin/shell-missa-agent" "$@"; }
auftrag() { curl -s -X POST "$S/test/auftrag" -d "$1" | jq -r .id; }
ergebnis() { # id [sekunden] -> JSON des Ergebnisses
    local i
    for i in $(seq 1 "$((${2:-10} * 5))"); do
        r="$(curl -s "$S/test/ergebnisse" | jq -c --arg id "$1" '.[] | select(.id == $id)')"
        [ -n "$r" ] && { echo "$r"; return 0; }
        sleep 0.2
    done
    echo '{}'
}

echo "== nie als root"
if [ "$(id -u)" -eq 0 ]; then
    pruefe '! HYPR_SHELL_ALLOW_ROOT=0 "$REPO/bin/shell-missa-agent" run 2>/dev/null' "als root verweigert der Agent den Start"
fi

echo "== Schalter aus: kein Agent"
echo '{"missa": {"enabled": true, "agent_enabled": false}}' > "$EFF"
ag sync; sleep 0.5
pruefe '[ "$(ag status | jq -c "[.enabled, .connected]")" = "[false,false]" ] && [ "$(curl -s "$S/test/anmeldungen" | jq length)" = 0 ]' "nach einer frischen Installation läuft kein Agent (keine Anmeldung)"
pruefe '! grep -q "WantedBy" config/systemd/user/shell-missa-agent.service' "Dienst startet nie von selbst"

echo "== Anmeldung"
einstellen '{}'
echo device-token | "$REPO/bin/shell-secrets" set MISSA_DEVICE_TOKEN
ag sync
for _ in $(seq 1 50); do [ "$(ag status | jq .connected)" = true ] && break; sleep 0.1; done
a="$(curl -s "$S/test/anmeldungen" | jq -c '.[0]')"
pruefe '[ "$(jq .protokoll <<<"$a")" = 1 ] && [ "$(jq -r .geraet <<<"$a")" = testgeraet ] && [[ "$(jq -r ".sitzungen[0]" <<<"$a")" == hypr-shell-* ]]' "Anmeldung nach Vertrag (Protokoll 1, Gerät, Sitzung hypr-shell-<Rechner>)"
pruefe '[ "$(jq "[.werkzeuge[] | select(.stufe == \"lesen\")] | length" <<<"$a")" = 5 ] && [ "$(jq "[.werkzeuge[] | select(.stufe == \"schreiben\")] | length" <<<"$a")" = 7 ] && [ "$(jq "[.werkzeuge[] | select(.stufe == \"zerstoererisch\")] | length" <<<"$a")" = 4 ]' "16 Werkzeuge: 5 lesen, 7 schreiben, 4 zerstörerisch"
pruefe '[ "$(jq "[.werkzeuge[] | select((.beschreibung | length) > 10 and .parameter.type == \"object\")] | length" <<<"$a")" = 16 ]' "jedes Werkzeug mit Beschreibung und JSON-Schema"
pruefe '[ "$(ag status | jq .connected)" = true ]' "verbunden (Symbol in der Leiste)"

echo "== letzte PDF im Download-Ordner öffnen"
touch -d "2026-11-01 10:00" "$HOME/Downloads/alt.pdf"; touch -d "2026-11-20 10:00" "$HOME/Downloads/Rechnung.pdf"; touch "$HOME/Downloads/notiz.txt"
id="$(auftrag '{"werkzeug": "rechner_dateien_suchen", "argumente": {"suche": "*.pdf", "ordner": "~/Downloads"}}')"
r="$(ergebnis "$id")"
pruefe '[ "$(jq .ok <<<"$r")" = true ] && jq -r .ergebnis <<<"$r" | head -n1 | grep -q "Downloads/Rechnung.pdf"' "suchen: neueste PDF zuerst"
id="$(auftrag "{\"werkzeug\": \"rechner_oeffnen\", \"argumente\": {\"ziel\": \"$HOME/Downloads/Rechnung.pdf\"}}")"
r="$(ergebnis "$id")"; sleep 0.3
pruefe '[ "$(jq .ok <<<"$r")" = true ] && grep -qx "$HOME/Downloads/Rechnung.pdf" "$T/xdg-open.log"' "öffnen: die Datei ist geöffnet"

echo "== Stufe ask: Befehl erst nach dem Klick"
id="$(auftrag '{"werkzeug": "rechner_befehl", "argumente": {"befehl": "echo hallo-vom-agent"}}')"
sleep 1
pruefe '[ "$(ergebnis "$id" 1)" = "{}" ]' "läuft nicht von selbst (wartet auf die Glas-Karte)"
ag answer "$id" yes
r="$(ergebnis "$id")"
pruefe '[ "$(jq .ok <<<"$r")" = true ] && jq -r .ergebnis <<<"$r" | grep -q hallo-vom-agent' "nach dem Klick ausgeführt"
id="$(auftrag '{"werkzeug": "rechner_befehl", "argumente": {"befehl": "touch '"$T"'/darf-nicht"}}')"
sleep 0.5; ag answer "$id" no
r="$(ergebnis "$id")"
pruefe '[ "$(jq -r .art <<<"$r")" = abgelehnt ] && [ ! -e "$T/darf-nicht" ]' "Esc lehnt ab"
id="$(auftrag '{"werkzeug": "rechner_datei_anlegen", "argumente": {"pfad": "bericht.txt", "inhalt": "Hallo"}}')"
r="$(ergebnis "$id")"
pruefe '[ "$(jq .ok <<<"$r")" = true ] && [ "$(cat "$HOME/Missa/Ausgabe/bericht.txt")" = Hallo ]' "Schreibendes ohne Rückfrage, Ablage in ~/Missa/Ausgabe"
id="$(auftrag '{"werkzeug": "rechner_datei_anlegen", "argumente": {"pfad": "bericht.txt", "inhalt": "Anders"}}')"
r="$(ergebnis "$id")"
pruefe '[ "$(jq .ok <<<"$r")" = false ] && [ "$(cat "$HOME/Missa/Ausgabe/bericht.txt")" = Hallo ]' "rechner_datei_anlegen überschreibt nie"

echo "== gesperrte Ordner in jeder Stufe"
echo geheim > "$HOME/.ssh/id_ed25519"
for stufe in read ask full; do
    einstellen "{\"access\": \"$stufe\"}"
    id="$(auftrag '{"werkzeug": "rechner_datei_lesen", "argumente": {"pfad": "~/.ssh/id_ed25519"}}')"
    r="$(ergebnis "$id")"
    pruefe '[ "$(jq -r .art <<<"$r")" = abgelehnt ] && ! grep -q geheim <<<"$r"' "Stufe $stufe: Lesen von ~/.ssh abgelehnt"
done
id="$(auftrag '{"werkzeug": "rechner_befehl", "argumente": {"befehl": "cat ~/.ssh/id_ed25519"}}')"
pruefe '[ "$(jq -r .art <<<"$(ergebnis "$id")")" = abgelehnt ]' "auch im Befehl (Stufe full)"

echo "== Stufe read und full"
einstellen '{"access": "read"}'
id="$(auftrag '{"werkzeug": "rechner_befehl", "argumente": {"befehl": "echo nie"}}')"
pruefe '[ "$(jq -r .art <<<"$(ergebnis "$id")")" = abgelehnt ]' "read: rechner_befehl läuft gar nicht"
id="$(auftrag '{"werkzeug": "rechner_status", "argumente": {}}')"
pruefe '[ "$(jq .ok <<<"$(ergebnis "$id")")" = true ]' "read: Lesendes geht"
einstellen '{"access": "full"}'
id="$(auftrag '{"werkzeug": "rechner_befehl", "argumente": {"befehl": "echo voll"}}')"
pruefe 'jq -r .ergebnis <<<"$(ergebnis "$id")" | grep -q voll' "full: ohne lokale Rückfrage"

echo "== Zeitlimit und Abbruch"
id="$(auftrag '{"werkzeug": "rechner_befehl", "argumente": {"befehl": "sleep 20", "zeitlimit": 1}, "frist_s": 10}')"
pruefe '[ "$(jq -r .art <<<"$(ergebnis "$id" 8)")" = zeitlimit ]' "Zeitlimit"
id="$(auftrag '{"werkzeug": "rechner_befehl", "argumente": {"befehl": "sleep 30; touch '"$T"'/nach-abbruch"}, "frist_s": 60}')"
sleep 1; curl -s -X POST "$S/test/abbruch" -d "{\"id\": \"$id\"}" >/dev/null; sleep 1.5
pruefe '[ "$(ergebnis "$id" 1)" = "{}" ] && ! pgrep -f "sleep 30; touch" >/dev/null' "abbruch beendet die laufende Aktion"

echo "== jede ID höchstens einmal"
curl -s -X POST "$S/test/auftrag" -d '{"id": "doppelt-1", "werkzeug": "rechner_befehl", "argumente": {"befehl": "echo x >> '"$T"'/zaehler"}}' >/dev/null
curl -s -X POST "$S/test/auftrag" -d '{"id": "doppelt-1", "werkzeug": "rechner_befehl", "argumente": {"befehl": "echo x >> '"$T"'/zaehler"}}' >/dev/null
sleep 2
pruefe '[ "$(wc -l < "$T/zaehler")" = 1 ]' "zweimal geschickt, einmal ausgeführt"

echo "== Meldungen"
curl -s -X POST "$S/test/meldung" -d '{"titel": "Alarm", "text": "ai01 CPU", "stufe": "notfall"}' >/dev/null
curl -s -X POST "$S/test/meldung" -d '{"titel": "Erinnerung", "text": "Training", "stufe": "wichtig"}' >/dev/null
sleep 1
pruefe 'grep -q -- "-u critical Alarm ai01 CPU" "$T/notify.log" && grep -q -- "-u normal Erinnerung Training" "$T/notify.log"' "meldung → Benachrichtigung (notfall bleibt stehen)"

echo "== gesperrter Bildschirm: nur Lesendes"
"$T/bin/hyprlock" 30 &
pids+=("$!")
sleep 0.3
id="$(auftrag '{"werkzeug": "rechner_zwischenablage_setzen", "argumente": {"text": "x"}}')"
pruefe '[ "$(jq -r .fehler <<<"$(ergebnis "$id")")" = "Bildschirm gesperrt: nur lesende Werkzeuge" ]' "Schreibendes abgelehnt, solange gesperrt"
kill "${pids[-1]}" 2>/dev/null || true

echo "== Neuverbinden"
vorher="$(curl -s "$S/test/anmeldungen" | jq length)"
curl -s -X POST "$S/test/trennen" >/dev/null
for _ in $(seq 1 40); do [ "$(curl -s "$S/test/anmeldungen" | jq length)" -gt "$vorher" ] && break; sleep 0.25; done
pruefe '[ "$(curl -s "$S/test/anmeldungen" | jq length)" -gt "$vorher" ]' "nach Abbruch neu verbunden und neu angemeldet"

echo "== Verlauf"
pruefe '[ "$(jq -s "[.[] | select(.ergebnis == \"erlaubt\")] | length" "$HOME/.local/share/hypr-shell/missa-actions.log")" -ge 5 ] && [ "$(jq -s "[.[] | select(.ergebnis == \"abgelehnt\")] | length" "$HOME/.local/share/hypr-shell/missa-actions.log")" -ge 5 ] && jq -e ".zeit and .werkzeug and .kurz" "$HOME/.local/share/hypr-shell/missa-actions.log" >/dev/null' "jede Aktion steht im Verlauf (Zeit, Werkzeug, Kurzfassung, erlaubt/abgelehnt)"
pruefe '! grep -rq "device-token" "$HOME/.local/share/hypr-shell" "$T/server.err"' "Geräte-Token in keinem Log"

echo "== Schalter im Panel: sofort trennen"
ag pause; sleep 0.5
pruefe '[ "$(ag status | jq -c "[.connected, .paused]")" = "[false,true]" ] && ! pgrep -f "shell-missa-agent run" >/dev/null' "Missa access aus: Verbindung sofort getrennt"
ag resume
for _ in $(seq 1 50); do [ "$(ag status | jq .connected)" = true ] && break; sleep 0.1; done
pruefe '[ "$(ag status | jq .connected)" = true ]' "wieder an: verbunden"
echo '{"missa": {"enabled": true, "agent_enabled": false}}' > "$EFF"
ag sync; sleep 0.5
pruefe '! pgrep -f "shell-missa-agent run" >/dev/null && [ "$(ag status | jq .connected)" = false ]' "Schalter aus: Agent gestoppt"
exit "$fehler"
