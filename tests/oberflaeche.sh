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

# Testdaten: Einstellungen, Profilbild, zwei Hintergrundbilder, Beispiel-Apps (nur in diesem Test-HOME)
SETTINGS_JSON="${SETTINGS_JSON:-$(jq '.weather.location = "Zurich"' "$REPO/settings/settings.example.json")}"
printf '%s\n' "$SETTINGS_JSON" > "$HOME/.config/hypr-shell/settings.json"
im="$(command -v magick || command -v convert || true)"
ersatzbild_ok=1
if [ -n "$im" ]; then
    # der Installer lief ohne ~/.face: Ersatzbild für hyprlock muss da sein
    [ -s "$HOME/.local/share/hypr-shell/face.png" ] || { echo "FEHLER: kein Ersatz-Profilbild für hyprlock"; ersatzbild_ok=0; }
    "$im" -size 256x256 -seed 7 plasma:'#e0457b'-'#2a7fd4' "png:$HOME/.face"
    mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/.local/share/test-icons"
    "$im" -size 1920x1080 -seed 3 plasma:'#3b6e8f'-'#d9a441' "$HOME/Pictures/Wallpapers/01-test-wolken.png"
    "$im" -size 1920x1080 -seed 5 plasma:'#6a3d8f'-'#41d98a' "$HOME/Pictures/Wallpapers/02-test-wiese.png"
    "$im" -size 64x64 xc:'#5865f2' -fill white -draw 'circle 32,32 32,14' "$HOME/.local/share/test-icons/discord.png"
fi
mkdir -p "$HOME/.local/share/applications"
for app in kitty:Kitty:kitty firefox:Firefox:firefox org.gnome.Nautilus:Files:org.gnome.Nautilus steam:Steam:steam \
           "discord:Discord:$HOME/.local/share/test-icons/discord.png"; do
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
export WAYLAND_DISPLAY="${sock##*/}" QT_QUICK_BACKEND=software QT_QPA_PLATFORM=wayland QS_ICON_THEME=Papirus-Dark

# Hintergrundbild und Farben: buntes Testbild setzen (awww + matugen), erzeugte Dateien prüfen
farben_ok=1
if command -v awww >/dev/null 2>&1 && command -v matugen >/dev/null 2>&1; then
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
starte_qs() {
    HYPR_SHELL_TEST=1 "$qs" -p "$cfg" >> "$T/qs.log" 2>&1 &
    qspid="$!"
    pids+=("$qspid")
    sleep 6
}
starte_qs

# bild NAME: Screenshot, dazu den Stand des Logs (für die Lage der Bilder, siehe Probe.qml)
bild() { grim "$OUT/$1.png" && cp "$T/qs.log" "$T/log-$1" && echo "  Screenshot: $1.png"; }
ipc() { "$qs" -p "$cfg" ipc call "$@" >/dev/null 2>&1; }

# bereich SCREENSHOT PROBE TEXT: der Ausschnitt (Rand je 20 % weggelassen) darf nicht einfarbig sein.
# So fällt auf, wenn Profilbild, Vorschaubild oder App-Symbol leer bleiben.
bereiche_ok=1
bereich() {
    local shot="$1" name="$2" text="$3" x y w h sd
    if [ -z "$im" ]; then echo "  Hinweis: ImageMagick fehlt, $text nicht geprüft"; return 0; fi
    read -r x y w h < <(grep -o "hypr-shell-probe $name .*" "$T/log-$shot" 2>/dev/null | tail -n1 | awk '{print $3, $4, $5, $6}') || true
    if [ -z "${h:-}" ]; then
        echo "  FEHLER: $text – nicht sichtbar (keine Lage im Log)"; bereiche_ok=0; return 0
    fi
    x=$((x + w / 5)); y=$((y + h / 5)); w=$((w * 3 / 5)); h=$((h * 3 / 5))
    sd="$("$im" "$OUT/$shot.png" -crop "${w}x${h}+${x}+${y}" +repage -colorspace gray -format '%[fx:standard_deviation]' info:)"
    if awk -v s="$sd" 'BEGIN { exit !(s > 0.04) }'; then
        echo "  ok: $text sichtbar (Streuung $sd bei ${w}x${h}+${x}+${y})"
    else
        echo "  FEHLER: $text einfarbig (Streuung $sd bei ${w}x${h}+${x}+${y})"; bereiche_ok=0
    fi
}

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

