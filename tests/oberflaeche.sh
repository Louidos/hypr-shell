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
        { echo "---- Zusammenfassung: FEHLER ----"; grep -E "FEHLER|Hinweis: ipc" "$T/ausgabe"; } >&3
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
# Beispiel-Steam-Ordner für den Tab Games (zwei Spiele, eines mit Cover)
st="$HOME/.local/share/Steam"
mkdir -p "$st/steamapps" "$st/appcache/librarycache"
printf '"AppState"\n{\n\t"appid"\t\t"570"\n\t"name"\t\t"Dota 2"\n\t"LastPlayed"\t\t"1700000000"\n}\n' > "$st/steamapps/appmanifest_570.acf"
printf '"AppState"\n{\n\t"appid"\t\t"620"\n\t"name"\t\t"Portal 2"\n\t"LastPlayed"\t\t"1600000000"\n}\n' > "$st/steamapps/appmanifest_620.acf"
[ -n "$im" ] && "$im" -size 300x450 -seed 11 plasma:'#c23b22'-'#1d1d6b' "$st/appcache/librarycache/570_library_600x900.jpg"
mkdir -p "$HOME/.local/share/applications"
for app in kitty:Kitty:kitty firefox:Firefox:firefox org.gnome.Nautilus:Files:org.gnome.Nautilus steam:Steam:steam \
           "discord:Discord:$HOME/.local/share/test-icons/discord.png"; do
    IFS=: read -r id name icon <<<"$app"
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\nIcon=%s\n' "$name" "$icon" \
        > "$HOME/.local/share/applications/$id.desktop"
