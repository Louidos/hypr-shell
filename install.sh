#!/usr/bin/env bash
# hypr-shell Installer
#
#   ./install.sh                 installieren (fragt einmal nach)
#   ./install.sh --yes           ohne Rückfrage
#   ./install.sh --dry-run       nur anzeigen, was passieren würde, nichts ändern
#   ./install.sh --no-packages   keine Pakete installieren, nur Dateien kopieren
#   ./install.sh --restore [DIR] Stand vor der letzten Installation wiederherstellen
#   ./install.sh --uninstall     alle Dateien von hypr-shell entfernen, Ursprungszustand zurück
#
# Jede Datei, die ersetzt wird, landet vorher in ~/.config/hypr-shell-backup-<Zeit>/.
# Nie als root starten; sudo wird nur für pacman benutzt.
# Meldungen zeigen Pfade bewusst mit ~ an:
# shellcheck disable=SC2088
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(tr -d '[:space:]' < "$REPO/VERSION")"
CONF="$HOME/.config"
DATA="$HOME/.local/share/hypr-shell"
BIN="$HOME/.local/bin"
WALLS="$HOME/Pictures/Wallpapers"
QS_DIR="$CONF/quickshell/hypr-shell"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$CONF/hypr-shell-backup-$STAMP"
MANIFEST="$DATA/installiert.txt"

YES=0
DRY=0
NOPKG=0
MODE=install
RESTORE_DIR=""

# Pakete (Namen werden vor der Installation mit pacman -Si / paru -Si geprüft)
PAKETE=(
    hyprland hyprlock hypridle xdg-desktop-portal-hyprland hyprpolkitagent
    quickshell waybar swaync rofi awww matugen kitty cava
    grim slurp wl-clipboard libnotify jq playerctl brightnessctl pamixer swayosd
    power-profiles-daemon networkmanager bluez bluez-utils nautilus xdg-user-dirs imagemagick
    papirus-icon-theme bibata-cursor-theme-bin
    ttf-jetbrains-mono-nerd inter-font noto-fonts noto-fonts-emoji
)
# Ausweichnamen, falls ein Paket anders heisst
declare -A ALTERNATIVEN=(
    [quickshell]="quickshell-git"
    [swaync]="swaynotificationcenter"
    [awww]="awww-bin awww-git"
    [matugen]="matugen-bin matugen-git"
    [swayosd]="swayosd-git"
    [bibata-cursor-theme-bin]="bibata-cursor-theme"
    [inter-font]="ttf-inter"
)
# Programme, die am Ende da sein müssen (Programm:Paket)
PROGRAMME=(
    Hyprland:hyprland hyprlock:hyprlock hypridle:hypridle qs:quickshell waybar:waybar
    swaync:swaync rofi:rofi awww:awww awww-daemon:awww matugen:matugen kitty:kitty
    grim:grim slurp:slurp wl-copy:wl-clipboard notify-send:libnotify jq:jq playerctl:playerctl
    brightnessctl:brightnessctl pamixer:pamixer swayosd-server:swayosd swayosd-client:swayosd
    powerprofilesctl:power-profiles-daemon nmcli:networkmanager bluetoothctl:bluez-utils
    nautilus:nautilus
)
# Dateien, die nur angelegt werden, wenn sie fehlen (vom Benutzer oder von matugen erzeugt)
NUR_WENN_FEHLT=(
    "$CONF/hypr/hypr-shell-colors.lua"
    "$CONF/hypr/hyprlock-colors.conf"
    "$CONF/kitty/colors.conf"
    "$CONF/rofi/colors.rasi"
    "$CONF/swaync/colors.css"
    "$CONF/waybar/colors.css"
    "$CONF/hypr-shell/colors.json"
    "$CONF/hypr-shell/settings.json"
)

# ---------------------------------------------------------------- Hilfsfunktionen

if [ -t 1 ]; then FETT=$'\e[1m'; GRUEN=$'\e[32m'; GELB=$'\e[33m'; ROT=$'\e[31m'; AUS=$'\e[0m'
else FETT=""; GRUEN=""; GELB=""; ROT=""; AUS=""; fi

