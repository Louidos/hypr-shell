#!/usr/bin/env bash
# Prüft den Missa-Chat (shell-missa) gegen den lokalen Missa-Testserver (tests/daten/missa-testserver.py,
# nur 127.0.0.1, Beispielantworten): Streaming Wort für Wort, feste Sitzung hypr-shell-<Rechner>, nur die
# neue Nachricht, Sprechmodus-Header, Fehler 401/429/502 und kein Netz verständlich, Schlüssel nie in der
# Befehlszeile oder im Log; ausgeschaltet keine Netzanfrage und kein Kürzel.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null && command -v python3 >/dev/null && command -v curl >/dev/null || { echo "Hinweis: jq, python3 oder curl fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
pids=()
aufraeumen() { local p; for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$T"; }
trap aufraeumen EXIT
export HOME="$T/home"
unset HYPRLAND_INSTANCE_SIGNATURE
mkdir -p "$HOME/.local/share/hypr-shell"
EFF="$HOME/.local/share/hypr-shell/settings.effective.json"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
port=$(( 21000 + RANDOM % 20000 ))
python3 "$REPO/tests/daten/missa-testserver.py" "$port" "$T/server.log" 2>"$T/server.err" &
pids+=("$!")
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$port/health" && break; sleep 0.1; done
touch "$T/server.log"
m() { "$REPO/bin/shell-missa" "$@"; }

echo "== ausgeschaltet"
echo "{\"missa\": {\"enabled\": false, \"url\": \"http://127.0.0.1:$port\"}}" > "$EFF"
pruefe '[ "$(echo hallo | m chat)" = "E off \"Missa is switched off\"" ] && [ "$(m health | jq -r .state)" = off ] && [ ! -s "$T/server.log" ]' "keine Netzanfrage, wenn Missa aus ist"

echo "== Einrichtung"
echo "{\"missa\": {\"enabled\": true, \"url\": \"\"}}" > "$EFF"
pruefe '[ "$(m health | jq -r .state)" = setup ] && { echo hi | m chat || true; } | grep -q "^E setup"' "ohne Adresse: Anleitung statt Fehler"
echo "{\"missa\": {\"enabled\": true, \"url\": \"http://127.0.0.1:$port\"}}" > "$EFF"
pruefe '[ "$(m health | jq -r .text)" = "Enter the API key" ]' "ohne Schlüssel: Anleitung"
echo test-key | "$REPO/bin/shell-secrets" set MISSA_API_KEY
pruefe '[ "$(m health | jq -r .state)" = ok ]' "Statuspunkt aus GET /health"

echo "== Chat"
out="$(echo "Was habe ich morgen?" | m chat)"
pruefe '[ "$(grep -c "^T " <<<"$out")" -gt 5 ] && [ "$(tail -n1 <<<"$out")" = D ]' "Antwort läuft Wort für Wort ein ($(grep -c "^T " <<<"$out") Stücke)"
text="$(grep "^T " <<<"$out" | cut -c3- | jq -rj .)"
pruefe '[ "$text" = "Hallo! Morgen hast du um 9:00 den **Zahnarzt**. Danach ist frei." ]' "ganze Antwort ($text)"
s="$(tail -n1 "$T/server.log")"
pruefe '[ "$(jq -r .session <<<"$s")" = "$(m session)" ] && [[ "$(m session)" == hypr-shell-* ]] && [ "$(jq .anzahl <<<"$s")" = 1 ] && [ "$(jq -r .model <<<"$s")" = missa ] && [ "$(jq .stream <<<"$s")" = true ]' "Sitzung $(m session), nur die neue Nachricht, Modell missa, Streaming"
echo hallo | m chat >/dev/null
pruefe '[ "$(tail -n1 "$T/server.log" | jq -r .session)" = "$(m session)" ]' "gleiche Sitzung beim nächsten Mal (auch nach Neustart der Oberfläche)"
echo hallo | m chat --voice >/dev/null
pruefe '[ "$(tail -n1 "$T/server.log" | jq -r .modus)" = sprache ]' "Sprechmodus: X-Missa-Modus: sprache"
echo "neu" | MISSA_NEU=1 MISSA_VERLAUF='[{"role":"user","content":"a"},{"role":"assistant","content":"b"}]' m chat >/dev/null
pruefe '[ "$(tail -n1 "$T/server.log" | jq .anzahl)" = 4 ]' "neue Unterhaltung: eigener Verlauf (System-Hinweis + Verlauf + Frage)"

echo "== Abbrechen"
( echo "langsam bitte" | m chat > "$T/langsam.out" ) &
lp=$!
sleep 1.2
pkill -P "$lp" 2>/dev/null || true; kill "$lp" 2>/dev/null || true
sleep 0.5
pruefe '[ "$(grep -c "^T " "$T/langsam.out")" -lt 4 ] && ! grep -q "^D" "$T/langsam.out"' "Antwort lässt sich mitten im Stream abbrechen"

echo "== Fehler"
pruefe '[ "$(echo modellfehler | m chat | cut -d" " -f1,2)" = "E 502" ]' "Modell nicht erreichbar (502) verständlich"
echo falscher-schluessel | "$REPO/bin/shell-secrets" set MISSA_API_KEY
r="$(echo hi | m chat || true)"
pruefe '[ "$r" = "E 401 \"Wrong API key – check it in Settings → Integrations\"" ]' "falscher Schlüssel: klare Meldung"
pruefe '! grep -rq "falscher-schluessel" "$T/server.log" "$HOME/.local/share/hypr-shell" 2>/dev/null' "Schlüssel steht in keinem Log"
( echo "langsam" | m chat >/dev/null ) &
lp=$!; sleep 0.5
pruefe '! ps -eo args | grep -v grep | grep -q "falscher-schluessel"' "Schlüssel nie in der Prozessliste"
wait "$lp" 2>/dev/null || true
echo gesperrt | "$REPO/bin/shell-secrets" set MISSA_API_KEY
pruefe '{ echo hi | m chat || true; } | grep -q "^E 429 \"Locked after too many wrong keys"' "gesperrt (429) mit Wartezeit"
echo test-key | "$REPO/bin/shell-secrets" set MISSA_API_KEY
echo "{\"missa\": {\"enabled\": true, \"url\": \"http://127.0.0.1:1\"}}" > "$EFF"
pruefe '[ "$(echo hi | m chat | cut -d" " -f1,2)" = "E netz" ] && [ "$(m health | jq -r .state)" = unreachable ]' "kein Netz: ruhige Meldung"

echo "== Kürzel"
lua=$(command -v lua5.4 || command -v lua || true)
if [ -n "$lua" ]; then
    k() { local h="$T/k$1"; mkdir -p "$h/.config/hypr-shell"; printf '%s\n' "$2" > "$h/.config/hypr-shell/settings.json"
          HOME="$h" KEINE_MELDUNG=1 "$REPO/bin/shell-apply" --no-reload 2>/dev/null
          HOME="$h" "$lua" "$REPO/tests/binds-json.lua" | jq -r '.[] | select(.description | startswith("Missa:")) | .description'; }
    pruefe '[ -z "$(cd "$REPO" && k 1 "{}")" ]' "Missa aus: SUPER+I ist nicht belegt (tut still nichts, nicht im Spickzettel)"
    pruefe '[ "$(cd "$REPO" && k 2 "{\"missa\": {\"enabled\": true}}")" = "Missa: Chat with Missa" ]' "Missa an: SUPER+I öffnet den Chat"
fi
exit "$fehler"
