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

echo "== GPU: schlafende NVIDIA-Karte wird nicht geweckt"
dev="$T/sys/bus/pci/devices/0000:01:00.0"
mkdir -p "$dev/power" "$T/nvproc/gpus/0000:01:00.0" "$T/fakebin"
echo 0x10de > "$dev/vendor"; echo 0x030000 > "$dev/class"; echo suspended > "$dev/power/runtime_status"
echo "Model:           NVIDIA GeForce RTX 4070 Laptop GPU" > "$T/nvproc/gpus/0000:01:00.0/information"
printf '#!/bin/sh\ntouch "%s/geweckt"\necho 37\n' "$T" > "$T/fakebin/nvidia-smi"
chmod +x "$T/fakebin/nvidia-smi"
fake() { PATH="$T/fakebin:$PATH" HYPR_SHELL_SYSFS="$T/sys" HYPR_SHELL_NVPROC="$T/nvproc" "$REPO/bin/shell-sysinfo" "$@"; }
pruefe 'fake gpu-usage | jq -e ".state == \"sleeping\" and .util == null" >/dev/null' "gpu-usage: schlafend, Kachel zeigt –"
pruefe 'fake gpu | jq -e ".state == \"sleeping\" and (.name | test(\"RTX 4070\"))" >/dev/null' "gpu: schlafend, Name ohne Wecken"
pruefe '[ ! -e "$T/geweckt" ]' "nvidia-smi wurde nicht aufgerufen"
echo active > "$dev/power/runtime_status"
pruefe 'fake gpu-usage | jq -e ".state == \"active\" and .util == 37" >/dev/null' "gpu-usage: wach, Auslastung aus nvidia-smi"
pruefe '"$REPO/bin/shell-sysinfo" gpu-usage | jq -e "(.state | type == \"string\")" >/dev/null' "gpu-usage auf diesem Rechner gültig"

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
raster() { grep -oE 'col: [0-9]+; row: [0-9]+; cs: [0-9]+; rs: [0-9]+' "$1" | tr -d ' ' | sort -u | tr '\n' ' '; }
pruefe '[ "$(raster quickshell/dashboard/HomeTab.qml)" = "col:0;row:0;cs:4;rs:1 col:0;row:1;cs:2;rs:2 col:2;row:1;cs:5;rs:2 col:4;row:0;cs:5;rs:1 col:7;row:1;cs:2;rs:2 col:9;row:0;cs:3;rs:3 " ]' "Tab Dashboard"
pruefe '[ "$(raster quickshell/dashboard/PerfTab.qml)" = "col:1;row:0;cs:5;rs:1 col:1;row:1;cs:4;rs:1 col:5;row:1;cs:4;rs:1 col:6;row:0;cs:5;rs:1 col:9;row:1;cs:2;rs:1 " ]' "Tab Performance"

echo "== Aufbau wie die Vorlage"
pruefe '! grep -rnE "icon: \"\"[,}]" quickshell --include="*.qml"' "kein leeres Symbol in den Kachel- und Tab-Listen"
d=quickshell/desktop; b=quickshell/dashboard
pruefe 'grep -q "font.family: Theme.clock" $d/ClockWidget.qml && [ "$(jq -r ".keys[] | select(.key == \"theme.font.clock\") | .default" settings/schema.json)" = "JetBrainsMono Nerd Font" ] && grep -q "font.bold: true" $d/ClockWidget.qml && grep -q "150 \* k" $d/ClockWidget.qml && grep -q "opacity: 0.85" $d/ClockWidget.qml && grep -q "opacity: 0.45" $d/ClockWidget.qml && ! grep -q "Theme.display" $d/ClockWidget.qml' "Desktop-Uhr: JetBrainsMono fett, 150 px, 85 % / 45 %, kein Bebas Neue"
pruefe '[ "$(grep -oE "label: \"[A-Za-z]+\"" $d/ResourcesWidget.qml | tr "\n" " ")" = "label: \"CPU\" label: \"RAM\" label: \"GPU\" label: \"Disk\" " ] && [ "$(jq -c ".keys[] | select(.key == \"desktop.resources.tiles\") | .default" settings/schema.json)" = "[\"cpu\",\"ram\",\"gpu\"]" ] && grep -q "gpu-usage" $d/ResourcesWidget.qml' "Desktop-Kacheln CPU, RAM, GPU (Disk wählbar)"
pruefe 'grep -q "width / dash.tabs.length" $b/Dashboard.qml && grep -q "color: Theme.pill" $b/Dashboard.qml && grep -q "dash.tabIcons\[tb.modelData\]" $b/Dashboard.qml' "Tab-Leiste: gleich breite Tabs, Symbol über Text, weisse Pille"
pruefe '! grep -qi "swap" $b/HomeTab.qml && [ "$(grep -A16 "Ringe (2×2" $b/HomeTab.qml | grep -c "label: ")" = 3 ] && grep -q "gapped: true" $b/HomeTab.qml' "Ringe: CPU, RAM, Disk untereinander, kein Swap"
pruefe 'grep -q "\"Usage\"" $b/PerfTab.qml && grep -q "component Cookie" $b/PerfTab.qml && grep -q "\"Used\"" $b/PerfTab.qml && grep -q "Download" $b/PerfTab.qml && grep -q "Upload" $b/PerfTab.qml && grep -q "\"Total\"" $b/PerfTab.qml' "Performance: Abzeichen Usage, Ring Used, Download/Upload/Total"
pruefe 'grep -q "Saved and copied to clipboard" quickshell/panel/PanelContent.qml' "Panel: Screenshot-Karte mit Hinweis"

pruefe 'grep -q "running: true" quickshell/dashboard/PerfTab.qml && grep -q "content: Component" quickshell/dashboard/Dashboard.qml && grep -q "active: !ov.lazy || ov.open || win.t > 0.001" quickshell/common/Overlay.qml' "Tabs werden nur bei offenem Panel geladen (Abfragen laufen nur dann)"

echo "== gemeinsame Panel-Grundlage"
for f in quickshell/dashboard/Dashboard.qml quickshell/panel/HotCorner.qml quickshell/settings/SettingsApp.qml; do
    pruefe 'grep -q "^    Overlay {" "$f"' "$f nutzt den Baustein Overlay"
done
pruefe '! grep -q "PanelWindow {[[:space:]]*$" quickshell/settings/SettingsApp.qml && [ "$(grep -c "PanelWindow {" quickshell/dashboard/Dashboard.qml)" = 1 ] && [ "$(grep -c "PanelWindow {" quickshell/panel/HotCorner.qml)" = 1 ]' "eigene Fenster nur noch für Kante und Ecke"
pruefe 'grep -q "readonly property bool open: exclusive ? Ui.panel === name : localOpen" quickshell/common/Overlay.qml && grep -q "property string panel: \"\"" quickshell/common/Ui.qml' "zentrale Stelle: immer nur ein Panel offen (Ui.panel)"
pruefe 'grep -q "Keys.onEscapePressed: if (ov.closeOnEscape) ov.hide()" quickshell/common/Overlay.qml && grep -q "HyprlandFocusGrab" quickshell/common/Overlay.qml' "Esc und Klick daneben schliessen"
pruefe 'grep -q "target: ov.name" quickshell/common/Overlay.qml' "jedes Panel ist per IPC erreichbar"

exit "$fehler"