info()   { printf '%s==>%s %s\n' "$FETT" "$AUS" "$*"; }
ok()     { printf '  %s✓%s %s\n' "$GRUEN" "$AUS" "$*"; }
warnung(){ printf '  %s!%s %s\n' "$GELB" "$AUS" "$*" >&2; }
fehler() { printf '%sFehler:%s %s\n' "$ROT" "$AUS" "$*" >&2; exit 1; }
probe()  { printf '  [Probelauf] %s\n' "$*"; }

hilfe() {
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

ja_nein() {
    [ "$YES" -eq 1 ] && return 0
    [ "$DRY" -eq 1 ] && return 0
    local antwort
    read -r -p "$1 [j/N] " antwort || return 1
    [[ "$antwort" =~ ^[jJyY] ]]
}

enthaelt() {
    local x="$1"; shift
    local e
    for e in "$@"; do [ "$e" = "$x" ] && return 0; done
    return 1
}

# ---------------------------------------------------------------- Argumente

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) YES=1 ;;
        --dry-run|-n) DRY=1 ;;
        --no-packages) NOPKG=1 ;;
        --restore)
            MODE=restore
            if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then RESTORE_DIR="$2"; shift; fi
            ;;
        --uninstall) MODE=uninstall ;;
        -h|--help) hilfe ;;
        *) fehler "Unbekannte Option: $1 (siehe ./install.sh --help)" ;;
    esac
    shift
done

if [ "$(id -u)" -eq 0 ] && [ "${HYPR_SHELL_ALLOW_ROOT:-0}" != 1 ]; then
    fehler "Bitte nicht als root starten. sudo wird nur für pacman verwendet."
fi

# ---------------------------------------------------------------- Dateien mit Sicherung

# Eintrag in einer Liste der Sicherung vermerken
vermerke() { # datei text
    [ "$DRY" -eq 1 ] && return 0
    mkdir -p "$BACKUP"
    printf '%s\n' "$2" >> "$BACKUP/$1"
}

sichere() { # pfad (Datei oder Symlink) -> Sicherung
    local ziel="$1" rel="${1#"$HOME"/}"
    if [ "$DRY" -eq 1 ]; then probe "sichern: ~/$rel"; return 0; fi
    mkdir -p "$BACKUP/dateien/$(dirname "$rel")"
    cp -P -p "$ziel" "$BACKUP/dateien/$rel"
}

# Ein Konfigurationsordner, der ein Symlink ist (z. B. aus einem Dotfiles-Repo),
# wird gesichert und durch einen echten Ordner ersetzt, damit nie in fremde Pfade geschrieben wird.
echter_ordner() { # pfad
    local d="$1"
    if [ -L "$d" ]; then
        warnung "~/${d#"$HOME"/} ist ein Link auf $(readlink "$d") – wird gesichert und durch einen eigenen Ordner ersetzt."
        vermerke links.txt "$d"
        if [ "$DRY" -eq 1 ]; then probe "Link sichern und durch Ordner ersetzen: ~/${d#"$HOME"/}"; return 0; fi
        local rel="${d#"$HOME"/}"
        mkdir -p "$BACKUP/links/$(dirname "$rel")"
        cp -P "$d" "$BACKUP/links/$rel"
        rm "$d"
        mkdir -p "$d"
        # bisherigen Inhalt übernehmen (als Kopie, der Dotfiles-Ordner bleibt unberührt)
        cp -a "$(readlink -f "$BACKUP/links/$rel")/." "$d/" 2>/dev/null || true
    fi
}

GEAENDERT=0
NEU=0
GLEICH=0

