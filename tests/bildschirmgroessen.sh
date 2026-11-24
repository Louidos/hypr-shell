#!/usr/bin/env bash
# Prüft, dass sich die Oberfläche an Bildschirmgrösse, Skalierung und Hochformat anpasst:
#   1. Rechenteil der Grössen-Hilfe (quickshell/common/fit.js) mit dem qml-Werkzeug von Qt
#   2. Quickshell in einem unsichtbaren sway (headless): ein Bildschirm wechselt im laufenden
#      Betrieb Auflösung, Skalierung und Ausrichtung (ohne Neustart von Quickshell). Für jede Grösse
#      öffnet der Test jedes Panel und prüft über die Lage-Meldungen (Probe.qml), dass es ganz auf
#      dem Bildschirm liegt; dazu Dock, Desktop-Widgets und Benachrichtigungskarten.
#   3. zwei Bildschirme mit verschiedener Grösse: die Panels rechnen mit ihrem eigenen Bildschirm
# Screenshots landen in $SCREENSHOTS/groessen (Standard: ./screenshots-ci/groessen).
# Fehlt qml, wird Teil 1 übersprungen; fehlen sway, grim oder quickshell, Teil 2 und 3.
# shellcheck disable=SC2329
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
OUT="${SCREENSHOTS:-$REPO/screenshots-ci}/groessen"
fehler=0

# eigener D-Bus der Sitzung (Benachrichtigungsdienst und notify-send); vor allem anderen, damit
# nichts doppelt läuft
if [ -z "${HYPR_SHELL_DBUS:-}" ] && command -v dbus-run-session >/dev/null 2>&1; then
    HYPR_SHELL_DBUS=1 exec dbus-run-session -- "$0" "$@"
fi

# ---- 1. Rechenteil
echo "== 1. Grössen-Hilfe (fit.js)"
qml="$(command -v qml6 || command -v qml || ls /usr/lib/qt6/bin/qml 2>/dev/null || true)"
if [ -n "$qml" ]; then
    R="$(mktemp -d)"
    # QT_FORCE_STDERR_LOGGING: ohne Terminal schreibt Qt sonst ins Journal (console.* wäre unsichtbar)
    if XDG_RUNTIME_DIR="$R" QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES="qml.debug=true;js.debug=true" timeout 60 "$qml" tests/daten/fit-test.qml > "$R/log" 2>&1 \
        && ! grep -qE "FEHLER|Error|TypeError|ReferenceError" "$R/log" && grep -q "ok:" "$R/log"; then
        sed 's/^qml: //' "$R/log"
    else
        sed 's/^qml: //' "$R/log"; echo "  FEHLER: fit.js"; fehler=1
    fi
    rm -rf "$R"
else
    echo "  Hinweis: qml fehlt, übersprungen."
fi

# ---- 2. und 3. echte Oberfläche
qs="$(command -v qs || command -v quickshell || true)"
for p in sway swaymsg grim jq; do
    command -v "$p" >/dev/null 2>&1 || { echo "Hinweis: $p fehlt, Oberflächenteil übersprungen."; exit "$fehler"; }
done
[ -n "$qs" ] || { echo "Hinweis: quickshell fehlt, Oberflächenteil übersprungen."; exit "$fehler"; }

