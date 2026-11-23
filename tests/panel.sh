#!/usr/bin/env bash
# Prüft das Hot-Corner-Panel ohne Bildschirm: Schalter-Skript (Zustand als JSON, Gaming-Modus und
# Keep Awake schalten hin und zurück), Einstellungen aus settings.json, Tastenkürzel.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T"
unset HYPRLAND_INSTANCE_SIGNATURE

fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
st() { "$REPO/bin/shell-toggle" status | jq -r ".$1"; }

echo "== Schalter"
pruefe '"$REPO/bin/shell-toggle" status | jq -e "[.wifi, .bluetooth, .dnd, .gaming, .awake] | all(type == \"boolean\")" >/dev/null' "Zustand aller Schalter als JSON"
"$REPO/bin/shell-toggle" gaming on >/dev/null
pruefe '[ "$(st gaming)" = true ] && [ -e "$HOME/.local/share/hypr-shell/gaming" ]' "Gaming-Modus an (bleibt nach hyprctl reload, siehe hyprland.lua)"
"$REPO/bin/shell-toggle" gaming >/dev/null
pruefe '[ "$(st gaming)" = false ]' "Gaming-Modus wieder aus (toggle)"
pruefe 'grep -q "hypr-shell/gaming" config/hypr/hyprland.lua' "hyprland.lua liest den Gaming-Modus"
if command -v systemd-inhibit >/dev/null && systemd-inhibit --list >/dev/null 2>&1; then
    "$REPO/bin/shell-toggle" awake on; sleep 0.5
    pruefe '[ "$(st awake)" = true ]' "Keep Awake an"
    "$REPO/bin/shell-toggle" awake off
    pruefe '[ "$(st awake)" = false ]' "Keep Awake aus"
else
    echo "  Hinweis: kein logind – Keep Awake nur auf dem echten System prüfbar"
fi
pruefe '! "$REPO/bin/shell-toggle" unbekannt >/dev/null 2>&1' "unbekannter Schalter wird abgelehnt"

echo "== Einstellungen"
ex=settings/settings.example.json
pruefe '[ "$(jq -r .panel.corner $ex)" = bottom-right ] && [ "$(jq .panel.trigger $ex)" = 6 ] && [ "$(jq .panel.width $ex)" = 420 ] && [ "$(jq .panel.radius $ex)" = 26 ] && [ "$(jq .panel.opacity $ex)" = 0.44 ]' "Ecke unten rechts, 6 px, 420 px, Radius 26, Deckkraft 0.44"
pruefe '[ "$(jq -c .panel.sections $ex)" = "[\"awake\",\"apps\",\"media\",\"shot\",\"toggles\"]" ]' "Karten in der richtigen Reihenfolge"
pruefe '[ "$(jq -c .panel.toggles $ex)" = "[\"wifi\",\"bluetooth\",\"dnd\",\"gaming\",\"settings\"]" ]' "Schnellschalter"
pruefe '[ "$(jq ".panel.apps | length" $ex)" = 6 ]' "App-Liste mit 6 Apps"
for k in sections apps toggles corner trigger width radius opacity; do
    pruefe 'grep -q "panel\.$k" quickshell/panel/*.qml' "QML liest panel.$k aus settings.json"
done
pruefe 'grep -q "watchChanges: true" quickshell/common/Settings.qml' "Änderungen an settings.json wirken ohne Neustart"
pruefe 'grep -q "SUPER + A\|mod .. \" + A\"" config/hypr/hyprland.lua' "SUPER+A öffnet das Panel"

exit "$fehler"
