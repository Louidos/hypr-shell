#!/usr/bin/env bash
# Lädt die installierte hyprland.lua mit dem echten Hyprland (nicht nur mit der Attrappe):
#   1. ./install.sh --yes --no-packages in ein leeres HOME
#   2. Hyprland --verify-config: Hyprland liest die Konfiguration wie beim Start, ohne Bildschirm,
#      und meldet jeden Fehler (unbekannter Aufruf, falscher Wert, Lua-Fehler). Muss "config ok" sein.
#   3. Versuch (zur Information, entscheidet nicht über grün/rot): Hyprland wirklich starten,
#      verschachtelt in einem unsichtbaren sway, und hyprctl configerrors abfragen.
# Läuft in der CI (archlinux); fehlt Hyprland, wird der Test übersprungen.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"

command -v Hyprland >/dev/null 2>&1 || { echo "Hinweis: Hyprland fehlt, Test übersprungen."; exit 0; }

T="$(mktemp -d)"
pids=()
# shellcheck disable=SC2329 # wird über trap aufgerufen
aufraeumen() {
    local p
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
    rm -rf "$T"
}
trap aufraeumen EXIT

export HOME="$T/home" XDG_RUNTIME_DIR="$T/run"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME
[ "$(id -u)" -eq 0 ] && export HYPR_SHELL_ALLOW_ROOT=1
"$REPO/install.sh" --yes --no-packages > "$T/install.log" 2>&1 || { cat "$T/install.log"; exit 1; }

cfg="$HOME/.config/hypr/hyprland.lua"
version="$( (Hyprland --version 2>/dev/null || true) | head -n1)"
echo "== $version"
echo "== Hyprland --verify-config -c ~/.config/hypr/hyprland.lua"
set +e
Hyprland --verify-config -c "$cfg" > "$T/verify.log" 2>&1
rc=$?
set -e
# nur das Ergebnis zeigen (davor stehen Start-Meldungen)
sed -n '/Config parsing result/,$p' "$T/verify.log"
fehler=0
if [ "$rc" -ne 0 ] || ! grep -q "config ok" "$T/verify.log"; then
    echo "FEHLER: Hyprland meldet Fehler in hyprland.lua (Rückgabewert $rc)"
    grep -q "Config parsing result" "$T/verify.log" || tail -n 40 "$T/verify.log"
    fehler=1
else
    echo "  ok: Hyprland lädt hyprland.lua ohne Fehler"
fi

echo "== Versuch: Hyprland ohne Bildschirm starten (nur zur Information)"
if command -v sway >/dev/null 2>&1; then
    cat > "$T/sway.conf" <<CONF
output HEADLESS-1 resolution 1920x1080 position 0 0
CONF
    cp "$(command -v sway)" "$T/sway"
    WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 "$T/sway" -c "$T/sway.conf" > "$T/sway.log" 2>&1 &
    pids+=("$!")
    sock=""
    for _ in $(seq 1 50); do
        sock="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit)"
        [ -n "$sock" ] && break
        sleep 0.1
    done
    if [ -n "$sock" ]; then
        WAYLAND_DISPLAY="${sock##*/}" Hyprland -c "$cfg" > "$T/hyprland.log" 2>&1 &
        pids+=("$!")
        hsock=""
        for _ in $(seq 1 100); do
            hsock="$(find "$XDG_RUNTIME_DIR/hypr" -name '.socket.sock' -print -quit 2>/dev/null || true)"
            [ -n "$hsock" ] && break
            sleep 0.1
        done
        if [ -n "$hsock" ]; then
            sig="$(basename "$(dirname "$hsock")")"
            echo "  Hyprland läuft (Instanz $sig)"
            echo "  hyprctl configerrors: $(HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl configerrors 2>&1 | head -n 5)"
        else
            echo "  Hyprland startet hier nicht. Letzte Meldungen:"
            grep -iE "err|crit|fail|cannot|could not|no " "$T/hyprland.log" | tail -n 15 | sed 's/^/    /'
        fi
    else
        echo "  sway startet nicht, Versuch übersprungen"
    fi
else
    echo "  sway fehlt, Versuch übersprungen"
fi

exit "$fehler"