T="$(mktemp -d)"
pids=()
aufraeumen() { local p; for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$T"; }
trap aufraeumen EXIT
export HOME="$T/home" XDG_RUNTIME_DIR="$T/run"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$OUT"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME SWAYSOCK
[ "$(id -u)" -eq 0 ] && export HYPR_SHELL_ALLOW_ROOT=1
"$REPO/install.sh" --yes --no-packages > "$T/install.log" 2>&1 || { cat "$T/install.log"; exit 1; }
# Missa an (Adresse ohne Dienst: das Panel zeigt "nicht erreichbar"), damit auch der Chat geprüft wird
jq '.weather.location = "Zurich" | .missa.enabled = true | .missa.url = "http://127.0.0.1:9"' \
    "$REPO/settings/settings.example.json" > "$HOME/.config/hypr-shell/settings.json"

cp "$(command -v sway)" "$T/sway"
cfg="$HOME/.config/quickshell/hypr-shell"
mkdir -p "$T/fake"
for p in hyprctl nmcli bluetoothctl; do ln -sf "$REPO/tests/daten/$p" "$T/fake/$p"; done

# sitzung MODUS SKALIERUNG: sway (headless) mit einem Bildschirm und Quickshell starten
sitzung() {
    [ -n "${qspid:-}" ] && kill "$qspid" 2>/dev/null
    [ -n "${swaypid:-}" ] && kill "$swaypid" 2>/dev/null
    sleep 1
    rm -f "$XDG_RUNTIME_DIR"/wayland-* "$XDG_RUNTIME_DIR"/sway-ipc.*
    cat > "$T/sway.conf" <<CONF
output HEADLESS-1 resolution $1 scale $2 position 0 0
output * bg $REPO/wallpapers/hypr-shell-grau.png fill
default_border none
CONF
    WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 "$T/sway" -c "$T/sway.conf" >> "$T/sway.log" 2>&1 &
    swaypid="$!"
    pids+=("$swaypid")
    sock=""
    for _ in $(seq 1 100); do
        sock="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit)"
        [ -n "$sock" ] && break
        sleep 0.1
    done
    [ -n "${sock:-}" ] || { echo "FEHLER: sway startet nicht"; tail -n 20 "$T/sway.log"; exit 1; }
    export WAYLAND_DISPLAY="${sock##*/}" QT_QUICK_BACKEND=software QT_QPA_PLATFORM=wayland QS_ICON_THEME=Papirus-Dark
    SWAYSOCK="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit)"
    export SWAYSOCK
    PATH="$T/fake:$PATH" HYPRCTL_LOG="$T/hyprctl.log" HYPR_SHELL_TEST=1 HYPR_SHELL_POWER_DRYRUN=1 "$qs" -p "$cfg" >> "$T/qs.log" 2>&1 &
    qspid="$!"
    pids+=("$qspid")
    sleep 6
}
sitzung 1920x1080 1

ipc() { "$qs" -p "$cfg" ipc call "$@" >/dev/null 2>&1 || true; }
# letzte Lage einer Probe seit Zeile $2 des Logs: "x y b h"
lage() { tail -n "+${2:-1}" "$T/qs.log" | grep -o "hypr-shell-probe $1 .*" | tail -n1 | awk '{print $3, $4, $5, $6}'; }
zeilen() { wc -l < "$T/qs.log"; }

# liegt NAME (seit Logzeile AB) ganz auf einem Bildschirm SW×SH? Meldet ok/FEHLER.
pruefe_lage() {
    local name="$1" ab="$2" sw="$3" sh="$4" text="$5" x y b h
    read -r x y b h < <(lage "$name" "$ab") || true
    if [ -z "${h:-}" ]; then echo "  FEHLER: $text – keine Lage im Log (nicht sichtbar?)"; fehler=1; return 1; fi
    if [ "$x" -ge -1 ] && [ "$y" -ge -1 ] && [ $((x + b)) -le $((sw + 1)) ] && [ $((y + h)) -le $((sh + 1)) ] && [ "$b" -ge 40 ] && [ "$h" -ge 20 ]; then
        echo "  ok: $text ${b}x${h}+${x}+${y} in ${sw}x${sh}"
    else
        echo "  FEHLER: $text ${b}x${h}+${x}+${y} ragt über ${sw}x${sh} hinaus oder ist zu klein"; fehler=1; return 1
    fi
}

# Panels: Name der Probe (overlay-NAME), Öffnen, Schliessen
panels=(
    "dashboard|dashboard open dashboard|dashboard close"
    "panel|panel open|panel close"
    "settings|settings open home|settings close"
    "launcher|launcher open|launcher close"
    "notifications|notifications open|notifications close"
    "power|power open|power close"
    "clipboard|clipboard open|clipboard close"
    "overview|overview open|overview close"
    "cheatsheet|cheatsheet open|cheatsheet close"
    "missa|missa open|missa close"
    "osd|osd display volume 50 false|"
)

# groesse NAME MODUS SKALIERUNG DREHUNG: Bildschirm umstellen, alles prüfen
groesse() {
    local name="$1" mode="$2" scale="$3" dreh="$4" sw sh p ziel auf zu ab
    echo "== 2. $name: $mode, Skalierung $scale, Drehung $dreh"
    swaymsg output HEADLESS-1 resolution "$mode" scale "$scale" transform "$dreh" >/dev/null 2>&1
    sleep 3
    if ! kill -0 "$swaypid" 2>/dev/null; then
        echo "  FEHLER: sway ist beendet (Container?):"; tail -n 5 "$T/sway.log"; fehler=1; return 1
    fi
    # logische Grösse, wie Quickshell sie sieht (sway rechnet Skalierung und Drehung schon ein)
    read -r sw sh < <(swaymsg -t get_outputs -r | jq -r '.[] | select(.name == "HEADLESS-1") | "\(.rect.width) \(.rect.height)"')
    echo "  logisch ${sw}x${sh}"
    ab="$(zeilen)"; sleep 2
    pruefe_lage dock-body "$ab" "$sw" "$sh" "Dock"
    pruefe_lage desktop-clock "$ab" "$sw" "$sh" "Uhr auf dem Desktop"
    pruefe_lage desktop-resources "$ab" "$sw" "$sh" "Kacheln auf dem Desktop"
    if command -v notify-send >/dev/null 2>&1; then
        ab="$(zeilen)"
        notify-send -a Test "Size test" "A notification card on a ${sw}x${sh} screen"; sleep 2
        pruefe_lage notification-cards "$ab" "$sw" "$sh" "Benachrichtigungskarte"
        ipc notifications clear
    fi
    for p in "${panels[@]}"; do
        IFS='|' read -r ziel auf zu <<<"$p"
        ab="$(zeilen)"
        # die Anzeige (osd) blendet sich nach 1.5 s selbst aus: gleich nach dem Hereingleiten messen
        # shellcheck disable=SC2086
        ipc $auf; if [ "$ziel" = osd ]; then sleep 1.1; else sleep 2.2; fi
        pruefe_lage "overlay-$ziel" "$ab" "$sw" "$sh" "Panel $ziel"
        # Screenshots nur bis 2560 px Breite (4K-Bilder sprengen den gemeinsamen Speicher des Containers)
        if [ "${mode%%x*}" -le 2560 ]; then
            case "$ziel" in dashboard|settings|power|cheatsheet) grim "$OUT/$name-$ziel.png" 2>/dev/null ;; esac
        fi
        # shellcheck disable=SC2086
        [ -n "$zu" ] && { ipc $zu; sleep 0.6; }
    done
    sleep 1.5
}