installiere_datei() { # quelle ziel [modus]
    local quelle="$1" ziel="$2" modus="${3:-644}"
    if enthaelt "$ziel" "${NUR_WENN_FEHLT[@]}" && { [ -e "$ziel" ] || [ -L "$ziel" ]; }; then
        return 0
    fi
    if [ -f "$ziel" ] && [ ! -L "$ziel" ] && cmp -s "$quelle" "$ziel"; then
        GLEICH=$((GLEICH + 1))
        [ "$DRY" -eq 0 ] && printf '%s\n' "$ziel" >> "$MANIFEST.neu"
        return 0
    fi
    if [ -e "$ziel" ] || [ -L "$ziel" ]; then
        sichere "$ziel"
        vermerke ersetzt.txt "$ziel"
        GEAENDERT=$((GEAENDERT + 1))
        [ "$DRY" -eq 1 ] && probe "ersetzen: ~/${ziel#"$HOME"/}"
    else
        vermerke neu.txt "$ziel"
        NEU=$((NEU + 1))
        [ "$DRY" -eq 1 ] && probe "neu: ~/${ziel#"$HOME"/}"
    fi
    [ "$DRY" -eq 1 ] && return 0
    mkdir -p "$(dirname "$ziel")"
    rm -f "$ziel"   # nie durch einen Symlink hindurch schreiben
    cp "$quelle" "$ziel"
    chmod "$modus" "$ziel"
    printf '%s\n' "$ziel" >> "$MANIFEST.neu"
}

installiere_baum() { # quellordner zielordner [modus]
    local quelle="$1" ziel="$2" modus="${3:-644}" f rel
    [ -d "$quelle" ] || return 0
    while IFS= read -r -d '' f; do
        rel="${f#"$quelle"/}"
        installiere_datei "$f" "$ziel/$rel" "$modus"
    done < <(find "$quelle" -type f ! -name '.gitkeep' -print0 | sort -z)
}

# ---------------------------------------------------------------- Erzeugte Dateien

lua_text() { # Text als Lua-Zeichenkette
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '"%s"' "$s"
}

# Tastaturlayout aus localectl
tastatur() {
    local status layout="" variante="" keymap=""
    status="$(localectl status 2>/dev/null || true)"
    layout="$(awk -F': *' '/X11 Layout/ {print $2}' <<<"$status" | tr -d ' ')"
    variante="$(awk -F': *' '/X11 Variant/ {print $2}' <<<"$status" | tr -d ' ')"
    if [ -z "$layout" ] || [ "$layout" = "n/a" ]; then
        keymap="$(awk -F': *' '/VC Keymap/ {print $2}' <<<"$status" | tr -d ' ')"
        case "$keymap" in
            de_CH*|sg*) layout=ch; variante=de ;;
            fr_CH*|fr-ch*|fr_ch*) layout=ch; variante=fr ;;
            uk*) layout=gb ;;
            [a-z][a-z]|[a-z][a-z]-*|[a-z][a-z]_*) layout="${keymap:0:2}" ;;
            *) layout=us ;;
        esac
    fi
    [ "$variante" = "n/a" ] && variante=""
    printf '%s\n%s\n' "${layout:-us}" "$variante"
}

erzeuge_lokal() {
    local ziel="$CONF/hypr/hypr-shell-local.lua" layout variante
    [ -e "$ziel" ] && return 0
    { read -r layout; read -r variante; } < <(tastatur)
    if [ "$DRY" -eq 1 ]; then probe "neu: ~/.config/hypr/hypr-shell-local.lua (Tastatur: $layout ${variante:-})"; return 0; fi
    mkdir -p "$CONF/hypr"
    {
        echo "-- erzeugt von install.sh aus localectl; darf von Hand geändert werden"
        echo "return {"
        echo "    kb_layout  = $(lua_text "$layout"),"
        echo "    kb_variant = $(lua_text "$variante"),"
        echo "}"
    } > "$ziel"
    vermerke neu.txt "$ziel"
    printf '%s\n' "$ziel" >> "$MANIFEST.neu"
    ok "Tastaturlayout übernommen: $layout${variante:+ ($variante)}"
}

