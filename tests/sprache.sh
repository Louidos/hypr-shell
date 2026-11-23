#!/usr/bin/env bash
# Prüft das Sprechen mit Missa (shell-voice) mit Attrappen für rec, whisper-cli, piper-tts und aplay:
# Aufnahme mit Pegel, erkannter Text, keine Audiodatei bleibt liegen, Mikrofon in der Leiste nur
# während der Aufnahme, Vorlesen Satz für Satz mit Tempo, Stoppen; ohne Programme kein Fehler;
# ausgeschaltet nimmt nichts auf und die Taste ist nicht belegt.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_RUNTIME_DIR="$T/run" PIPER_LOG="$T/piper.log"
mkdir -p "$HOME/.local/share/hypr-shell/whisper" "$HOME/.local/share/hypr-shell/piper" "$XDG_RUNTIME_DIR" "$T/bin"
for p in rec whisper-cli piper-tts aplay; do ln -s "$REPO/tests/daten/$p" "$T/bin/$p"; done
touch "$HOME/.local/share/hypr-shell/whisper/ggml-base.bin" "$HOME/.local/share/hypr-shell/piper/de_DE-thorsten-medium.onnx"
echo '{"audio": {"sample_rate": 22050}}' > "$HOME/.local/share/hypr-shell/piper/de_DE-thorsten-medium.onnx.json"
EFF="$HOME/.local/share/hypr-shell/settings.effective.json"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
v() { PATH="$T/bin:$PATH" "$REPO/bin/shell-voice" "$@"; }

echo "== ausgeschaltet"
echo '{"missa": {"enabled": true, "voice_enabled": false}}' > "$EFF"
pruefe '{ v listen || true; } | grep -q "^E " && [ -z "$(ls -A "$XDG_RUNTIME_DIR")" ]' "Schalter aus: nichts wird aufgenommen"

echo "== Aufnehmen und erkennen"
echo '{"missa": {"enabled": true, "voice_enabled": true, "voice_speed": 1.25}}' > "$EFF"
pruefe '[ "$(v available | jq -c "[.ok, .speak]")" = "[true,true]" ]' "alles da"
v listen > "$T/listen.out" &
lp=$!
sleep 0.3
pruefe '[ "$(cat "$XDG_RUNTIME_DIR/hypr-shell-voice.state" 2>/dev/null)" = listening ]' "während der Aufnahme: Mikrofon in der Leiste"
pruefe '"$REPO/bin/shell-recording" status | jq -e ".text | test(\"󰍬\")" >/dev/null' "shell-recording zeigt das Mikrofon"
wait "$lp" || true
pruefe 'grep -q "^L [1-9]" "$T/listen.out" && grep -qx "S" "$T/listen.out"' "Pegel während der Aufnahme"
pruefe '[ "$(grep "^R " "$T/listen.out")" = "R \"Was habe ich morgen vor?\"" ]' "erkannter Text"
pruefe '[ -z "$(find "$XDG_RUNTIME_DIR" "$HOME" -name "*.wav")" ] && [ ! -e "$XDG_RUNTIME_DIR/hypr-shell-voice.state" ]' "danach liegt keine Audiodatei mehr auf der Platte, Mikrofon weg"
pruefe '[ "$("$REPO/bin/shell-recording" status | jq -r .text)" = "" ]' "Leiste ohne Mikrofon"

echo "== Vorlesen"
printf 'Morgen hast du um neun den Zahnarzt. Danach ist frei! Alles klar?\n' | v speak
pruefe '[ "$(wc -l < "$PIPER_LOG")" = 3 ] && grep -q "^Morgen hast du um neun den Zahnarzt. | " "$PIPER_LOG"' "Satz für Satz"
pruefe 'grep -q -- "--length-scale 0.80 --output-raw" "$PIPER_LOG"' "Tempo aus missa.voice_speed (1.25 → length-scale 0.80)"
: > "$PIPER_LOG"
printf 'Erster Satz. Zweiter Satz. Dritter Satz.\n' | APLAY_SLEEP=1 v speak &
sp=$!
sleep 0.5; v stop; sleep 0.3
pruefe '! kill -0 "$sp" 2>/dev/null && [ "$(wc -l < "$PIPER_LOG")" -lt 3 ]' "Stoppen beendet das Vorlesen"

echo "== ohne whisper.cpp und piper"
mkdir -p "$T/nix"; for p in bash jq sed awk tr cat mktemp chmod rm stdbuf sleep kill; do ln -sf "$(command -v "$p")" "$T/nix/$p"; done
pruefe '[ "$(PATH="$T/nix" "$REPO/bin/shell-voice" available | jq -c "[.ok, .speak]")" = "[false,false]" ]' "ohne Programme: nicht verfügbar"
pruefe '{ PATH="$T/nix" "$REPO/bin/shell-voice" listen 2>&1 || true; } | grep -q "^E " && echo hallo | PATH="$T/nix" "$REPO/bin/shell-voice" speak' "kein Absturz, nur eine Meldung"

echo "== Kürzel"
lua=$(command -v lua5.4 || command -v lua || true)
if [ -n "$lua" ]; then
    k() { local h="$T/k$1"; mkdir -p "$h/.config/hypr-shell"; printf '%s\n' "$2" > "$h/.config/hypr-shell/settings.json"
          HOME="$h" KEINE_MELDUNG=1 "$REPO/bin/shell-apply" --no-reload 2>/dev/null
          PATH="$3" HOME="$h" "$lua" "$REPO/tests/binds-json.lua" | jq -r '.[] | select(.description | startswith("Missa:")) | .description' | sort | tr '\n' '|'; }
    pruefe '[ "$(cd "$REPO" && k 1 "{\"missa\": {\"enabled\": true, \"voice_enabled\": false}}" "$T/bin:$PATH")" = "Missa: Chat with Missa|" ]' "Sprache aus: SUPER+SHIFT+I nicht belegt"
    pruefe '[ "$(cd "$REPO" && k 2 "{\"missa\": {\"enabled\": true, \"voice_enabled\": true}}" "$T/bin:$PATH")" = "Missa: Chat with Missa|Missa: Talk to Missa|" ]' "Sprache an: SUPER+SHIFT+I belegt"
    pruefe '[ "$(cd "$REPO" && k 3 "{\"missa\": {\"enabled\": true, \"voice_enabled\": true}}" "/usr/bin:/bin")" = "Missa: Chat with Missa|" ]' "ohne whisper.cpp fehlt die Taste"
fi
exit "$fehler"
