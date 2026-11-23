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

# eigener D-Bus der Sitzung (für den Benachrichtigungsdienst und notify-send)
if [ -z "${HYPR_SHELL_DBUS:-}" ] && command -v dbus-run-session >/dev/null 2>&1; then
    HYPR_SHELL_DBUS=1 exec dbus-run-session -- "$0" "$@"
fi

T="$(mktemp -d)"
pids=()
# alle Ausgaben mitschreiben; am Ende stehen die FEHLER-Zeilen gesammelt da (das Log ist lang)
exec 3>&1
exec > >(tee -a "$T/ausgabe") 2>&1
aufraeumen() {
    local p
    if grep -q "FEHLER" "$T/ausgabe" 2>/dev/null; then
        { echo "---- Zusammenfassung: FEHLER ----"; grep "FEHLER" "$T/ausgabe"; } >&3
    fi
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
                 .config/kitty/colors.conf .config/rofi/colors.rasi .config/hypr-shell/colors.json; do
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
    HYPR_SHELL_TEST=1 HYPR_SHELL_POWER_DRYRUN=1 "$qs" -p "$cfg" >> "$T/qs.log" 2>&1 &
    qspid="$!"
    pids+=("$qspid")
    sleep 6
}
starte_qs

# bild NAME: Screenshot, dazu den Stand des Logs (für die Lage der Bilder, siehe Probe.qml)
bild() { grim "$OUT/$1.png" && cp "$T/qs.log" "$T/log-$1" && echo "  Screenshot: $1.png"; }
# IPC-Aufruf; schlägt er fehl, steht der Grund im Log und der Test läuft weiter (die Prüfungen danach melden es)
ipc() {
    "$qs" -p "$cfg" ipc call "$@" >/dev/null 2>"$T/ipc.err" && return 0
    echo "  Hinweis: ipc call $* ging nicht: $(head -c 300 "$T/ipc.err" | tr '\n' ' ')"
    return 0
}
offen() { "$qs" -p "$cfg" ipc call shell current 2>/dev/null; }

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

# ---- Benachrichtigungen: Karte, Verlauf, Nicht stören
note_ok=1
if command -v notify-send >/dev/null 2>&1 && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] \
    && "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target notifications'; then
    echo "---- Benachrichtigungen ----"
    nzahl() { "$qs" -p "$cfg" ipc call notifications "$1" 2>/dev/null; }
    notify-send -a "Test" Test "Body of the test notification"; sleep 1.5; bild benachrichtigung
    if [ "$(nzahl visible)" = 1 ] && [ "$(nzahl count)" = 1 ]; then echo "  ok: notify-send zeigt eine Karte und steht im Verlauf"
    else echo "  FEHLER: Karte/Verlauf: $(nzahl visible) / $(nzahl count)"; note_ok=0; fi
    "$HOME/.local/bin/shell-toggle" dnd on; sleep 1.5
    notify-send -a "Test" "Second" "while do not disturb"; sleep 1.5
    if [ "$(nzahl visible)" = 0 ] && [ "$(nzahl count)" = 2 ]; then echo "  ok: mit Nicht stören keine Karte, der Verlauf füllt sich trotzdem"
    else echo "  FEHLER: Nicht stören: $(nzahl visible) Karten, $(nzahl count) im Verlauf"; note_ok=0; fi
    if grep -q '"class":"dnd"' "$HOME/.local/share/hypr-shell/notifications-bar.json" 2>/dev/null; then echo "  ok: Glocke in der Leiste zeigt Nicht stören"
    else echo "  FEHLER: Glocke: $(cat "$HOME/.local/share/hypr-shell/notifications-bar.json" 2>/dev/null)"; note_ok=0; fi
    ipc notifications open; sleep 2; bild benachrichtigungen-verlauf
    ipc notifications clear; sleep 0.5
    if [ "$(nzahl count)" = 0 ]; then echo "  ok: Clear all leert den Verlauf"; else echo "  FEHLER: Verlauf nicht leer"; note_ok=0; fi
    ipc notifications close; sleep 0.5
    "$HOME/.local/bin/shell-toggle" dnd off
    if command -v dbus-send >/dev/null 2>&1; then
        besitzer="$(dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetConnectionUnixProcessID \
            string:org.freedesktop.Notifications 2>/dev/null | awk '/uint32/ {print $2}')"
        wer="$(tr '\0' ' ' < "/proc/${besitzer:-0}/cmdline" 2>/dev/null)"
        if [[ "$wer" == *"-p $cfg"* ]]; then echo "  ok: genau ein Benachrichtigungsdienst, und zwar hypr-shell (PID $besitzer)"
        else echo "  FEHLER: Benachrichtigungsdienst gehört PID ${besitzer:-?} ($wer), nicht Quickshell"; note_ok=0; fi
    fi
    pgrep -x swaync >/dev/null && { echo "  FEHLER: swaync läuft"; note_ok=0; }