# Umgebungsvariablen der alten Konfiguration (z. B. für NVIDIA) übernehmen,
# damit Spiele und Steam weiter so starten wie vorher.
erzeuge_env() {
    local ziel="$CONF/hypr/hypr-shell-env.lua" zeilen=() name wert f
    [ -e "$ziel" ] && return 0
    [ -d "$CONF/hypr" ] || return 0
    while IFS= read -r -d '' f; do
        while IFS= read -r zeile; do
            name="$(sed -E 's/^[[:space:]]*env[[:space:]]*=[[:space:]]*([^,]+),.*/\1/' <<<"$zeile" | tr -d ' ')"
            wert="$(sed -E 's/^[[:space:]]*env[[:space:]]*=[[:space:]]*[^,]+,[[:space:]]*//; s/[[:space:]]+#.*$//' <<<"$zeile")"
            zeilen+=("$name"$'\t'"$wert")
        done < <(grep -E '^[[:space:]]*env[[:space:]]*=' "$f" 2>/dev/null || true)
    done < <(find -L "$CONF/hypr" -name '*.conf' ! -name 'hyprlock*' ! -name 'hypridle*' -print0 2>/dev/null)
    if [ -f "$CONF/hypr/hyprland.lua" ] && ! grep -q 'hypr-shell' "$CONF/hypr/hyprland.lua"; then
        while IFS= read -r zeile; do
            name="$(sed -E 's/.*hl\.env\(\s*"([^"]+)".*/\1/' <<<"$zeile")"
            wert="$(sed -E 's/.*hl\.env\(\s*"[^"]+"\s*,\s*"([^"]*)".*/\1/' <<<"$zeile")"
            zeilen+=("$name"$'\t'"$wert")
        done < <(grep -E 'hl\.env\(\s*"[^"]+"\s*,\s*"[^"]*"' "$CONF/hypr/hyprland.lua" || true)
    fi
    [ "${#zeilen[@]}" -eq 0 ] && return 0
    if [ "$DRY" -eq 1 ]; then probe "neu: ~/.config/hypr/hypr-shell-env.lua (${#zeilen[@]} alte Umgebungsvariablen)"; return 0; fi
    {
        echo "-- erzeugt von install.sh: Umgebungsvariablen aus der vorherigen Hyprland-Konfiguration"
        local z
        for z in "${zeilen[@]}"; do
            name="${z%%$'\t'*}"; wert="${z#*$'\t'}"
            case "$name" in XCURSOR_*|HYPRCURSOR_*|"") continue ;; esac
            [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
            echo "hl.env($(lua_text "$name"), $(lua_text "$wert"))"
        done
    } > "$ziel"
    vermerke neu.txt "$ziel"
    printf '%s\n' "$ziel" >> "$MANIFEST.neu"
    ok "Umgebungsvariablen der alten Konfiguration übernommen (~/.config/hypr/hypr-shell-env.lua)"
}

# ---------------------------------------------------------------- Pakete

paket_quelle() { # paket -> "installiert NAME" | "repo NAME" | "aur NAME" | "fehlt"
    local p kandidat
    p="$1"
    # shellcheck disable=SC2086 # Ausweichnamen sind durch Leerzeichen getrennt
    for kandidat in "$p" ${ALTERNATIVEN[$p]:-}; do
        if pacman -Qq "$kandidat" >/dev/null 2>&1; then echo "installiert $kandidat"; return; fi
    done
    for kandidat in "$p" ${ALTERNATIVEN[$p]:-}; do
        if pacman -Si "$kandidat" >/dev/null 2>&1; then echo "repo $kandidat"; return; fi
    done
    if command -v paru >/dev/null 2>&1; then
        for kandidat in "$p" ${ALTERNATIVEN[$p]:-}; do
            if paru -Si "$kandidat" >/dev/null 2>&1; then echo "aur $kandidat"; return; fi
        done
    fi
    echo fehlt
}

pakete() {
    info "Pakete prüfen"
    if ! command -v pacman >/dev/null 2>&1; then
        warnung "pacman fehlt – Pakete bitte von Hand installieren: ${PAKETE[*]}"
        return 0
    fi
    local repo=() aur=() fehlend=() p art name
    for p in "${PAKETE[@]}"; do
        read -r art name < <(paket_quelle "$p")
        case "$art" in
            installiert) ;;
            repo) repo+=("$name") ;;
            aur)  aur+=("$name") ;;
            *)    fehlend+=("$p") ;;
        esac
    done
    if [ "${#repo[@]}" -eq 0 ] && [ "${#aur[@]}" -eq 0 ]; then
        ok "alle verfügbaren Pakete sind schon installiert"
    fi
    if [ "${#repo[@]}" -gt 0 ]; then
        if [ "$DRY" -eq 1 ]; then probe "sudo pacman -S --needed ${repo[*]}"
        else sudo pacman -S --needed --noconfirm "${repo[@]}" || warnung "pacman meldete einen Fehler"; fi
    fi
    if [ "${#aur[@]}" -gt 0 ]; then
        if [ "$DRY" -eq 1 ]; then probe "paru -S --needed ${aur[*]}"
        else paru -S --needed --noconfirm "${aur[@]}" || warnung "paru meldete einen Fehler"; fi
    fi
    if [ "${#fehlend[@]}" -gt 0 ]; then
        if command -v paru >/dev/null 2>&1; then
            warnung "nicht gefunden (weder pacman noch paru): ${fehlend[*]}"
        else
            warnung "nicht in den Paketquellen, paru fehlt: ${fehlend[*]}"
        fi
    fi
}