groesse klein 1280x720 1 normal
groesse laptop 2560x1600 1.6 normal
groesse hochformat 2560x1600 1 90
# Hochformat: Einstellungen mit Seiten oben (die Leiste steht über der Suche), Dashboard in 6 Spalten
ab="$(zeilen)"; ipc settings open home; sleep 2.5
read -r _ ny _ _ < <(lage nav-home "$ab") || true
read -r _ sy _ _ < <(lage settings-search "$ab") || true
if [ -n "${ny:-}" ] && [ -n "${sy:-}" ] && [ "$ny" -lt "$sy" ]; then echo "  ok: Einstellungen im Hochformat: Seiten oben (y $ny) über der Suche (y $sy)"
else echo "  FEHLER: Einstellungen im Hochformat nicht umgeordnet (Seiten y ${ny:-?}, Suche y ${sy:-?})"; fehler=1; fi
grim "$OUT/hochformat-settings-compact.png" 2>/dev/null
ipc settings close; sleep 0.6
groesse laptop-125 1920x1080 1.25 normal

# ---- 3. zwei Bildschirme: Panels auf dem kleinen rechnen mit dessen Grösse
echo "== 3. zwei Bildschirme"
swaymsg output HEADLESS-1 resolution 2560x1440 scale 1 transform normal position 0 0 >/dev/null 2>&1
swaymsg create_output >/dev/null 2>&1; sleep 2
zweiter="$(swaymsg -t get_outputs -r | jq -r '.[] | select(.name != "HEADLESS-1") | .name' | head -n1)"
if [ -z "$zweiter" ]; then
    echo "  Hinweis: kein zweiter Bildschirm (create_output), übersprungen"
