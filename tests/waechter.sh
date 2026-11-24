#!/usr/bin/env bash
# Prüft bin/shell-waechter (Neustart von Leiste und Oberfläche nach einem Absturz):
# Absturz → Neustart, höchstens 6 Starts in 2 Minuten (dann Benachrichtigung und Schluss), sauberes
# Ende und SIGTERM → kein Neustart, "shell-waechter stop" beendet beides, ein zweiter Wächter mit
# demselben Namen tut nichts; Leiste und Quickshell starten über den Wächter.
# shellcheck disable=SC2016,SC2034
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
T="$(mktemp -d)"
trap 'pkill -f "$T/" 2>/dev/null; rm -rf "$T"' EXIT
export XDG_RUNTIME_DIR="$T/run" SHELL_WAECHTER_PAUSE=0 PATH="$T/bin:$PATH"
mkdir -p "$XDG_RUNTIME_DIR" "$T/bin"
printf '#!/bin/sh\necho "$@" >> "%s/meldungen"\n' "$T" > "$T/bin/notify-send"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
W="$REPO/bin/shell-waechter"

echo "== Absturz"
printf '#!/bin/sh\necho x >> "%s/starts"\nkill -SEGV $$\n' "$T" > "$T/bin/stuerzt"; chmod +x "$T/bin/stuerzt" "$T/bin/notify-send"
timeout 20 "$W" leiste -- stuerzt 2>"$T/err"
pruefe '[ "$(wc -l < "$T/starts")" = 6 ]' "nach einem Absturz neu gestartet, höchstens 6-mal in 2 Minuten ($(wc -l < "$T/starts") Starts)"
pruefe 'grep -q "nicht mehr neu gestartet" "$T/meldungen"' "danach Schluss mit einer Benachrichtigung"

echo "== sauberes Ende, SIGTERM, stop"
printf '#!/bin/sh\necho x >> "%s/starts2"\nexit 0\n' "$T" > "$T/bin/fertig"; chmod +x "$T/bin/fertig"
timeout 10 "$W" fertig -- fertig
pruefe '[ "$(wc -l < "$T/starts2")" = 1 ]' "Rückgabe 0: kein Neustart"
printf '#!/bin/sh\necho x >> "%s/starts3"\nexec sleep 30\n' "$T" > "$T/bin/laeuft"; chmod +x "$T/bin/laeuft"
"$W" lang -- laeuft & wp=$!
sleep 0.5
pruefe '! "$W" lang -- laeuft 2>/dev/null & sleep 0.5; [ "$(wc -l < "$T/starts3")" = 1 ]' "zweiter Wächter mit demselben Namen tut nichts"
pkill -TERM -f "^sleep 30$" 2>/dev/null; sleep 1
pruefe '[ "$(wc -l < "$T/starts3")" = 1 ] && ! kill -0 "$wp" 2>/dev/null' "SIGTERM an das Programm (pkill): kein Neustart, Wächter beendet"
"$W" lang2 -- laeuft & wp=$!
sleep 0.5
"$W" stop lang2; sleep 1
pruefe '! kill -0 "$wp" 2>/dev/null && [ "$(wc -l < "$T/starts3")" = 2 ] && ! pgrep -f "^sleep 30$" >/dev/null' "shell-waechter stop beendet Programm und Wächter"
pruefe '! "$W" "" -- x 2>/dev/null && ! "$W" leiste 2>/dev/null && ! "$W" leiste -- gibt-es-nicht 2>/dev/null' "fehlender Name, Befehl oder Programm: Meldung statt Start"

echo "== Einbindung"
pruefe 'grep -q "shell-waechter waybar -- waybar" config/hypr/hyprland.lua' "Leiste startet über den Wächter"
pruefe 'grep -q "\$waechter\" quickshell --" bin/shell-quickshell && grep -q "\$waechter\" stop quickshell" bin/shell-quickshell' "Quickshell startet über den Wächter, stop beendet ohne Neustart"
exit "$fehler"