else
    echo "  Hinweis: notify-send oder D-Bus fehlt, Benachrichtigungen nicht geprüft"
fi

# ---- Lautstärke-Anzeige und Power-Menü (Probelauf: nichts wird wirklich ausgeschaltet)
power_ok=1
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target power'; then
    echo "---- Anzeige und Power-Menü ----"
    ipc osd show volume 42 false; sleep 0.8; bild osd
    if [ "$("$qs" -p "$cfg" ipc call osd current 2>/dev/null)" = "volume 42" ]; then echo "  ok: Lautstärke-Anzeige erscheint"
    else echo "  FEHLER: Anzeige: $("$qs" -p "$cfg" ipc call osd current 2>/dev/null)"; power_ok=0; fi
    sleep 2
    if [ -z "$("$qs" -p "$cfg" ipc call osd current 2>/dev/null)" ]; then echo "  ok: Anzeige verschwindet von selbst"
    else echo "  FEHLER: Anzeige bleibt stehen"; power_ok=0; fi
    log="$HOME/.local/share/hypr-shell/power-dryrun.log"; rm -f "$log"
    ipc power open; sleep 1.5; bild power
    r1="$("$qs" -p "$cfg" ipc call power press shutdown 2>/dev/null)"; sleep 0.8; bild power-bestaetigen
    if [ "$r1" = armed ] && [ ! -s "$log" ]; then echo "  ok: Shutdown braucht einen zweiten Druck"
    else echo "  FEHLER: erster Druck: $r1, Log: $(cat "$log" 2>/dev/null)"; power_ok=0; fi
    r2="$("$qs" -p "$cfg" ipc call power press shutdown 2>/dev/null)"; sleep 1.5
    if [ "$r2" = "done" ] && [ "$(cat "$log" 2>/dev/null)" = shutdown ]; then echo "  ok: zweiter Druck löst aus (Probelauf)"
    else echo "  FEHLER: zweiter Druck: $r2, Log: $(cat "$log" 2>/dev/null)"; power_ok=0; fi
    if [ -z "$(offen)" ]; then echo "  ok: Menü danach geschlossen"; else echo "  FEHLER: noch offen: $(offen)"; power_ok=0; fi
else
    echo "FEHLER: IPC-Ziel power fehlt"; power_ok=0
fi

# ---- Starter (SUPER+R): Suche, Rechner
starter_ok=1
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target launcher'; then
    echo "---- Starter ----"
    ipc launcher open; sleep 2; bild launcher
    erst="$("$qs" -p "$cfg" ipc call launcher search "kit" 2>/dev/null)"
    if [ "$erst" = Kitty ]; then echo "  ok: \"kit\" findet Kitty"; else echo "  FEHLER: \"kit\" ergibt \"$erst\""; starter_ok=0; fi
    sleep 1; bild launcher-suche
    erg="$("$qs" -p "$cfg" ipc call launcher search "=12*8" 2>/dev/null)"
    if [ "$erg" = 96 ]; then echo "  ok: =12*8 zeigt 96"; else echo "  FEHLER: =12*8 ergibt \"$erg\""; starter_ok=0; fi
    sleep 1; bild launcher-rechner
    ipc launcher close; sleep 1
else
    echo "FEHLER: IPC-Ziel launcher fehlt"; starter_ok=0
fi

# ---- immer nur ein Panel offen: öffnet man das Dashboard bei offenem Panel, schliesst das Panel
panel_ok=1
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target shell'; then
    echo "---- nur ein Panel offen ----"
    ipc panel open; sleep 1
    if [ "$(offen)" = panel ]; then echo "  ok: Panel offen"; else echo "  FEHLER: Panel nicht offen ($(offen))"; panel_ok=0; fi
    ipc dashboard toggle; sleep 2; bild panel-dann-dashboard
    if [ "$(offen)" = dashboard ]; then echo "  ok: Dashboard geöffnet, Panel geschlossen"; else echo "  FEHLER: offen ist \"$(offen)\""; panel_ok=0; fi
    ipc launcher open; sleep 1
    if [ "$(offen)" = launcher ]; then echo "  ok: Starter schliesst das Dashboard"; else echo "  FEHLER: offen ist \"$(offen)\""; panel_ok=0; fi
    ipc settings open home; sleep 1
    if [ "$(offen)" = settings ]; then echo "  ok: Einstellungs-App schliesst das Dashboard"; else echo "  FEHLER: offen ist \"$(offen)\""; panel_ok=0; fi
    ipc shell close; sleep 1
    if [ -z "$(offen)" ]; then echo "  ok: alles geschlossen"; else echo "  FEHLER: noch offen: $(offen)"; panel_ok=0; fi