else
    swaymsg output "$zweiter" resolution 1280x720 scale 1 position 2560 0 >/dev/null 2>&1
    "$HOME/.local/bin/shell-set" desktop.screen "$zweiter" >/dev/null 2>&1; sleep 4
    for p in "${panels[@]}"; do
        IFS='|' read -r ziel auf zu <<<"$p"
        [ "$ziel" = osd ] && continue
        ab="$(zeilen)"
        # shellcheck disable=SC2086
        ipc $auf; sleep 2.2
        pruefe_lage "overlay-$ziel" "$ab" 1280 720 "Panel $ziel auf $zweiter (1280x720 neben 2560x1440)"
        # shellcheck disable=SC2086
        [ -n "$zu" ] && { ipc $zu; sleep 0.6; }
    done
    # abgesteckt: der eingestellte Bildschirm fehlt → erster Bildschirm, kein Absturz
    swaymsg output "$zweiter" unplug >/dev/null 2>&1; sleep 3
    ab="$(zeilen)"; ipc dashboard open dashboard; sleep 2.2
    pruefe_lage overlay-dashboard "$ab" 2560 1440 "Dashboard nach dem Abstecken auf dem ersten Bildschirm"
    ipc dashboard close; sleep 0.6
    "$HOME/.local/bin/shell-set" reset desktop.screen >/dev/null 2>&1; sleep 2
fi

if ! kill -0 "$qspid" 2>/dev/null; then echo "FEHLER: Quickshell ist abgestürzt"; fehler=1; fi

# ---- 4K in einer frischen Sitzung (sway stürzt nach dem Abstecken eines Bildschirms beim nächsten
# Moduswechsel ab – ein Fehler in sway, nicht in hypr-shell); auch hier ohne Neustart von Quickshell
# zwischen Skalierung 2 und 1
echo "== 4. 4K"
sitzung 3840x2160 2
groesse 4k-skalierung2 3840x2160 2 normal
breite_1080="$(lage overlay-dashboard 1 | awk '{print $3}')"
groesse 4k 3840x2160 1 normal
# 4K mit Skalierung 1: alles grösser als bei 1080 logischen Zeilen (nicht winzig)
ab="$(zeilen)"; ipc dashboard open dashboard; sleep 2.2
breite_4k="$(lage overlay-dashboard "$ab" | awk '{print $3}')"; ipc dashboard close; sleep 0.6
if [ -n "$breite_4k" ] && [ -n "$breite_1080" ] && [ "$breite_4k" -gt $((breite_1080 * 13 / 10)) ]; then
    echo "  ok: Dashboard auf 4K (Skalierung 1) ${breite_4k} px breit statt ${breite_1080} px – nicht winzig"
else
    echo "  FEHLER: Dashboard auf 4K nicht grösser (${breite_4k:-?} gegen ${breite_1080:-?})"; fehler=1
fi

if ! kill -0 "$qspid" 2>/dev/null; then echo "FEHLER: Quickshell ist abgestürzt"; fehler=1; fi
if grep -E "Binding loop|TypeError|ReferenceError|WARN scene" "$T/qs.log" | grep -vE "AppIcon\.qml\[[0-9:]+\]: Cannot open: file:///usr/share/pixmaps/" | sort -u | head -n 20 | grep .; then
    echo "FEHLER: QML-Warnungen im Log (siehe oben)"; fehler=1
fi
[ "$fehler" -eq 0 ] && echo "Bildschirmgrössen: alles passt"
exit "$fehler"