# ---- Einstellungs-App: jede Seite, Suche, Klicks wie mit der Maus (sway-Zeiger)
app_ok=1
SWAYSOCK="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit)"
export SWAYSOCK
lage() { # probe -> "x y w h" aus dem neuesten Log-Eintrag
    grep -o "hypr-shell-probe $1 .*" "$T/qs.log" | tail -n1 | awk '{print $3, $4, $5, $6}'
}
klick() { # probe [anteil-x]: Mitte (bzw. Anteil der Breite) anklicken
    local x y w h
    read -r x y w h < <(lage "$1") || true
    [ -n "${h:-}" ] || { echo "  FEHLER: $1 nicht sichtbar"; app_ok=0; return 1; }
    swaymsg -q "seat seat0 cursor set $((x + w * ${2:-50} / 100)) $((y + h / 2))" \
        && swaymsg -q "seat seat0 cursor press button1" && sleep 0.15 && swaymsg -q "seat seat0 cursor release button1"
}
wert() { jq -c "$1" "$HOME/.config/hypr-shell/settings.json"; }
warte_auf() { # jq-ausdruck erwartet [sekunden]
    local _
    for _ in $(seq 1 "${3:-20}"); do [ "$(wert "$1")" = "$2" ] && return 0; sleep 0.25; done
    return 1
}
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target settings'; then
    echo "---- Einstellungs-App ----"
    for seite in home bar look theme desktop dashboard panel lock input monitors apps keybinds about; do
        ipc settings open "$seite"; sleep 2; bild "settings-$seite"
    done
    for q in blur clock battery; do
        vorher="$(grep -c "hypr-shell-probe search-first" "$T/qs.log" || true)"
        ipc settings search "$q"; sleep 1.5
        [ "$q" = blur ] && bild settings-suche
        if [ "$(grep -c "hypr-shell-probe search-first" "$T/qs.log" || true)" -gt "$vorher" ]; then echo "  ok: Suche findet \"$q\""
        else echo "  FEHLER: Suche findet \"$q\" nicht"; app_ok=0; fi
    done
    ipc settings close; sleep 0.5
    if [ -n "$SWAYSOCK" ] && command -v swaymsg >/dev/null 2>&1; then
        ipc settings open look; sleep 2
        # Schalter: Blur aus
        klick setting-look.blur.enabled && if warte_auf .look.blur.enabled false; then echo "  ok: Klick auf einen Schalter landet in settings.json"
            else echo "  FEHLER: Schalter-Klick kam nicht in settings.json an ($(wert .look))"; app_ok=0; fi
        # Regler ziehen: Rundung von links nach rechts; schon während des Ziehens wirkt der Wert
        sleep 2.5
        read -r x y w h < <(lage setting-look.rounding) || true
        if [ -n "${h:-}" ]; then
            swaymsg -q "seat seat0 cursor set $((x + 2)) $((y + h / 2))"; swaymsg -q "seat seat0 cursor press button1"
            for f in 25 50 75; do swaymsg -q "seat seat0 cursor set $((x + w * f / 100)) $((y + h / 2))"; sleep 0.6; done
            r="$(grep -o '\["rounding"\] = [0-9]*' "$HOME/.config/hypr/hypr-shell-settings.lua" | grep -o '[0-9]*$')"
            if [ "${r:-12}" -gt 12 ]; then echo "  ok: Regler wirkt schon beim Ziehen (Hyprland-Rundung jetzt $r)"
            else echo "  FEHLER: Regler wirkt beim Ziehen nicht"; app_ok=0; fi
            swaymsg -q "seat seat0 cursor set $((x + w + 20)) $((y + h / 2))"; sleep 0.3; swaymsg -q "seat seat0 cursor release button1"
            if warte_auf .look.rounding 30; then echo "  ok: Regler losgelassen: look.rounding = 30"
            else echo "  FEHLER: Regler-Wert $(wert .look.rounding)"; app_ok=0; fi
        else
            echo "  FEHLER: Regler look.rounding nicht sichtbar"; app_ok=0
        fi
        sleep 2.5; bild settings-look-geaendert
        # Undo stellt den Regler zurück, Reset page alles auf der Seite
        klick settings-undo && if warte_auf .look.rounding null; then echo "  ok: Undo nimmt das Ziehen in einem Schritt zurück"
            else echo "  FEHLER: Undo: $(wert .look)"; app_ok=0; fi
        sleep 2.5
        klick reset-page && if warte_auf .look null; then echo "  ok: Reset page setzt die Seite zurück"
            else echo "  FEHLER: Reset page: $(wert .look)"; app_ok=0; fi
        ipc settings close; sleep 0.5
    else
        echo "  Hinweis: swaymsg fehlt, Klicks nicht geprüft"
    fi
fi

echo "---- Bilder und Symbole ----"
bereich dashboard-dashboard dashboard-avatar "Profilbild im Dashboard"
bereich dashboard-wallpaper wallpaper-card "erste Wallpaper-Karte"
bereich panel panel-avatar "Profilbild im Panel"
bereich panel app-icon "erstes App-Symbol im Panel"

# ohne ~/.face: Anfangsbuchstabe statt Bild
if [ -n "$im" ]; then
    kill "$qspid" 2>/dev/null || true
    sleep 1
    rm -f "$HOME/.face"
    starte_qs
    ipc panel open; sleep 2; bild panel-ohne-face
    ipc panel close; sleep 1
    bereich panel-ohne-face panel-avatar "Anfangsbuchstabe ohne ~/.face"
fi

# Sperrbildschirm (jetzt ohne ~/.face, also mit dem Ersatzbild des Installers) – nur in diesem
# unsichtbaren Test-Compositor, nie in einer echten Sitzung. Kommt zuletzt, weil sway nach dem Beenden von hyprlock gesperrt bleibt.
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
[ "$bereiche_ok" -eq 1 ] || { echo "FEHLER: Bilder oder Symbole fehlen (siehe oben)"; exit 1; }
[ "$ersatzbild_ok" -eq 1 ] || { echo "FEHLER: Ersatz-Profilbild"; exit 1; }
[ "$app_ok" -eq 1 ] || { echo "FEHLER: Einstellungs-App (siehe oben)"; exit 1; }
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