fehlende_programme() {
    local fehlend=() e prog paket
    for e in "${PROGRAMME[@]}"; do
        prog="${e%%:*}"; paket="${e#*:}"
        command -v "$prog" >/dev/null 2>&1 || fehlend+=("$prog ($paket)")
    done
    if [ "${#fehlend[@]}" -gt 0 ]; then
        warnung "Diese Programme fehlen noch:"
        printf '      - %s\n' "${fehlend[@]}" >&2
    else
        ok "alle benötigten Programme sind vorhanden"
    fi
}

dienste_pruefen() {
    command -v systemctl >/dev/null 2>&1 || return 0
    local d
    for d in NetworkManager bluetooth power-profiles-daemon; do
        if systemctl list-unit-files "$d.service" 2>/dev/null | grep -q "^$d.service" && ! systemctl is-active --quiet "$d" 2>/dev/null; then
            warnung "Dienst $d läuft nicht. Einschalten mit: sudo systemctl enable --now $d"
        fi
    done
}

# ---------------------------------------------------------------- Installation

installieren() {
    info "hypr-shell $VERSION installieren"
    [ "$DRY" -eq 1 ] && info "Probelauf: es wird nichts verändert"
    if [ "$DRY" -eq 0 ] && ! ja_nein "Dateien nach ~/.config, ~/.local/bin, ~/.local/share und ~/Pictures/Wallpapers kopieren (alte werden gesichert)?"; then
        echo "Abgebrochen."
        exit 1
    fi

    if [ "$NOPKG" -eq 0 ]; then pakete; else info "Pakete übersprungen (--no-packages)"; fi

    info "Dateien kopieren"
    [ "$DRY" -eq 0 ] && { mkdir -p "$DATA"; : > "$MANIFEST.neu"; }

    local d name
    for d in "$REPO"/config/*/; do
        name="$(basename "$d")"
        echter_ordner "$CONF/$name"
        installiere_baum "$REPO/config/$name" "$CONF/$name"
    done
    if [ -d "$REPO/quickshell" ] && [ -n "$(find "$REPO/quickshell" -name '*.qml' -print -quit)" ]; then
        echter_ordner "$CONF/quickshell"
        installiere_baum "$REPO/quickshell" "$QS_DIR"
    fi
    installiere_baum "$REPO/bin" "$BIN" 755
    # mitgelieferte Schriften (Bebas Neue, SIL Open Font License)
    installiere_baum "$REPO/quickshell/common/fonts" "$HOME/.local/share/fonts/hypr-shell"
    installiere_baum "$REPO/wallpapers" "$DATA/wallpapers"
    installiere_datei "$REPO/VERSION" "$DATA/VERSION"
    if [ -f "$REPO/settings/settings.example.json" ]; then
        installiere_datei "$REPO/settings/settings.example.json" "$DATA/settings.example.json"
        installiere_datei "$REPO/settings/settings.example.json" "$CONF/hypr-shell/settings.json"
    fi
    # mitgelieferte Bilder nur nach ~/Pictures/Wallpapers, wenn sie dort fehlen
    local w
    for w in "$REPO"/wallpapers/*; do
        [ -f "$w" ] || continue
        if [ ! -e "$WALLS/$(basename "$w")" ]; then
            if [ "$DRY" -eq 1 ]; then probe "neu: ~/Pictures/Wallpapers/$(basename "$w")"
            else mkdir -p "$WALLS"; cp "$w" "$WALLS/"; vermerke neu.txt "$WALLS/$(basename "$w")"; fi
        fi
    done

    erzeuge_lokal
    erzeuge_env
    if [ "$DRY" -eq 0 ] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$HOME/.local/share/fonts/hypr-shell" >/dev/null 2>&1 || true
    fi

    if [ "$DRY" -eq 0 ]; then
        # Manifest: alle Dateien, die zu hypr-shell gehören (für --uninstall)
        if [ -f "$MANIFEST" ]; then sort -u "$MANIFEST.neu" "$MANIFEST"; else sort -u "$MANIFEST.neu"; fi > "$MANIFEST.tmp"
        mv "$MANIFEST.tmp" "$MANIFEST"
        rm -f "$MANIFEST.neu"
        if [ -d "$BACKUP" ]; then
            echo "$VERSION" > "$BACKUP/version"
        fi
    fi
    ok "$NEU neu, $GEAENDERT ersetzt, $GLEICH unverändert"
    if [ "$GEAENDERT" -gt 0 ] && [ "$DRY" -eq 0 ]; then
        ok "Sicherung der ersetzten Dateien: ~/${BACKUP#"$HOME"/}"
    fi

    if [ "$DRY" -eq 0 ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
        info "Laufende Hyprland-Sitzung neu laden"
        "$BIN/shell-wallpaper" --restore >/dev/null 2>&1 || true
        hyprctl reload >/dev/null 2>&1 || true
        "$BIN/shell-quickshell" restart >/dev/null 2>&1 || true
        local err
        err="$(hyprctl configerrors 2>/dev/null || true)"
        if [ -n "$err" ] && [ "$err" != "no errors" ]; then warnung "hyprctl configerrors: $err"; else ok "Konfiguration ohne Fehler geladen"; fi
    fi

    if [ "$NOPKG" -eq 0 ]; then fehlende_programme; fi
    dienste_pruefen

    echo
    if [ "$DRY" -eq 1 ]; then
        info "Probelauf beendet – nichts wurde verändert."
    else
        info "Fertig. Jetzt abmelden und im Login-Manager Hyprland wählen."
        echo "    Rückgängig: ./install.sh --restore   Entfernen: ./install.sh --uninstall"
    fi
}

# ---------------------------------------------------------------- Wiederherstellen

sicherungen() { # älteste zuerst
    find "$CONF" -maxdepth 1 -type d -name 'hypr-shell-backup-*' ! -name '*.wiederhergestellt' 2>/dev/null | sort
}

in_link_ordner() { # sicherungsordner pfad -> liegt pfad in einem Ordner, der ein Link war?
    local l
    [ -f "$1/links.txt" ] || return 1
    while IFS= read -r l; do
        [ -n "$l" ] || continue
        case "$2" in "$l"/*) return 0 ;; esac
    done < "$1/links.txt"
    return 1
}

stelle_wieder_her() { # sicherungsordner
    local dir="$1" f rel
    [ -d "$dir" ] || fehler "Sicherung nicht gefunden: $dir"
    info "Wiederherstellen aus ~/${dir#"$HOME"/}"
    # Dateien, die erst mit dieser Installation dazukamen, wieder entfernen
    if [ -f "$dir/neu.txt" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            case "$f" in "$HOME"/*) ;; *) continue ;; esac
            if [ -e "$f" ] || [ -L "$f" ]; then
                if [ "$DRY" -eq 1 ]; then probe "entfernen: ~/${f#"$HOME"/}"; else rm -f "$f"; fi
            fi
        done < "$dir/neu.txt"
    fi
    # Links auf Dotfile-Ordner zurücksetzen
    if [ -f "$dir/links.txt" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            if [ "$DRY" -eq 1 ]; then probe "Link wiederherstellen: ~/${f#"$HOME"/}"; continue; fi
            if [ -d "$f" ] && [ ! -L "$f" ]; then mv "$f" "$f.hypr-shell-$STAMP"; fi
            cp -P "$dir/links/${f#"$HOME"/}" "$f"
        done < "$dir/links.txt"
    fi
    # gesicherte Dateien zurückkopieren
    if [ -d "$dir/dateien" ]; then
        while IFS= read -r -d '' f; do
            rel="${f#"$dir/dateien/"}"
            # Dateien in einem verlinkten Ordner kamen aus dem Dotfiles-Ordner, der unverändert blieb
            if in_link_ordner "$dir" "$HOME/$rel"; then continue; fi
            if [ "$DRY" -eq 1 ]; then probe "zurück: ~/$rel"; continue; fi
            mkdir -p "$HOME/$(dirname "$rel")"
            rm -f "$HOME/$rel"
            cp -P -p "$f" "$HOME/$rel"
        done < <(find "$dir/dateien" \( -type f -o -type l \) -print0)
    fi
    ok "wiederhergestellt"
}

wiederherstellen() {
    local dir="$RESTORE_DIR"
    if [ -z "$dir" ]; then
        dir="$(sicherungen | tail -n1)"
        [ -n "$dir" ] || fehler "Keine Sicherung gefunden (~/.config/hypr-shell-backup-*)."
    fi
    [ "$DRY" -eq 1 ] && info "Probelauf: es wird nichts verändert"
    ja_nein "Stand aus ~/${dir#"$HOME"/} wiederherstellen?" || { echo "Abgebrochen."; exit 1; }
    stelle_wieder_her "$dir"
    if [ "$DRY" -eq 0 ]; then
        mv "$dir" "$dir.wiederhergestellt"
        ok "Sicherung umbenannt in ~/${dir#"$HOME"/}.wiederhergestellt"
        info "Fertig. Abmelden und wieder anmelden, damit alles neu startet."
    fi
}

entfernen() {
    [ -f "$MANIFEST" ] || fehler "hypr-shell ist nicht installiert ($MANIFEST fehlt)."
    [ "$DRY" -eq 1 ] && info "Probelauf: es wird nichts verändert"
    ja_nein "Alle Dateien von hypr-shell entfernen und den Zustand vor der ersten Installation zurückholen?" || { echo "Abgebrochen."; exit 1; }
    info "Dateien von hypr-shell entfernen"
    local f
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        case "$f" in "$HOME"/*) ;; *) continue ;; esac
        if [ -e "$f" ] || [ -L "$f" ]; then
            if [ "$DRY" -eq 1 ]; then probe "entfernen: ~/${f#"$HOME"/}"; else rm -f "$f"; fi
        fi
    done < "$MANIFEST"
    # leere Ordner von hypr-shell aufräumen
    if [ "$DRY" -eq 0 ]; then
        find "$QS_DIR" "$CONF/hypr-shell" -depth -type d -empty -delete 2>/dev/null || true
    fi
    # Zustand vor der ersten Installation
    local erste
    erste="$(sicherungen | head -n1)"
    if [ -n "$erste" ]; then
        stelle_wieder_her "$erste"
    fi
    if [ "$DRY" -eq 0 ]; then
        rm -rf "$DATA"
        ok "hypr-shell entfernt. Sicherungen bleiben in ~/.config/hypr-shell-backup-*"
    fi
}

case "$MODE" in
    install) installieren ;;
    restore) wiederherstellen ;;
    uninstall) entfernen ;;
esac