else
    echo "FEHLER: IPC-Ziel shell fehlt"; panel_ok=0
fi

# ---- Einstellungs-App: jede Seite, Suche, Bedienung. Im unsichtbaren Compositor gibt es kein
# Zeigegerät; "ipc call test …" löst deshalb die Signale der Bedienelemente aus (toggled/clicked,
# beim Regler moved … released) – derselbe Weg wie ein Mausklick.
app_ok=1
wert() { jq -c "$1" "$HOME/.config/hypr-shell/settings.json"; }
warte_auf() { # jq-ausdruck erwartet [versuche à 0.25 s]
    local _
    for _ in $(seq 1 "${3:-24}"); do [ "$(wert "$1")" = "$2" ] && return 0; sleep 0.25; done
    return 1
}
test_ipc() { [ "$("$qs" -p "$cfg" ipc call test "$@" 2>/dev/null)" = true ]; }
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
    ipc settings open look; sleep 2
    # Schalter: Blur aus
    if test_ipc click setting-look.blur.enabled && warte_auf .look.blur.enabled false; then echo "  ok: Schalter in der App landet in settings.json"
    else echo "  FEHLER: Schalter kam nicht in settings.json an ($(wert .look))"; app_ok=0; fi
    sleep 1
    # Regler ziehen: schon während des Ziehens wirkt der Wert
    rund_vorher="$(wert .look.rounding)"
    if test_ipc dragStart setting-look.rounding 0.8; then
        sleep 2
        r="$(grep -o '\["rounding"\] = [0-9]*' "$HOME/.config/hypr/hypr-shell-settings.lua" | grep -o '[0-9]*$')"
        if [ "${r:-12}" -eq 24 ]; then echo "  ok: Regler wirkt schon beim Ziehen (Hyprland-Rundung jetzt $r)"
        else echo "  FEHLER: Regler wirkt beim Ziehen nicht (Rundung ${r:-?})"; app_ok=0; fi
    else
        echo "  FEHLER: Regler look.rounding nicht gefunden"; app_ok=0
    fi
    if test_ipc drag setting-look.rounding 1 && warte_auf .look.rounding 30; then echo "  ok: Regler losgelassen: look.rounding = 30"
    else echo "  FEHLER: Regler-Wert $(wert .look.rounding)"; app_ok=0; fi
    sleep 2.5; bild settings-look-geaendert
    # Undo nimmt das ganze Ziehen in einem Schritt zurück, Reset page die ganze Seite
    if test_ipc click settings-undo && warte_auf .look.rounding "$rund_vorher" && [ "$(wert .look.blur.enabled)" = false ]; then echo "  ok: Undo nimmt das Ziehen in einem Schritt zurück"
    else echo "  FEHLER: Undo: $(wert .look)"; app_ok=0; fi
    sleep 2.5
    # Reset page setzt die geänderten Werte der Seite zurück (hier: Blur wieder Standard)
    if test_ipc click reset-page && warte_auf .look.blur.enabled null && [ "$(wert .look.rounding)" = "$rund_vorher" ]; then echo "  ok: Reset page setzt die Seite zurück"
    else echo "  FEHLER: Reset page: $(wert .look)"; app_ok=0; fi
    sleep 1
    # Reset neben einem Wert
    ipc settings open bar; sleep 1.5
    if test_ipc click "setting-bar.position=bottom" && warte_auf .bar.position '"bottom"'; then
        sleep 2.5
        if test_ipc click reset-bar.position && warte_auf .bar.position null; then echo "  ok: Auswahl und Reset neben dem Wert"
        else echo "  FEHLER: Reset neben dem Wert: $(wert .bar)"; app_ok=0; fi
    else
        echo "  FEHLER: Auswahl bar.position: $(wert .bar)"; app_ok=0
    fi
    ipc settings close; sleep 0.5
fi