done
# Dock: Testdaten für die Zuordnung Fenster → Programm (kitty, Firefox, Flatpak, Steam-Spiel, StartupWMClass)
cp "$REPO"/tests/fixtures/dock/applications/*.desktop "$HOME/.local/share/applications/"
mkdir -p "$HOME/Downloads"

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
    # Quickshell sieht eine hyprctl-Attrappe mit Beispielfenstern (tests/daten), Aufrufe landen in $T/hyprctl.log
    mkdir -p "$T/fake"
    for p in hyprctl nmcli bluetoothctl asusctl supergfxctl rec whisper-cli piper-tts aplay; do ln -sf "$REPO/tests/daten/$p" "$T/fake/$p"; done
    PATH="$T/fake:$PATH" ASUS_STATE="$T/asus" HYPRCTL_LOG="$T/hyprctl.log" HYPRCTL_BINDS="$T/binds.json" HYPR_SHELL_TEST=1 HYPR_SHELL_POWER_DRYRUN=1 "$qs" -p "$cfg" >> "$T/qs.log" 2>&1 &
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
    for tab in dashboard wallpaper performance games about; do
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
    ipc osd display volume 42 false; sleep 0.8; bild osd
    if [ "$("$qs" -p "$cfg" ipc call osd current 2>/dev/null)" = "volume 42" ]; then echo "  ok: Lautstärke-Anzeige erscheint"
    else
        echo "  FEHLER: Anzeige: \"$("$qs" -p "$cfg" ipc call osd current 2>&1)\" – IPC: $("$qs" -p "$cfg" ipc show 2>&1 | grep -A4 'target osd' | tr '\n' ' ')"
        echo "  FEHLER: (Anzeige) direkter Aufruf: $("$qs" -p "$cfg" ipc call osd display volume 42 false 2>&1 | head -c 300)"
        power_ok=0
    fi
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

# ---- Zwischenablage (SUPER+SHIFT+V): Reihenfolge, Bild mit Vorschau, Clear all
clip_ok=1
if command -v cliphist >/dev/null 2>&1 && "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target clipboard'; then
    echo "---- Zwischenablage ----"
    for t in "first copy" "second copy" "third copy"; do printf '%s' "$t" | cliphist store; done
    [ -n "$im" ] && "$im" -size 160x90 pattern:checkerboard -fill '#e0457b' -opaque black png:- | cliphist store
    ipc clipboard open; sleep 2; bild zwischenablage
    zahl="$("$qs" -p "$cfg" ipc call clipboard count 2>/dev/null)"
    erst="$("$HOME/.local/bin/shell-clipboard" list | jq -r '[.[] | select(.image == "")][0].text')"
    if [ "$zahl" -ge 4 ] && [ "$erst" = "third copy" ]; then echo "  ok: $zahl Einträge, neueste zuerst"
    else echo "  FEHLER: $zahl Einträge, erster Text \"$erst\""; clip_ok=0; fi
    ipc clipboard clear; sleep 1
    if [ "$("$qs" -p "$cfg" ipc call clipboard count 2>/dev/null)" = 0 ] && [ "$("$HOME/.local/bin/shell-clipboard" list)" = "[]" ]; then
        echo "  ok: Clear all leert den Verlauf"
    else echo "  FEHLER: Verlauf nicht leer"; clip_ok=0; fi
    ipc clipboard close; sleep 0.5
else
    echo "  Hinweis: cliphist fehlt, Zwischenablage nicht geprüft"
fi

# ---- Fenster-Übersicht (SUPER+Tab) mit Beispielfenstern aus der hyprctl-Attrappe
uebersicht_ok=1
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target overview'; then
    echo "---- Fenster-Übersicht ----"
    ipc overview open; sleep 2; bild uebersicht
    fenster="$("$qs" -p "$cfg" ipc call overview windows 2>/dev/null | tr '\n' '|')"
    if [ "$fenster" = "1:Terminal – htop|1:Mozilla Firefox|3:Files – Downloads|" ]; then echo "  ok: alle offenen Fenster an der richtigen Arbeitsfläche"
    else echo "  FEHLER: Fenster: $fenster"; uebersicht_ok=0; fi
    if [ "$("$qs" -p "$cfg" ipc call overview filter fire 2>/dev/null)" = 1 ]; then echo "  ok: Tippen filtert nach Titel"; else echo "  FEHLER: Filter"; uebersicht_ok=0; fi
    sleep 0.5; bild uebersicht-filter
    ipc overview moveFirst 2; sleep 0.8
    if grep -qF 'hl.dsp.window.move({ window = "address:0x55d3c0a1b2c0", workspace = 2, follow = false })' "$T/hyprctl.log" 2>/dev/null; then echo "  ok: Ziehen verschiebt das Fenster"
    else echo "  FEHLER: kein move ($(cat "$T/hyprctl.log" 2>/dev/null))"; uebersicht_ok=0; fi
    ipc overview focusFirst; sleep 0.8
    if grep -qF 'hl.dsp.focus({ window = "address:0x55d3c0a1b3d0" })' "$T/hyprctl.log" 2>/dev/null && [ -z "$(offen)" ]; then echo "  ok: Klick springt zum Fenster und schliesst die Übersicht"
    else echo "  FEHLER: kein focus ($(cat "$T/hyprctl.log" 2>/dev/null)), offen: $(offen)"; uebersicht_ok=0; fi
else
    echo "FEHLER: IPC-Ziel overview fehlt"; uebersicht_ok=0
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

# ---- Kürzel-Spickzettel (SUPER+F1) aus "hyprctl binds -j" (hier: die Kürzel aus hyprland.lua über die Attrappe)
spick_ok=1
lua_bin="$(command -v lua5.4 || command -v lua || true)"
if [ -n "$lua_bin" ] && "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target cheatsheet'; then
    echo "---- Kürzel-Spickzettel ----"
    (cd "$REPO" && "$lua_bin" tests/binds-json.lua) > "$T/binds.json"
    ipc cheatsheet open; sleep 2; bild spickzettel
    zeilen="$("$qs" -p "$cfg" ipc call cheatsheet rows 2>/dev/null)"
    soll="$(jq length "$T/binds.json")"
    if grep -qx "Panels|SUPER + F1|Keyboard shortcuts" <<<"$zeilen" && grep -qx "Workspaces|SUPER + 1…0|Go to workspace 1…10" <<<"$zeilen" \
        && grep -qx "Panels|SUPER + SHIFT + V|Clipboard history" <<<"$zeilen"; then echo "  ok: $(wc -l <<<"$zeilen") Zeilen aus $soll Kürzeln, Arbeitsflächen zusammengefasst"
    else echo "  FEHLER: Spickzettel: $(head -c 400 <<<"$zeilen")"; spick_ok=0; fi
    if [ "$(jq '[.[] | select(.has_description | not)] | length' "$T/binds.json")" = 0 ]; then echo "  ok: jedes Kürzel aus hyprland.lua hat eine Beschreibung"
    else echo "  FEHLER: Kürzel ohne Beschreibung"; spick_ok=0; fi
    if [ "$("$qs" -p "$cfg" ipc call cheatsheet filter terminal 2>/dev/null)" -ge 1 ]; then echo "  ok: Suche findet \"terminal\""
    else echo "  FEHLER: Suche"; spick_ok=0; fi
    ipc cheatsheet close; sleep 1
    # geändertes Kürzel: nach "hyprctl reload" (hier: neu erzeugt) steht es beim nächsten Öffnen richtig drin
    cp "$HOME/.config/hypr-shell/settings.json" "$T/settings.vorher"
    jq '.keybinds.terminal = "SUPER + T"' "$T/settings.vorher" > "$HOME/.config/hypr-shell/settings.json"
    KEINE_MELDUNG=1 "$HOME/.local/bin/shell-apply" --no-reload 2>/dev/null
    (cd "$REPO" && "$lua_bin" tests/binds-json.lua) > "$T/binds.json"
    ipc cheatsheet open; sleep 1.5
    if "$qs" -p "$cfg" ipc call cheatsheet rows 2>/dev/null | grep -qx "Apps|SUPER + T|Terminal"; then echo "  ok: geändertes Kürzel steht nach dem Neuladen richtig drin"
    else echo "  FEHLER: geändertes Kürzel fehlt"; spick_ok=0; fi
    ipc cheatsheet close; sleep 0.5
    cp "$T/settings.vorher" "$HOME/.config/hypr-shell/settings.json"
    KEINE_MELDUNG=1 "$HOME/.local/bin/shell-apply" --no-reload 2>/dev/null
else
    echo "  Hinweis: lua fehlt, Spickzettel nicht geprüft"
fi

# ---- Unterseiten im Panel (WLAN und Bluetooth aus Attrappen; der Test-Rechner hat keinen Bluetooth-Adapter)
seiten_ok=1
echo "---- Unterseiten im Panel ----"
ipc panel page wifi; sleep 2.5; bild panel-wlan
if [ "$("$qs" -p "$cfg" ipc call panel current 2>/dev/null)" = wifi ]; then echo "  ok: WLAN-Unterseite direkt geöffnet (wie Klick auf das Symbol in der Leiste)"
else echo "  FEHLER: Unterseite: $("$qs" -p "$cfg" ipc call panel current 2>/dev/null)"; seiten_ok=0; fi
ipc panel page audio; sleep 1.5; bild panel-ton
ipc panel close; sleep 1
schalter="$("$qs" -p "$cfg" ipc call panel toggles 2>/dev/null)"
if [[ ",$schalter," != *",bluetooth,"* ]] && [[ ",$schalter," == *",wifi,"* ]]; then echo "  ok: ohne Bluetooth-Adapter fehlt der Schalter ($schalter)"
else echo "  FEHLER: Schalter: $schalter"; seiten_ok=0; fi

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
    for seite in home bar look theme desktop dashboard panel dock system integrations laptop lock input monitors apps keybinds about; do
        ipc settings open "$seite"; sleep 2; bild "settings-$seite"
    done
    for q in blur clock battery; do
        vorher="$(grep -c "hypr-shell-probe search-first" "$T/qs.log" || true)"
        ipc settings search "$q"; sleep 1.5
        [ "$q" = blur ] && bild settings-suche
        if [ "$(grep -c "hypr-shell-probe search-first" "$T/qs.log" || true)" -gt "$vorher" ]; then echo "  ok: Suche findet \"$q\""
        else echo "  FEHLER: Suche findet \"$q\" nicht"; app_ok=0; fi
    done
    # Programme mitfärben: GTK steht immer da, Firefox nur, wenn installiert
    ipc settings open theme; sleep 2
    if test_ipc click setting-theme.apps.gtk && warte_auf .theme.apps.gtk false; then echo "  ok: Theme → Apps: GTK-Schalter landet in settings.json"
    else echo "  FEHLER: Schalter theme.apps.gtk ($(wert .theme))"; app_ok=0; fi
    if ! command -v firefox >/dev/null 2>&1; then
        if test_ipc click setting-theme.apps.firefox; then echo "  FEHLER: Firefox-Zeile da, obwohl Firefox fehlt"; app_ok=0
        else echo "  ok: ohne Firefox keine Firefox-Zeile"; fi
    fi
    test_ipc click setting-theme.apps.gtk && warte_auf .theme.apps.gtk true || true
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

# ---- Missa (aus: kein Panel, kein IPC-Ziel; an: Chat gegen den lokalen Testserver, Karte im Dashboard)
missa_ok=1
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target missa'; then
    echo "  FEHLER: Missa-Panel geladen, obwohl Missa aus ist"; missa_ok=0
else
    echo "  ok: Missa aus: kein Panel, kein IPC-Ziel"
fi
if command -v python3 >/dev/null 2>&1; then
    echo "---- Missa-Chat (Testserver) ----"
    mport=$(( 22000 + RANDOM % 20000 ))
    python3 "$REPO/tests/daten/missa-testserver.py" "$mport" "$T/missa.log" 2>/dev/null &
    pids+=("$!")
    sleep 1
    mkdir -p "$HOME/.local/share/hypr-shell/whisper" "$HOME/.local/share/hypr-shell/piper"
    touch "$HOME/.local/share/hypr-shell/whisper/ggml-base.bin" "$HOME/.local/share/hypr-shell/piper/de_DE-thorsten-medium.onnx"
    jq --arg u "http://127.0.0.1:$mport" '.missa.enabled = true | .missa.voice_enabled = true | .missa.url = $u' "$HOME/.config/hypr-shell/settings.json" > "$T/s.json" \
        && mv "$T/s.json" "$HOME/.config/hypr-shell/settings.json"
    echo test-key | "$HOME/.local/bin/shell-secrets" set MISSA_API_KEY
    KEINE_MELDUNG=1 "$HOME/.local/bin/shell-apply" --no-reload 2>/dev/null
    sleep 2.5
    if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target missa'; then
        ipc missa send "Was habe ich morgen?"; sleep 4.5; bild missa-chat
        letzt="$("$qs" -p "$cfg" ipc call missa lastText 2>/dev/null)"
        if [[ "$letzt" == "assistant: Hallo! Morgen"*"Zahnarzt"* ]]; then echo "  ok: Frage beantwortet (Antwort lief ein)"
        else echo "  FEHLER: Antwort: $letzt"; missa_ok=0; fi
        if [ "$("$qs" -p "$cfg" ipc call missa asking 2>/dev/null)" = false ]; then echo "  ok: ohne Rückfrage keine Knöpfe Yes/No"; else echo "  FEHLER: Yes/No ohne Rückfrage"; missa_ok=0; fi
        ipc missa send "eine rückfrage"; sleep 3.5; bild missa-rueckfrage
        if [ "$("$qs" -p "$cfg" ipc call missa asking 2>/dev/null)" = true ]; then echo "  ok: nach einer Rückfrage erscheinen Yes und No"; else echo "  FEHLER: keine Knöpfe nach der Rückfrage"; missa_ok=0; fi
        ipc missa send "langsam bitte"; sleep 1.2
        if [ "$("$qs" -p "$cfg" ipc call missa busy 2>/dev/null)" = true ]; then ipc missa cancel; sleep 0.5; fi
        if [ "$("$qs" -p "$cfg" ipc call missa busy 2>/dev/null)" = false ] && "$qs" -p "$cfg" ipc call missa lastText 2>/dev/null | grep -q "cancelled"; then
            echo "  ok: Antwort lässt sich abbrechen"
        else echo "  FEHLER: Abbrechen"; missa_ok=0; fi
        ipc missa close; sleep 1
        # mit Missa sprechen (Attrappen für Aufnahme, whisper.cpp und piper)
        ipc missa voice; sleep 0.4; bild missa-sprechen
        zustand="$("$qs" -p "$cfg" ipc call missa voiceState 2>/dev/null)"
        for _ in $(seq 1 30); do [ "$("$qs" -p "$cfg" ipc call missa voiceState 2>/dev/null)" = "" ] && break; sleep 0.3; done
        if [ "$zustand" = listening ] && jq -e 'select(.chat == "Was habe ich morgen vor?" and .modus == "sprache")' "$T/missa.log" >/dev/null 2>&1; then
            echo "  ok: gesprochener Satz steht im Chat und wird beantwortet (Sprechmodus)"
        else echo "  FEHLER: Sprechen: Zustand $zustand, Log: $(tail -n 2 "$T/missa.log")"; missa_ok=0; fi
        if [ -z "$(find "$XDG_RUNTIME_DIR" "$HOME" -name 'hypr-shell-voice-*.wav' 2>/dev/null)" ]; then echo "  ok: keine Audiodatei bleibt liegen"; else echo "  FEHLER: Audiodatei liegt noch"; missa_ok=0; fi
        # Missa-Agent: Glas-Karte für die Rückfrage (Stufe ask) und Schalter "Missa access" im Panel
        jq '.missa.agent_enabled = true' "$HOME/.config/hypr-shell/settings.json" > "$T/s.json" && mv "$T/s.json" "$HOME/.config/hypr-shell/settings.json"
        KEINE_MELDUNG=1 "$HOME/.local/bin/shell-apply" --no-reload 2>/dev/null; sleep 2
        ipc missaagent ask test-1 rechner_befehl "rm -rf ~/tmp/*.log"; sleep 1; bild missa-rueckfrage-karte
        if [ "$("$qs" -p "$cfg" ipc call missaagent waiting 2>/dev/null)" = "rechner_befehl: rm -rf ~/tmp/*.log" ]; then echo "  ok: Glas-Karte zeigt den Befehl wörtlich"
        else echo "  FEHLER: Rückfrage-Karte"; missa_ok=0; fi
        ipc missaagent deny
        for _ in $(seq 1 25); do [ "$(cat "$XDG_RUNTIME_DIR/hypr-shell-missa-answer-test-1" 2>/dev/null)" = no ] && break; sleep 0.2; done
        if [ -z "$("$qs" -p "$cfg" ipc call missaagent waiting 2>/dev/null)" ] && [ "$(cat "$XDG_RUNTIME_DIR/hypr-shell-missa-answer-test-1" 2>/dev/null)" = no ]; then echo "  ok: Esc/Deny lehnt ab"
        else echo "  FEHLER: Ablehnen"; missa_ok=0; fi
        ipc panel open; sleep 2; bild panel-missa
        if [[ ",$("$qs" -p "$cfg" ipc call panel toggles 2>/dev/null)," == *",missa,"* ]]; then echo "  ok: Schalter Missa access im Panel (Agent eingeschaltet)"
        else echo "  FEHLER: Schalter Missa access fehlt"; missa_ok=0; fi
        ipc panel close; sleep 1
        # Homelab, Kalender, Sensor (über denselben Testserver)
        jq --arg u "http://127.0.0.1:$mport" '.lab.enabled = true | .calendar.enabled = true | .calendar.url = ($u + "/caldav/") | .calendar.user = "kal"
            | .sensor.enabled = true | .sensor.url = ($u + "/sensor.json") | .sensor.field = "luft.co2" | .sensor.title = "CO2"' \
            "$HOME/.config/hypr-shell/settings.json" > "$T/s.json" && mv "$T/s.json" "$HOME/.config/hypr-shell/settings.json"
        echo kal-pw | "$HOME/.local/bin/shell-secrets" set CALDAV_PASSWORD
        KEINE_MELDUNG=1 "$HOME/.local/bin/shell-apply" --no-reload 2>/dev/null; sleep 2
        ipc dashboard open lab; sleep 3; bild dashboard-lab
        ipc dashboard open dashboard; sleep 3; bild dashboard-missa; ipc dashboard close; sleep 1
        missa_vorher="$("$qs" -p "$cfg" ipc call missa lastText 2>/dev/null)"
        if grep -q '"/api/homelab"' "$T/missa.log" && grep -q '"caldav"' "$T/missa.log"; then echo "  ok: Lab und Kalender lesen erst, wenn eingeschaltet und das Dashboard offen ist"
        else echo "  FEHLER: keine Abfrage für Lab/Kalender"; missa_ok=0; fi
    else
        echo "  FEHLER: Missa eingeschaltet, aber kein Panel"; missa_ok=0
    fi
fi

echo "---- Bilder und Symbole ----"
bereich dashboard-dashboard dashboard-avatar "Profilbild im Dashboard"
bereich dashboard-wallpaper wallpaper-card "erste Wallpaper-Karte"
[ -n "$im" ] && bereich dashboard-games games-cover "Cover im Tab Games"
bereich panel panel-avatar "Profilbild im Panel"
bereich panel app-icon "erstes App-Symbol im Panel"
bereich launcher launcher-first "erstes App-Symbol im Starter"
[ -f "$T/log-dashboard-missa" ] && bereich dashboard-missa missa-card "Missa-Karte im Dashboard"
[ -f "$T/log-dashboard-lab" ] && bereich dashboard-lab lab-vms "VMs im Tab Lab"
[ -f "$T/log-dashboard-missa" ] && bereich dashboard-missa calendar-event "Termin unter dem Kalender"
if command -v cliphist >/dev/null 2>&1 && [ -n "$im" ]; then bereich zwischenablage clipboard-image "Bild-Vorschau in der Zwischenablage"; fi

# ohne ~/.face: Anfangsbuchstabe statt Bild
if [ -n "$im" ]; then
    pkill -f -- "-p $cfg" 2>/dev/null || true   # auch den Kindprozess von Quickshell
    sleep 1
    rm -f "$HOME/.face"
    starte_qs
    ipc panel open; sleep 2; bild panel-ohne-face
    ipc panel close; sleep 1
    bereich panel-ohne-face panel-avatar "Anfangsbuchstabe ohne ~/.face"
    # nach dem Neustart (wie nach einer Neuanmeldung) läuft dieselbe Missa-Sitzung weiter
    if [ -f "$T/missa.log" ]; then
        if [ -n "${missa_vorher:-}" ] && [ "$("$qs" -p "$cfg" ipc call missa lastText 2>/dev/null)" = "$missa_vorher" ] \
            && [ "$(jq -r 'select(.session) | .session' "$T/missa.log" | sort -u | wc -l)" = 1 ]; then
            echo "  ok: nach dem Neustart: gleicher Verlauf und dieselbe Sitzung ($(jq -r 'select(.session) | .session' "$T/missa.log" | head -n1))"
        else echo "  FEHLER: Missa-Sitzung nach dem Neustart"; missa_ok=0; fi
    fi
    # nach dem Neustart (wie nach einer Neuanmeldung) steht die Uhr am gespeicherten Platz
    if [ "$edit_ok" -eq 1 ] && [ "$(wert .desktop.clock.x)" = 0.3 ]; then
        cx="$(grep -o "hypr-shell-probe desktop-clock .*" "$T/qs.log" | tail -n1 | awk '{print $3}')"
        if [ "${cx:-0}" -ge 570 ] && [ "${cx:-0}" -le 590 ]; then echo "  ok: Uhr steht nach dem Neustart am neuen Platz (x = $cx)"
        else echo "  FEHLER: Uhr nach dem Neustart bei x = ${cx:-?} statt 576"; edit_ok=0; fi
    fi
fi

# ---- Dock
echo "---- Dock ----"
dock_ok=1
dk() { "$qs" -p "$cfg" ipc call dock "$@" 2>/dev/null; }
vergleich() { if command -v magick >/dev/null 2>&1; then magick compare "$@"; else compare "$@"; fi; }
if "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target dock'; then
    if [ "$(dk count)" = 1 ] && [ "$(dk visible)" = true ]; then echo "  ok: genau ein Dock auf dem Bildschirm"
    else echo "  FEHLER: Dock-Fenster: $(dk count)"; dock_ok=0; fi
    g="$(dk geometry)"
    echo "  Lage: $g"
    if jq -e '(.x - ((.windowWidth - .width) / 2) | fabs) <= 1 and (.windowHeight - .y - .height) == 10 and .radius == 22 and .icon == 48' <<<"$g" >/dev/null 2>&1; then
        echo "  ok: mittig unten, 10 px vom Rand, Rundung 22, Symbole 48 px"
    else echo "  FEHLER: Lage oder Masse des Docks"; dock_ok=0; fi
    for _ in $(seq 1 20); do [[ "$(dk items)" == *folder:* ]] && break; sleep 0.3; done
    l="$(dk items)"
    echo "  Einträge: $l"
    if [[ "$l" == app:org.gnome.Nautilus,app:kitty,app:firefox,separator,folder:~/Downloads* ]]; then echo "  ok: Standardliste (Dateimanager, Terminal, Browser, Trenner, Downloads …)"
    else echo "  FEHLER: Standardliste"; dock_ok=0; fi
    for paar in kitty:kitty firefox:firefox org.example.FlatNotes:org.example.FlatNotes jetbrains-idea:idea "steam_app_570:Dota 2" unbekannt-xyz:; do
        a="${paar%%:*}" e="${paar#*:}"
        r="$(dk resolve "$a")"
        if [ "$r" = "$e" ]; then echo "  ok: Zuordnung $a → ${e:-(eigenes Symbol)}"
        else echo "  FEHLER: Zuordnung $a → \"$r\" statt \"$e\""; dock_ok=0; fi
    done
    # ein echtes Fenster (Quickshell-Testfenster): erscheint als laufend
    printf 'import Quickshell\nimport QtQuick\nFloatingWindow { title: "Dock test window"; implicitWidth: 300; implicitHeight: 200; color: "#335" }\n' > "$T/fenster.qml"
    "$qs" -p "$T/fenster.qml" > "$T/fenster.log" 2>&1 &
    fpid="$!"; pids+=("$fpid")
    for _ in $(seq 1 30); do dk items | grep -q '\*1' && break; sleep 0.3; done
    l2="$(dk items)"
    if grep -q '\*1' <<<"$l2"; then echo "  ok: laufendes Fenster erscheint im Dock ($l2)"
    else echo "  FEHLER: Fenster erscheint nicht im Dock ($l2)"; dock_ok=0; fi
    sleep 1; bild dock
    kill "$fpid" 2>/dev/null || true
    for _ in $(seq 1 30); do dk items | grep -q '\*1' || break; sleep 0.3; done
    if ! dk items | grep -q '\*1'; then echo "  ok: geschlossenes Fenster verschwindet wieder"
    else echo "  FEHLER: geschlossenes Fenster bleibt"; dock_ok=0; fi
    # ---- Bedienung: Menü, Ziehen, Lösen, Tastatur, Zähler, kaputte Liste
    m="$(dk menu 2)"
    if [ "$m" = "New window|New Private Window|Remove from Dock" ]; then echo "  ok: Rechtsklick-Menü mit den Desktop-Aktionen ($m)"
    else echo "  FEHLER: Menü: $m"; dock_ok=0; fi
    dk drag 0 2 >/dev/null
    for _ in $(seq 1 30); do [ "$(wert '.dock.items[0].desktop_id')" = '"kitty"' ] && break; sleep 0.3; done
    if [ "$(wert '[.dock.items[].desktop_id] | .[0:3]')" = '["kitty","firefox","org.gnome.Nautilus"]' ]; then echo "  ok: Ziehen sortiert um und speichert dock.items"
    else echo "  FEHLER: Umsortieren: $(wert '.dock.items')"; dock_ok=0; fi
    sleep 1
    "$HOME/.local/bin/shell-quickshell" restart >/dev/null 2>&1 || true
    for _ in $(seq 1 40); do [ "$(dk count)" = 1 ] && break; sleep 0.3; done
    qspid="$(pgrep -f -- "-p $cfg" | head -n1)"
    if [[ "$(dk items)" == app:kitty,app:firefox,app:org.gnome.Nautilus* ]]; then echo "  ok: Reihenfolge bleibt nach dem Neustart"
    else echo "  FEHLER: nach dem Neustart: $(dk items)"; dock_ok=0; fi
    dk dragOut 1 >/dev/null
    for _ in $(seq 1 30); do [[ "$(dk items)" != *app:firefox* ]] && break; sleep 0.3; done
    if [[ "$(dk items)" != *app:firefox* ]] && [ "$(wert '[.dock.items[] | select(.desktop_id == "firefox")] | length')" = 0 ]; then echo "  ok: Herausziehen löst Firefox"
    else echo "  FEHLER: Lösen: $(dk items)"; dock_ok=0; fi
    rmdir "$HOME/Downloads"; dk refresh; sleep 1
    if [[ "$(dk items)" != *folder:* ]]; then echo "  ok: fehlender Ordner erscheint nicht"; else echo "  FEHLER: Ordner trotz Fehlen: $(dk items)"; dock_ok=0; fi
    mkdir -p "$HOME/Downloads"; dk refresh; sleep 1
    k0="$(dk key "")"; dk focus >/dev/null; sleep 0.5
    k1="$(dk key "")"; k2="$(dk key Right)"; k3="$(dk key ShiftF10)"; k4="$(dk key Escape)"; k5="$(dk key Escape)"
    echo "  Tastatur: $k0 → focus $k1 → Right $k2 → SHIFT+F10 $k3 → Esc $k4 → Esc $k5"
    if [ "$k0" = off ] && [ "$k1" = on:app:kitty ] && [ "$k2" = on:app:org.gnome.Nautilus ] && [[ "$k3" == *:menu ]] \
        && [ "$k4" = on:app:org.gnome.Nautilus ] && [ "$k5" = off ]; then
        echo "  ok: Tastatur: Pfeile wählen, SHIFT+F10 öffnet das Menü, Esc verlässt"
    else echo "  FEHLER: Tastatur"; dock_ok=0; fi
    # was auch passiert: die Tastatur gehört danach nicht mehr dem Dock
    dk key Escape >/dev/null; dk key Escape >/dev/null
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a kitty "Build" "fertig" 2>/dev/null; sleep 1.5
        if [ "$(dk badge 0)" = 1 ]; then echo "  ok: Zähler für eine Meldung von kitty"; else echo "  FEHLER: Zähler $(dk badge 0)"; dock_ok=0; fi
    fi
    jq '.dock.items = "kaputt"' "$HOME/.config/hypr-shell/settings.json" > "$T/s.json" && cp "$T/s.json" "$HOME/.config/hypr-shell/settings.json"
    "$HOME/.local/bin/shell-apply" >/dev/null 2>&1 || true
    sleep 2
    if [[ "$(dk items)" == app:org.gnome.Nautilus,app:kitty,app:firefox* ]] && kill -0 "$qspid" 2>/dev/null; then echo "  ok: kaputte dock.items: Standardliste, kein Absturz"
    else echo "  FEHLER: kaputte dock.items: $(dk items)"; dock_ok=0; fi
    "$HOME/.local/bin/shell-set" reset dock.items >/dev/null 2>&1 || true
    sleep 1

    # ---- Bewegung und Verstecken
    st() { dk smartTest "$1"; }
    if [ "$(st '{"dock":{"x":760,"y":1006,"width":400,"height":64},"windows":[{"x":0,"y":0,"width":1920,"height":1040}]}')" = true ] \
        && [ "$(st '{"dock":{"x":760,"y":1006,"width":400,"height":64},"windows":[{"x":0,"y":0,"width":1920,"height":1000}]}')" = false ] \
        && [ "$(st '{"dock":{"x":760,"y":1006,"width":400,"height":64},"windows":[{"x":700,"y":900,"width":200,"height":300,"sichtbar":false}]}')" = false ] \
        && [ "$(st '{"dock":{"x":760,"y":1006,"width":400,"height":64},"windows":[{"x":1160,"y":900,"width":200,"height":300}]}')" = false ]; then
        echo "  ok: smart: überdeckt nur, wenn ein sichtbares Fenster die Fläche schneidet"
    else echo "  FEHLER: smart-Logik"; dock_ok=0; fi
    "$HOME/.local/bin/shell-set" dock.anim_ms 0 >/dev/null 2>&1; sleep 1.5
    if [ "$(dk animMs)" = 0 ]; then echo "  ok: anim_ms 0 schaltet die Animationen ab"; else echo "  FEHLER: anim_ms $(dk animMs)"; dock_ok=0; fi
    "$HOME/.local/bin/shell-quickshell" ipc shell gaming true >/dev/null 2>&1
    "$HOME/.local/bin/shell-set" reset dock.anim_ms >/dev/null 2>&1; sleep 1.5
    if [ "$(dk animMs)" = 0 ]; then echo "  ok: Gaming-Modus: keine Dock-Animationen"; else echo "  FEHLER: Gaming-Modus anim $(dk animMs)"; dock_ok=0; fi
    "$HOME/.local/bin/shell-quickshell" ipc shell gaming false >/dev/null 2>&1; sleep 0.5
    if [ "$(dk animMs)" = 180 ]; then echo "  ok: danach wieder 180 ms"; else echo "  FEHLER: anim nach Gaming $(dk animMs)"; dock_ok=0; fi
    "$HOME/.local/bin/shell-set" dock.autohide always >/dev/null 2>&1; sleep 2
    if [ "$(dk geometry | jq .hidden)" = true ]; then echo "  ok: autohide always: ohne Maus versteckt"; else echo "  FEHLER: always versteckt nicht"; dock_ok=0; fi
    bild dock-versteckt-always
    "$HOME/.local/bin/shell-set" reset dock.autohide >/dev/null 2>&1; sleep 1.5
    if [ "$(dk geometry | jq .hidden)" = false ]; then echo "  ok: smart ohne überdeckendes Fenster: sichtbar"; else echo "  FEHLER: smart versteckt ohne Grund"; dock_ok=0; fi
    # 20 Symbole (Ordner): passt ohne Scrollen, Vergrösserung schnell genug
    for i in $(seq 1 20); do mkdir -p "$HOME/dock-test/o$i"; done
    "$HOME/.local/bin/shell-set" dock.items "$(jq -nc '[range(1;21) | {type: "folder", desktop_id: "", path: "~/dock-test/o\(.)"}]')" >/dev/null 2>&1
    for _ in $(seq 1 30); do [ "$(dk items | tr ',' '\n' | grep -c folder)" = 20 ] && break; sleep 0.3; done
    dauer="$(dk sweep 120)"
    echo "  20 Symbole: $(dk items | tr ',' '\n' | grep -c folder) Ordner, 120 Mausschritte in ${dauer} ms"
    if [ "$(dk items | tr ',' '\n' | grep -c folder)" = 20 ] && [ "${dauer:-9999}" -lt 1200 ]; then echo "  ok: Vergrösserung mit 20 Symbolen unter 10 ms je Schritt"
    else echo "  FEHLER: 20 Symbole ($dauer ms)"; dock_ok=0; fi
    bild dock-20
    "$HOME/.local/bin/shell-set" reset dock.items >/dev/null 2>&1; sleep 1

    # ---- Einstellungen: Seite Dock, shell-set wirkt sofort, Voreinstellung aus der App, Export/Reset/Import
    "$HOME/.local/bin/shell-set" dock.icon_size 64 >/dev/null 2>&1
    for _ in $(seq 1 30); do [ "$(dk geometry | jq .icon)" = 64 ] && break; sleep 0.3; done
    if [ "$(dk geometry | jq .icon)" = 64 ] && [ "$("$HOME/.local/bin/shell-set" get dock.icon_size)" = 64 ]; then echo "  ok: shell-set dock.icon_size 64 wirkt sofort am Dock"
    else echo "  FEHLER: icon_size am Dock $(dk geometry | jq .icon)"; dock_ok=0; fi
    ipc settings open dock; sleep 2; bild settings-dock
    # Knopf da (Probe im Log); Klick über die Test-Schnittstelle, sonst derselbe Befehl, den der Knopf ausführt
    knopf="$(grep -c 'hypr-shell-probe dock-preset-island' "$T/qs.log" || true)"
    geklickt=nein; test_ipc click dock-preset-island && geklickt=ja
    [ "$geklickt" = ja ] || "$HOME/.local/bin/shell-dock" preset island >/dev/null 2>&1
    if [ "${knopf:-0}" -ge 1 ] && warte_auf .dock.preset '"island"' 60; then
        for _ in $(seq 1 30); do [ "$(dk geometry | jq .icon)" = 56 ] && break; sleep 0.3; done
        if [ "$(dk geometry | jq .icon)" = 56 ] && [ "$(wert '.dock.items')" = null ]; then echo "  ok: Knopf island auf der Seite, Voreinstellung wirkt sofort (Klick: $geklickt), dock.items unberührt"
        else echo "  FEHLER: island: Symbol $(dk geometry | jq .icon), items $(wert '.dock.items')"; dock_ok=0; fi
    else echo "  FEHLER: Knopf island (geklickt: $geklickt, preset: $(wert .dock.preset), Probe: $(grep -c 'hypr-shell-probe dock-preset-island' "$T/qs.log"))"; dock_ok=0; fi
    sleep 1; bild dock-island
    ipc settings close; sleep 1
    sleep 2
    if [ -n "$im" ]; then grim -g "$(dk geometry | jq -r '"\((1920 - .windowWidth) / 2 + .x - 20 | floor),\(1080 - .windowHeight + .y - 20 | floor) \(.width + 40)x\(.height + 40)"')" "$T/dock-vorher.png"; fi
    g1="$(dk geometry)"
    "$HOME/.local/bin/shell-dock" export "$T/dock-export.json" >/dev/null 2>&1
    "$HOME/.local/bin/shell-dock" reset >/dev/null 2>&1; sleep 2
    g2="$(dk geometry)"
    "$HOME/.local/bin/shell-dock" import "$T/dock-export.json" >/dev/null 2>&1
    for _ in $(seq 1 30); do [ "$(dk geometry)" = "$g1" ] && break; sleep 0.3; done
    # Symbole laden asynchron: warten, bis alles gezeichnet ist
    sleep 3
    if [ "$(dk geometry)" = "$g1" ] && [ "$g2" != "$g1" ]; then echo "  ok: Export, Reset all und Import: dieselbe Lage und Grösse"
    else echo "  FEHLER: nach Import $(dk geometry) statt $g1"; dock_ok=0; fi
    if [ -n "$im" ]; then
        grim -g "$(jq -r '"\((1920 - .windowWidth) / 2 + .x - 20 | floor),\(1080 - .windowHeight + .y - 20 | floor) \(.width + 40)x\(.height + 40)"' <<<"$g1")" "$T/dock-nachher.png"
        # kleine Toleranz für Kantenglättung; die Lage prüft schon der Vergleich der Geometrie
        abw="$(vergleich -metric AE -fuzz 8% "$T/dock-vorher.png" "$T/dock-nachher.png" null: 2>&1 | cut -d' ' -f1 | cut -d. -f1)"
        flaeche="$("$im" "$T/dock-vorher.png" -format '%[fx:w*h]' info: 2>/dev/null || echo 100000)"
        if [ -n "$abw" ] && [ "$abw" -le $(( ${flaeche%.*} / 200 )) ]; then echo "  ok: Screenshot nach dem Import gleicht dem davor ($abw Pixel abweichend)"
        else echo "  FEHLER: Screenshot nach dem Import anders ($abw Pixel)"; dock_ok=0; fi
    fi
    echo '{"dock": {"icon_size": 9999' > "$T/kaputt.json"
    if ! "$HOME/.local/bin/shell-dock" import "$T/kaputt.json" >/dev/null 2>&1 && [ "$(dk geometry)" = "$g1" ] && kill -0 "$qspid" 2>/dev/null; then
        echo "  ok: kaputte Datei abgelehnt, Dock unverändert"
    else echo "  FEHLER: kaputte Datei"; dock_ok=0; fi
    for p in minimal compact full mac; do
        "$HOME/.local/bin/shell-dock" preset "$p" >/dev/null 2>&1; sleep 2
        # minimal versteckt sich ohne Maus: für das Bild mit der Tastatur sichtbar halten
        [ "$p" = minimal ] && { dk focus >/dev/null; sleep 1; }
        bild "dock-$p"
        [ "$p" = minimal ] && dk key Escape >/dev/null
    done

    # ---- Zusammenspiel: Leiste, Panels, Vollbild, zweiter Bildschirm, Bildwechsel
    ds() { dk state | jq -r "$1"; }
    export SWAYSOCK="${SWAYSOCK:-$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit)}"
    unten() { grim -g "0,1050 1920x30" "$1"; }
    if [ "$(ds .exclusion)" = ignore ]; then echo "  ok: Leiste oben, Dock unten: Dock schwebt frei"; else echo "  FEHLER: exclusion $(ds .exclusion)"; dock_ok=0; fi
    if pgrep -x waybar >/dev/null 2>&1 && [ -n "$im" ]; then
        "$HOME/.local/bin/shell-set" bar.position bottom >/dev/null 2>&1; sleep 3
        if [ "$(ds .exclusion)" = avoid ]; then echo "  ok: Leiste unten: Dock hält ihren Abstand ein"; else echo "  FEHLER: avoid $(ds .exclusion)"; dock_ok=0; fi
        for p in mac compact island full; do
            "$HOME/.local/bin/shell-dock" preset "$p" >/dev/null 2>&1; sleep 2
            unten "$T/bar-mit.png"; dk close; sleep 1; unten "$T/bar-ohne.png"; dk open; sleep 1
            if [ "$(vergleich -metric AE "$T/bar-mit.png" "$T/bar-ohne.png" null: 2>&1 | cut -d' ' -f1)" = 0 ]; then echo "  ok: $p: Dock überdeckt die Leiste nicht"
            else echo "  FEHLER: $p: Dock überdeckt die Leiste"; dock_ok=0; fi
        done
        bild dock-leiste-unten
        "$HOME/.local/bin/shell-dock" preset mac >/dev/null 2>&1
        "$HOME/.local/bin/shell-set" reset bar.position >/dev/null 2>&1; sleep 2
    fi
    ipc dashboard open dashboard; sleep 1
    if [ "$(ds .input)" = false ]; then echo "  ok: Dashboard offen: Dock nimmt keine Eingaben an"; else echo "  FEHLER: Dock nimmt bei offenem Dashboard Eingaben an"; dock_ok=0; fi
    ipc dashboard close; sleep 1
    if [ "$(ds .input)" = true ]; then echo "  ok: Dashboard zu: Dock wieder bedienbar"; else echo "  FEHLER: Dock nach dem Dashboard"; dock_ok=0; fi
    "$HOME/.local/bin/shell-quickshell" ipc shell gaming true >/dev/null 2>&1; sleep 1
    if [ "$(ds .shown)" = false ]; then echo "  ok: Gaming-Modus: Dock weg"; else echo "  FEHLER: Dock im Gaming-Modus sichtbar"; dock_ok=0; fi
    "$HOME/.local/bin/shell-quickshell" ipc shell gaming false >/dev/null 2>&1; sleep 1
    if [ "$(ds .shown)" = true ]; then echo "  ok: danach wieder da"; else echo "  FEHLER: Dock nach dem Gaming-Modus"; dock_ok=0; fi
    if command -v swaymsg >/dev/null 2>&1 && [ -n "$SWAYSOCK" ]; then
        "$qs" -p "$T/fenster.qml" > "$T/fenster2.log" 2>&1 &
        fpid="$!"; pids+=("$fpid"); sleep 2
        swaymsg '[title="Dock test window"] fullscreen enable' >/dev/null 2>&1; sleep 1
        if [ "$(ds .fullscreen)" = true ] && [ "$(ds .shown)" = false ]; then echo "  ok: Vollbild-Fenster: Dock weg"; else echo "  FEHLER: Vollbild: $(dk state)"; dock_ok=0; fi
        swaymsg '[title="Dock test window"] fullscreen disable' >/dev/null 2>&1; sleep 1
        if [ "$(ds .shown)" = true ]; then echo "  ok: Vollbild beendet: Dock wieder da"; else echo "  FEHLER: nach dem Vollbild"; dock_ok=0; fi
        kill "$fpid" 2>/dev/null || true
        # zweiter Bildschirm: an- und abstecken
        swaymsg create_output >/dev/null 2>&1; sleep 2
        n2="$(dk count)"
        if [ "$n2" = 2 ]; then echo "  ok: zweiter Bildschirm: genau ein zusätzliches Dock"; else echo "  FEHLER: zwei Bildschirme, $n2 Docks"; dock_ok=0; fi
        "$HOME/.local/bin/shell-set" dock.monitor primary >/dev/null 2>&1; sleep 2
        if [ "$(dk count)" = 1 ]; then echo "  ok: dock.monitor primary: ein Dock"; else echo "  FEHLER: primary: $(dk count)"; dock_ok=0; fi
        "$HOME/.local/bin/shell-set" reset dock.monitor >/dev/null 2>&1; sleep 2
        zweiter="$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '.[] | select(.name != "HEADLESS-1") | .name' | head -n1)"
        [ -n "$zweiter" ] && swaymsg output "$zweiter" unplug >/dev/null 2>&1; sleep 2
        if kill -0 "$qspid" 2>/dev/null && [ "$(dk count)" = 1 ]; then echo "  ok: Abstecken: kein Absturz, ein Dock"; else echo "  FEHLER: nach dem Abstecken: $(dk count)"; dock_ok=0; fi
    fi
    # Bildwechsel färbt das Dock um; helles und dunkles Bild für die Doku
    if command -v awww >/dev/null 2>&1 && command -v matugen >/dev/null 2>&1 && [ -n "$im" ]; then
        vorher_glas="$(ds .glass)"
        "$im" -size 1920x1080 gradient:'#f2efe6'-'#d9e4f0' "$HOME/Pictures/Wallpapers/test-hell.png"
        "$im" -size 1920x1080 gradient:'#10131a'-'#2b1f3a' "$HOME/Pictures/Wallpapers/test-dunkel.png"
        "$HOME/.local/bin/shell-wallpaper" "$HOME/Pictures/Wallpapers/test-hell.png" >/dev/null 2>&1; sleep 3
        bild dock-hell
        if [ "$(ds .glass)" != "$vorher_glas" ]; then echo "  ok: Bildwechsel färbt das Dock um"; else echo "  FEHLER: Dock-Farbe bleibt nach dem Bildwechsel"; dock_ok=0; fi
        "$HOME/.local/bin/shell-wallpaper" "$HOME/Pictures/Wallpapers/test-dunkel.png" >/dev/null 2>&1; sleep 3
        bild dock-dunkel
        "$HOME/.local/bin/shell-wallpaper" "$HOME/Pictures/Wallpapers/test-bunt.png" >/dev/null 2>&1; sleep 2
    fi

    # CPU in Ruhe: Quickshell 10 s messen, mit und ohne Dock
    cpu() { local a b; a=$(awk '{print $14+$15}' "/proc/$qspid/stat"); sleep 10; b=$(awk '{print $14+$15}' "/proc/$qspid/stat"); awk -v d=$((b - a)) -v hz="$(getconf CLK_TCK)" 'BEGIN { printf "%.2f", d / hz / 10 * 100 }'; }
    mit="$(cpu)"
    # Abschalten: kein Dock-Fenster mehr, die Fläche sieht aus wie ohne Dock
    [ -n "$im" ] && grim -g "560,980 800x100" "$T/dock-an.png"
    dk hide; sleep 1
    [ -n "$im" ] && grim -g "560,980 800x100" "$T/dock-versteckt.png"
    dk open
    "$HOME/.local/bin/shell-set" dock.enabled false >/dev/null 2>&1
    for _ in $(seq 1 30); do "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target dock' || break; sleep 0.3; done
    if ! "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target dock'; then echo "  ok: dock.enabled false: kein Dock-Fenster"
    else echo "  FEHLER: Dock trotz dock.enabled false"; dock_ok=0; fi
    sleep 1
    ohne="$(cpu)"
    echo "  CPU in Ruhe (ganze Oberfläche, 10 s): mit Dock $mit %, ohne Dock $ohne %"
    if awk -v a="$mit" -v b="$ohne" 'BEGIN { exit !(a - b <= 1.0) }'; then echo "  ok: Dock braucht in Ruhe höchstens 1 % CPU"
    else echo "  FEHLER: Dock braucht in Ruhe mehr als 1 % CPU"; dock_ok=0; fi
    if [ -n "$im" ]; then
        grim -g "560,980 800x100" "$T/dock-aus.png"
        if [ "$(vergleich -metric AE "$T/dock-aus.png" "$T/dock-versteckt.png" null: 2>&1 | cut -d' ' -f1)" = 0 ] \
            && [ "$(vergleich -metric AE "$T/dock-aus.png" "$T/dock-an.png" null: 2>&1 | cut -d' ' -f1)" != 0 ]; then
            echo "  ok: ohne Dock gleicht der Bildschirm dem ohne Dock-Fenster"
        else echo "  FEHLER: Bildschirm ohne Dock nicht wie vorher"; dock_ok=0; fi
    fi
    "$HOME/.local/bin/shell-set" dock.enabled true >/dev/null 2>&1
    for _ in $(seq 1 30); do "$qs" -p "$cfg" ipc show 2>/dev/null | grep -q 'target dock' && break; sleep 0.3; done
    if [ "$(dk count)" = 1 ]; then echo "  ok: wieder eingeschaltet: ein Dock"; else echo "  FEHLER: Dock nach dem Einschalten"; dock_ok=0; fi
else
    echo "  FEHLER: kein IPC-Ziel dock (Dock nicht geladen)"; dock_ok=0
fi
if grep -E "dock/[A-Za-z]+\.qml" "$T/qs.log" | grep -v "hypr-shell-probe"; then echo "  FEHLER: Warnungen aus dock/ im Log"; dock_ok=0; fi


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
[ "$missa_ok" -eq 1 ] || { echo "FEHLER: Missa (siehe oben)"; exit 1; }
[ "$spick_ok" -eq 1 ] || { echo "FEHLER: Kürzel-Spickzettel (siehe oben)"; exit 1; }
[ "$seiten_ok" -eq 1 ] || { echo "FEHLER: Unterseiten im Panel (siehe oben)"; exit 1; }
[ "$uebersicht_ok" -eq 1 ] || { echo "FEHLER: Fenster-Übersicht (siehe oben)"; exit 1; }
[ "$clip_ok" -eq 1 ] || { echo "FEHLER: Zwischenablage (siehe oben)"; exit 1; }
[ "$power_ok" -eq 1 ] || { echo "FEHLER: Anzeige oder Power-Menü (siehe oben)"; exit 1; }
[ "$note_ok" -eq 1 ] || { echo "FEHLER: Benachrichtigungen (siehe oben)"; exit 1; }
[ "$starter_ok" -eq 1 ] || { echo "FEHLER: Starter (siehe oben)"; exit 1; }
[ "$panel_ok" -eq 1 ] || { echo "FEHLER: mehr als ein Panel offen (siehe oben)"; exit 1; }
[ "$dock_ok" -eq 1 ] || { echo "FEHLER: Dock (siehe oben)"; exit 1; }
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
