#!/usr/bin/env bash
# Startet die Quickshell-Oberfläche in einem unsichtbaren Wayland-Compositor (sway, headless,
# Software-Rendering), prüft das Log auf QML-Fehler und legt Screenshots nach $SCREENSHOTS
# (Standard: ./screenshots-ci). Blur gibt es dort nicht – die Bilder zeigen Aufbau und Masse.
# Läuft in der CI (archlinux); fehlt sway, quickshell oder grim, wird der Test übersprungen.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
OUT="${SCREENSHOTS:-$REPO/screenshots-ci}"

qs="$(command -v qs || command -v quickshell || true)"
for p in sway grim; do
    command -v "$p" >/dev/null 2>&1 || { echo "Hinweis: $p fehlt, Oberflächentest übersprungen."; exit 0; }
done
[ -n "$qs" ] || { echo "Hinweis: quickshell fehlt, Oberflächentest übersprungen."; exit 0; }
[ -f quickshell/shell.qml ] || { echo "Hinweis: noch keine Oberfläche, übersprungen."; exit 0; }

T="$(mktemp -d)"
pids=()
aufraeumen() {
    local p
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
    rm -rf "$T"
}
trap aufraeumen EXIT

export HOME="$T/home" XDG_RUNTIME_DIR="$T/run"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$OUT"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME
[ "$(id -u)" -eq 0 ] && export HYPR_SHELL_ALLOW_ROOT=1
"$REPO/install.sh" --yes --no-packages > "$T/install.log" 2>&1 || { cat "$T/install.log"; exit 1; }

# Testdaten: Einstellungen und ein Profilbild-Ersatz
SETTINGS_JSON="${SETTINGS_JSON:-$(jq '.weather.location = "Zurich"' "$REPO/settings/settings.example.json")}"
printf '%s\n' "$SETTINGS_JSON" > "$HOME/.config/hypr-shell/settings.json"

cat > "$T/sway.conf" <<CONF
output HEADLESS-1 resolution 1920x1080 position 0 0
output * bg $REPO/wallpapers/hypr-shell-grau.png fill
default_border none
CONF
# Kopie ohne Datei-Capabilities (sway hat cap_sys_nice, das ist in Containern verboten)
cp "$(command -v sway)" "$T/sway"
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    "$T/sway" -c "$T/sway.conf" > "$T/sway.log" 2>&1 &
pids+=("$!")
for _ in $(seq 1 100); do
    sock="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit)"
    [ -n "$sock" ] && break
    sleep 0.1
done
[ -n "${sock:-}" ] || { echo "FEHLER: sway startet nicht"; cat "$T/sway.log"; exit 1; }
export WAYLAND_DISPLAY="${sock##*/}" QT_QUICK_BACKEND=software QT_QPA_PLATFORM=wayland

cfg="$HOME/.config/quickshell/hypr-shell"
"$qs" -p "$cfg" > "$T/qs.log" 2>&1 &
pids+=("$!")
sleep 6

bild() { grim "$OUT/$1.png" && echo "  Screenshot: $1.png"; }
ipc() { "$qs" -p "$cfg" ipc call "$@" >/dev/null 2>&1; }

bild desktop
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target dashboard'; then
    for tab in dashboard wallpaper performance about; do
        ipc dashboard open "$tab"; sleep 2; bild "dashboard-$tab"
    done
    ipc dashboard close; sleep 1
fi
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target panel'; then
    ipc panel open; sleep 2; bild panel
    ipc panel close; sleep 1
fi

echo "---- Quickshell-Log ----"
cat "$T/qs.log"
echo "------------------------"
if ! kill -0 "${pids[1]}" 2>/dev/null; then
    echo "FEHLER: Quickshell ist abgestürzt"
    exit 1
fi
if grep -E "ERROR|TypeError|ReferenceError|is not a type|is not installed|Cannot assign|Unable to assign|Type error|SyntaxError|failed to load" "$T/qs.log" \
    | grep -vE "Failed to connect to|dbus|DBus|org\.freedesktop|polkit|pipewire|Pipewire|upower|UPower|notification server|NetworkManager|bluez|Bluez|mpris"; then
    echo "FEHLER: QML-Fehler im Log (siehe oben)"
    exit 1
fi
echo "Oberflächentest: keine QML-Fehler"