# ---- Bearbeiten-Modus der Desktop-Widgets (SUPER+ALT+W)
edit_ok=1
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target desktop'; then
    echo "---- Widgets verschieben ----"
    vorher="$(wert .desktop)"
    ipc desktop edit; sleep 1.5; bild desktop-bearbeiten
    if test_ipc moveWidget clock 0.3 0.2; then sleep 1; bild desktop-bearbeiten-gezogen; else echo "  FEHLER: Bearbeiten-Modus nicht aktiv"; edit_ok=0; fi
    test_ipc click edit-cancel; sleep 1.5
    if [ "$(wert .desktop)" = "$vorher" ]; then echo "  ok: Cancel lässt alles wie vorher"; else echo "  FEHLER: Cancel hat gespeichert: $(wert .desktop)"; edit_ok=0; fi
    ipc desktop edit; sleep 1; test_ipc moveWidget resources 0.5 0.5; ipc desktop cancel; sleep 1.5
    if [ "$(wert .desktop)" = "$vorher" ]; then echo "  ok: Abbrechen wie mit Esc lässt alles wie vorher"; else echo "  FEHLER: Abbrechen hat gespeichert"; edit_ok=0; fi
    ipc desktop edit; sleep 1
    test_ipc moveWidget clock 0.3 0.2 && test_ipc click edit-done
    if warte_auf .desktop.clock.x 0.3 && [ "$(wert .desktop.clock.y)" = 0.2 ]; then echo "  ok: Done speichert die Position als Anteil der Bildschirmgrösse"
    else echo "  FEHLER: Done: $(wert .desktop)"; edit_ok=0; fi
    sleep 2
    if grep -q "mask: Region { }" quickshell/desktop/ClockWidget.qml && grep -q "mask: Region { }" quickshell/desktop/ResourcesWidget.qml; then
        echo "  ok: ausserhalb des Modus nehmen die Widgets keine Klicks an (leere Eingabefläche)"
    else echo "  FEHLER: Widgets nehmen Klicks an"; edit_ok=0; fi
fi

echo "---- Bilder und Symbole ----"
bereich dashboard-dashboard dashboard-avatar "Profilbild im Dashboard"
bereich dashboard-wallpaper wallpaper-card "erste Wallpaper-Karte"
bereich panel panel-avatar "Profilbild im Panel"
bereich panel app-icon "erstes App-Symbol im Panel"
bereich launcher launcher-first "erstes App-Symbol im Starter"

# ohne ~/.face: Anfangsbuchstabe statt Bild
if [ -n "$im" ]; then
    pkill -f -- "-p $cfg" 2>/dev/null || true   # auch den Kindprozess von Quickshell
    sleep 1
    rm -f "$HOME/.face"
    starte_qs
    ipc panel open; sleep 2; bild panel-ohne-face
    ipc panel close; sleep 1
    bereich panel-ohne-face panel-avatar "Anfangsbuchstabe ohne ~/.face"
    # nach dem Neustart (wie nach einer Neuanmeldung) steht die Uhr am gespeicherten Platz
    if [ "$edit_ok" -eq 1 ] && [ "$(wert .desktop.clock.x)" = 0.3 ]; then
        cx="$(grep -o "hypr-shell-probe desktop-clock .*" "$T/qs.log" | tail -n1 | awk '{print $3}')"
        if [ "${cx:-0}" -ge 570 ] && [ "${cx:-0}" -le 590 ]; then echo "  ok: Uhr steht nach dem Neustart am neuen Platz (x = $cx)"
        else echo "  FEHLER: Uhr nach dem Neustart bei x = ${cx:-?} statt 576"; edit_ok=0; fi
    fi
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

echo "---- Quickshell-Log (ohne Lage-Meldungen) ----"
grep -v "hypr-shell-probe" "$T/qs.log" || true
echo "------------------------"
[ "$farben_ok" -eq 1 ] || { echo "FEHLER: Farben aus dem Hintergrundbild"; exit 1; }
[ "$bereiche_ok" -eq 1 ] || { echo "FEHLER: Bilder oder Symbole fehlen (siehe oben)"; exit 1; }
[ "$ersatzbild_ok" -eq 1 ] || { echo "FEHLER: Ersatz-Profilbild"; exit 1; }
[ "$app_ok" -eq 1 ] || { echo "FEHLER: Einstellungs-App (siehe oben)"; exit 1; }
[ "$edit_ok" -eq 1 ] || { echo "FEHLER: Widgets verschieben (siehe oben)"; exit 1; }
[ "$power_ok" -eq 1 ] || { echo "FEHLER: Anzeige oder Power-Menü (siehe oben)"; exit 1; }
[ "$note_ok" -eq 1 ] || { echo "FEHLER: Benachrichtigungen (siehe oben)"; exit 1; }
[ "$starter_ok" -eq 1 ] || { echo "FEHLER: Starter (siehe oben)"; exit 1; }
[ "$panel_ok" -eq 1 ] || { echo "FEHLER: mehr als ein Panel offen (siehe oben)"; exit 1; }
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
