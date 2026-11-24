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

# gedrehte Bildschirme (alle acht Werte) und ein Touchscreen mit Stift: Hyprland nimmt transform 0–7
# und input.touchdevice/input.tablet an
echo "== Hyprland --verify-config mit gedrehten Bildschirmen und Touchscreen"
jq -n '{monitors: {outputs: [
    {name: "eDP-1", transform: "270", scale: "1.6"}, {name: "DP-1", transform: "90"}, {name: "DP-2", transform: "180"},
    {name: "DP-3", transform: "flipped"}, {name: "DP-4", transform: "flipped-90"}, {name: "DP-5", transform: "flipped-180"},
    {name: "DP-6", transform: "flipped-270"}, {name: "HDMI-A-1", transform: "normal", position: "auto"}]}}' \
    > "$HOME/.config/hypr-shell/settings.json"
KEINE_MELDUNG=1 "$HOME/.local/bin/shell-apply" --no-reload > "$T/apply.log" 2>&1 || { cat "$T/apply.log"; fehler=1; }
set +e
HYPR_SHELL_INPUT_DEVICES="$REPO/tests/fixtures/eingabe/touch-und-stift" Hyprland --verify-config -c "$cfg" > "$T/verify2.log" 2>&1
rc=$?
set -e
sed -n '/Config parsing result/,$p' "$T/verify2.log"
if [ "$rc" -ne 0 ] || ! grep -q "config ok" "$T/verify2.log"; then
    echo "FEHLER: Hyprland lehnt gedrehte Bildschirme oder die Touch-Drehung ab (Rückgabewert $rc)"
    grep -q "Config parsing result" "$T/verify2.log" || tail -n 40 "$T/verify2.log"
    fehler=1
else
    echo "  ok: Hyprland nimmt Drehung 0–7 und die Drehung von Touchscreen und Stift an"
fi
# leuchtender Rand (theme.border.glow): Schatten in Randfarbe, keine Schatten für Ausnahmen und Vollbild
echo "== Hyprland --verify-config mit leuchtendem Rand"
echo '{"theme": {"border": {"glow": true, "glow_size": 12, "glow_opacity": 0.3}}}' > "$HOME/.config/hypr-shell/settings.json"
KEINE_MELDUNG=1 "$HOME/.local/bin/shell-apply" --no-reload > "$T/apply.log" 2>&1 || { cat "$T/apply.log"; fehler=1; }
set +e
Hyprland --verify-config -c "$cfg" > "$T/verify3.log" 2>&1
rc=$?
set -e
sed -n '/Config parsing result/,$p' "$T/verify3.log"
if [ "$rc" -ne 0 ] || ! grep -q "config ok" "$T/verify3.log"; then
    echo "FEHLER: Hyprland lehnt den leuchtenden Rand ab (Rückgabewert $rc)"
    grep -q "Config parsing result" "$T/verify3.log" || tail -n 40 "$T/verify3.log"
    fehler=1
else
    echo "  ok: Hyprland nimmt den leuchtenden Rand an (Schatten in Randfarbe, Ausnahmen ohne Schein)"
fi
echo '{}' > "$HOME/.config/hypr-shell/settings.json"
KEINE_MELDUNG=1 "$HOME/.local/bin/shell-apply" --no-reload > /dev/null 2>&1 || true

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
