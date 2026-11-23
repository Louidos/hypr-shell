#!/usr/bin/env bash
# Prüft das Dashboard ohne Bildschirm: Datenskripte liefern gültiges JSON, das Wetter bleibt ohne
# Ort oder Netz ruhig, der Zwischenspeicher greift, und das Raster entspricht dem Auftrag.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T"
mkdir -p "$HOME/.config/hypr-shell"

fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }

echo "== Systemwerte"
about="$("$REPO/bin/shell-sysinfo" about)"
pruefe 'jq -e ".kernel != \"\" and .user != \"\" and (.uptime | type == \"number\") and (.memTotal > 0)" <<<"$about" >/dev/null' "shell-sysinfo about"
pruefe '"$REPO/bin/shell-sysinfo" cpu | jq -e ".model != null and (.cores | type == \"number\")" >/dev/null' "shell-sysinfo cpu"
gpu="$("$REPO/bin/shell-sysinfo" gpu 2>&1 || true)"
pruefe 'jq -e "(.name | type == \"string\") and (.state == \"active\" or .state == \"sleeping\")" <<<"$gpu" >/dev/null' "shell-sysinfo gpu"
jq -e . <<<"$gpu" >/dev/null 2>&1 || { echo "  Ausgabe: $gpu"; bash -x "$REPO/bin/shell-sysinfo" gpu 2>&1 | tail -n 25 | sed 's/^/    /'; }

echo "== Wetter"
pruefe '"$REPO/bin/shell-weather" | jq -e ".ok == false and .reason == \"no-location\"" >/dev/null' "ohne Ort ruhig (ok: false)"
echo '{"weather": {"location": "Zurich"}}' > "$HOME/.config/hypr-shell/settings.json"
w1="$("$REPO/bin/shell-weather")"
pruefe 'jq -e ".ok | type == \"boolean\"" <<<"$w1" >/dev/null' "mit Ort gültiges JSON"
if jq -e .ok <<<"$w1" >/dev/null; then
    pruefe 'jq -e "(.temp | type == \"number\") and .icon != \"\" and .description != \"\"" <<<"$w1" >/dev/null' "Temperatur, Symbol, Beschreibung"
    w2="$("$REPO/bin/shell-weather")"
    pruefe '[ "$(jq .time <<<"$w1")" = "$(jq .time <<<"$w2")" ]' "zweiter Aufruf aus dem Zwischenspeicher"
else
    echo "  Hinweis: kein Netz – nur das ruhige Verhalten geprüft ($(jq -r .reason <<<"$w1"))"
fi

echo "== Raster (col, row, cs, rs) wie im Auftrag"
raster() { grep -oE 'col: [0-9]+; row: [0-9]+; cs: [0-9]+; rs: [0-9]+' "$1" | tr -d ' ' | sort | tr '\n' ' '; }
pruefe '[ "$(raster quickshell/dashboard/HomeTab.qml)" = "col:0;row:0;cs:4;rs:1 col:0;row:1;cs:2;rs:2 col:2;row:1;cs:5;rs:2 col:4;row:0;cs:5;rs:1 col:7;row:1;cs:2;rs:2 col:9;row:0;cs:3;rs:3 " ]' "Tab Dashboard"
pruefe '[ "$(raster quickshell/dashboard/PerfTab.qml)" = "col:1;row:0;cs:5;rs:1 col:1;row:1;cs:4;rs:1 col:5;row:1;cs:4;rs:1 col:6;row:0;cs:5;rs:1 col:9;row:1;cs:2;rs:1 " ]' "Tab Performance"
pruefe 'grep -q "running: true" quickshell/dashboard/PerfTab.qml && grep -q "sourceComponent:" quickshell/dashboard/Dashboard.qml && grep -q "active: dash.open || win.t > 0.001" quickshell/dashboard/Dashboard.qml' "Tabs werden nur bei offenem Panel geladen (Abfragen laufen nur dann)"

exit "$fehler"
