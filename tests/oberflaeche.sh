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
# Beispiel-Apps nur in diesem Test-HOME, damit das App-Raster des Panels etwas zeigt
mkdir -p "$HOME/.local/share/applications"
for app in kitty:Kitty:utilities-terminal firefox:Firefox:firefox org.gnome.Nautilus:Files:org.gnome.Nautilus steam:Steam:steam; do
    IFS=: read -r id name icon <<<"$app"
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\nIcon=%s\n' "$name" "$icon" \
        > "$HOME/.local/share/applications/$id.desktop"
done

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

# Hintergrundbild und Farben: buntes Testbild setzen (awww + matugen), erzeugte Dateien prüfen
farben_ok=1
if command -v awww >/dev/null 2>&1 && command -v matugen >/dev/null 2>&1; then
    im="$(command -v magick || command -v convert || true)"
    if [ -n "$im" ]; then
        bunt="$HOME/Pictures/Wallpapers/test-bunt.png"
        "$im" -size 1920x1080 gradient:'#1b3a8f'-'#e07a1f' "$bunt"
        setsid awww-daemon > "$T/awww.log" 2>&1 &
        pids+=("$!")
        "$HOME/.local/bin/shell-wallpaper" "$bunt" > "$T/wallpaper.log" 2>&1 || { cat "$T/wallpaper.log"; farben_ok=0; }
        echo "---- Farben aus dem Bild ----"
        for f in .config/hypr/hypr-shell-colors.lua .config/hypr/hyprlock-colors.conf .config/waybar/colors.css \
                 .config/swaync/colors.css .config/kitty/colors.conf .config/rofi/colors.rasi .config/hypr-shell/colors.json; do
            if [ -f "$HOME/$f" ] && ! grep -q "Standardfarben" "$HOME/$f" && ! grep -q "{{" "$HOME/$f"; then
                echo "  ok: $f"
            else
                echo "  FEHLER: $f nicht von matugen erzeugt"; farben_ok=0
            fi
        done
        jq -e '.accent | test("^#[0-9a-fA-F]{6}$")' "$HOME/.config/hypr-shell/colors.json" >/dev/null || { echo "  FEHLER: colors.json"; farben_ok=0; }
        luac_bin="$(command -v luac || command -v luac5.4 || true)"
        [ -z "$luac_bin" ] || "$luac_bin" -p "$HOME/.config/hypr/hypr-shell-colors.lua" || farben_ok=0
        echo "  Akzentfarbe: $(jq -r .accent "$HOME/.config/hypr-shell/colors.json")"
        if awww query 2>/dev/null | grep -q "test-bunt"; then echo "  ok: awww zeigt das Bild"
        else echo "  FEHLER: awww zeigt das Bild nicht"; farben_ok=0; fi
        if [ "$(cat "$HOME/.local/share/hypr-shell/wallpaper")" = "$bunt" ]; then echo "  ok: Auswahl gespeichert"
        else echo "  FEHLER: Auswahl nicht gespeichert"; farben_ok=0; fi
    fi
fi

# Leiste (Waybar) – Hyprland-Module melden ohne Hyprland Fehler, das ist hier egal
if command -v waybar >/dev/null 2>&1; then
    waybar > "$T/waybar.log" 2>&1 &
    pids+=("$!")
fi

cfg="$HOME/.config/quickshell/hypr-shell"
"$qs" -p "$cfg" > "$T/qs.log" 2>&1 &
qspid="$!"
pids+=("$qspid")
sleep 6

bild() { grim "$OUT/$1.png" && echo "  Screenshot: $1.png"; }
ipc() { "$qs" -p "$cfg" ipc call "$@" >/dev/null 2>&1; }

bild desktop
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target dashboard'; then
    for tab in dashboard wallpaper performance about; do
        ipc dashboard open "$tab"; sleep 3; bild "dashboard-$tab"
    done
    ipc dashboard close; sleep 1
fi
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target panel'; then
    ipc panel open; sleep 2; bild panel
    ipc panel close; sleep 1
fi

# Sperrbildschirm – nur in diesem unsichtbaren Test-Compositor, nie in einer echten Sitzung.
# Kommt zuletzt, weil sway nach dem Beenden von hyprlock gesperrt bleibt.
if command -v hyprlock >/dev/null 2>&1; then
    hyprlock -c "$HOME/.config/hypr/hyprlock.conf" > "$T/hyprlock.log" 2>&1 &
    lockpid="$!"
    sleep 4
    bild lockscreen
    kill "$lockpid" 2>/dev/null || true
    echo "---- hyprlock-Log ----"
    cat "$T/hyprlock.log"
    if grep -iE "config error|error in config|config has errors|\.conf.*(error|invalid)" "$T/hyprlock.log"; then
        echo "FEHLER: hyprlock meldet Konfigurationsfehler"
        exit 1
    fi
fi

echo "---- Quickshell-Log ----"
cat "$T/qs.log"
echo "------------------------"
[ "$farben_ok" -eq 1 ] || { echo "FEHLER: Farben aus dem Hintergrundbild"; exit 1; }
if ! kill -0 "$qspid" 2>/dev/null; then
    echo "FEHLER: Quickshell ist abgestürzt"
    exit 1
fi
if grep -E "ERROR|TypeError|ReferenceError|is not a type|is not installed|Cannot assign|Unable to assign|Type error|SyntaxError|failed to load" "$T/qs.log" \
    | grep -vE "Failed to connect to|dbus|DBus|org\.freedesktop|polkit|pipewire|Pipewire|upower|UPower|notification server|NetworkManager|bluez|Bluez|mpris"; then
    echo "FEHLER: QML-Fehler im Log (siehe oben)"
    exit 1
fi
echo "Oberflächentest: keine QML-Fehler"
