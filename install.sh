#!/usr/bin/env bash
# hypr-shell Installer
#
#   ./install.sh                 installieren (fragt einmal nach)
#   ./install.sh --yes           ohne Rückfrage
#   ./install.sh --dry-run       nur anzeigen, was passieren würde, nichts ändern
#   ./install.sh --no-packages   keine Pakete installieren, nur Dateien kopieren
#   ./install.sh --update        neuen Stand holen (git pull --ff-only) und neu installieren;
#                                settings.json, user.lua und hypr-shell-local.lua bleiben unberührt
#   ./install.sh --restore [DIR] Stand vor der letzten Installation wiederherstellen
#   ./install.sh --uninstall     alle Dateien von hypr-shell entfernen, Ursprungszustand zurück
#
# Braucht Hyprland ab 0.55 (Lua-Konfiguration); ein älteres bricht vor jeder Änderung ab.
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
UPDATE=0
MODE=install
RESTORE_DIR=""
HYPR_MIN="0.55.0"
ARGS=("$@")

# Pakete (Namen werden vor der Installation mit pacman -Si / paru -Si geprüft)
PAKETE=(
    hyprland hyprlock hypridle hyprsunset xdg-desktop-portal-hyprland hyprpolkitagent
    quickshell waybar rofi awww matugen kitty cava
    grim slurp wl-clipboard cliphist libnotify jq playerctl brightnessctl pamixer wireplumber
    power-profiles-daemon networkmanager bluez bluez-utils nautilus xdg-user-dirs imagemagick
    papirus-icon-theme bibata-cursor-theme-bin
    ttf-jetbrains-mono-nerd inter-font noto-fonts noto-fonts-emoji
)
# Ausweichnamen, falls ein Paket anders heisst
declare -A ALTERNATIVEN=(
    [quickshell]="quickshell-git"
    [awww]="awww-bin awww-git"
    [matugen]="matugen-bin matugen-git"
    [bibata-cursor-theme-bin]="bibata-cursor-theme"
    [inter-font]="ttf-inter"
)
# Programme, die am Ende da sein müssen (Programm:Paket)
PROGRAMME=(
    Hyprland:hyprland hyprlock:hyprlock hypridle:hypridle qs:quickshell waybar:waybar
    rofi:rofi awww:awww awww-daemon:awww matugen:matugen kitty:kitty
    grim:grim slurp:slurp wl-copy:wl-clipboard cliphist:cliphist notify-send:libnotify jq:jq playerctl:playerctl
    brightnessctl:brightnessctl pamixer:pamixer wpctl:wireplumber
    powerprofilesctl:power-profiles-daemon nmcli:networkmanager bluetoothctl:bluez-utils
    nautilus:nautilus
)
# Dateien, die nur angelegt werden, wenn sie fehlen (vom Benutzer oder von matugen erzeugt)
NUR_WENN_FEHLT=(
    "$CONF/hypr/hypr-shell-colors.lua"
    "$CONF/hypr/hyprlock-colors.conf"
    "$CONF/kitty/colors.conf"
    "$CONF/rofi/colors.rasi"
    "$CONF/waybar/colors.css"
    "$CONF/hypr-shell/colors.json"
    "$CONF/hypr-shell/settings.json"
)

# Dateien, die shell-apply aus settings.json erzeugt: der Installer legt nur die Fassung mit den
# Standardwerten an, wenn sie fehlt (oder noch nicht von hypr-shell erzeugt wurde), danach
# schreibt shell-apply sie passend zu den Einstellungen
ERZEUGT=(
    "$CONF/waybar/config.jsonc"
    "$CONF/waybar/style.css"
    "$CONF/hypr/hypridle.conf"
    "$CONF/hypr/hyprlock.conf"
    "$CONF/rofi/hypr-shell-settings.rasi"
)
ERZEUGT_KOPF="erzeugt von hypr-shell"

# ---------------------------------------------------------------- Hilfsfunktionen

if [ -t 1 ]; then FETT=$'\e[1m'; GRUEN=$'\e[32m'; GELB=$'\e[33m'; ROT=$'\e[31m'; AUS=$'\e[0m'
else FETT=""; GRUEN=""; GELB=""; ROT=""; AUS=""; fi

info()   { printf '%s==>%s %s\n' "$FETT" "$AUS" "$*"; }
ok()     { printf '  %s✓%s %s\n' "$GRUEN" "$AUS" "$*"; }
warnung(){ printf '  %s!%s %s\n' "$GELB" "$AUS" "$*" >&2; }
fehler() { printf '%sFehler:%s %s\n' "$ROT" "$AUS" "$*" >&2; exit 1; }
probe()  { printf '  [Probelauf] %s\n' "$*"; }

hilfe() {
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

ja_nein() {
    [ "$YES" -eq 1 ] && return 0
    [ "$DRY" -eq 1 ] && return 0
    local antwort
    read -r -p "$1 [j/N] " antwort || return 1
    [[ "$antwort" =~ ^[jJyY] ]]
}

# gleicher Inhalt? (cmp gehört zu diffutils und fehlt manchmal, sha256sum ist immer da)
gleich() {
    if command -v cmp >/dev/null 2>&1; then cmp -s "$1" "$2"; return; fi
    [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ]
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
        --update) UPDATE=1 ;;
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

# ---------------------------------------------------------------- Hyprland-Version

# installierte Version, z. B. "0.55.1" (leer, wenn Hyprland fehlt)
hyprland_version() {
    local v=""
    if command -v Hyprland >/dev/null 2>&1; then
        v="$( (Hyprland --version 2>/dev/null || true) | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
    fi
    if [ -z "$v" ] && command -v hyprctl >/dev/null 2>&1; then
        v="$( (hyprctl version 2>/dev/null || true) | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
    fi
    printf '%s\n' "$v"
}

# mindestens HYPR_MIN? (Versionen wie 0.55.0 mit sort -V vergleichen)
version_ok() { [ "$(printf '%s\n%s\n' "$HYPR_MIN" "$1" | sort -V | head -n1)" = "$HYPR_MIN" ]; }

# Bricht ab, bevor irgendetwas verändert wird, wenn ein zu altes Hyprland installiert ist.
pruefe_hyprland() {
    local v
    v="$(hyprland_version)"
    if [ -z "$v" ]; then
        if [ "$NOPKG" -eq 1 ]; then
            warnung "Hyprland ist nicht installiert – hypr-shell braucht Hyprland ab ${HYPR_MIN%.0} (sudo pacman -S hyprland)"
        fi
        return 0
    fi
    if ! version_ok "$v"; then
        printf '%sFehler:%s Hyprland %s ist zu alt. hypr-shell braucht Hyprland ab %s (Lua-Konfiguration).\n' "$ROT" "$AUS" "$v" "${HYPR_MIN%.0}" >&2
        printf '       Zuerst aktualisieren:  sudo pacman -Syu hyprland\n' >&2
        printf '       Danach ./install.sh erneut starten. Es wurde nichts verändert.\n' >&2
        exit 1
    fi
    ok "Hyprland $v (mindestens ${HYPR_MIN%.0})"
}

# ---------------------------------------------------------------- Aktualisieren (--update)

aktualisieren() {
    command -v git >/dev/null 2>&1 || fehler "git fehlt – --update braucht git."
    git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || fehler "$REPO ist kein git-Klon – bitte neu klonen: gh repo clone Louidos/hypr-shell"
    info "Neuen Stand holen (git pull --ff-only)"
    if [ "$DRY" -eq 1 ]; then
        probe "git -C $REPO pull --ff-only"
    else
        git -C "$REPO" pull --ff-only || fehler "git pull --ff-only ging nicht (eigene Änderungen im Ordner?). Nichts wurde installiert."
    fi
    # die neue Fassung des Installers ausführen, ohne --update
    local rest=() a
    for a in "${ARGS[@]}"; do [ "$a" = --update ] || rest+=("$a"); done
    exec "$REPO/install.sh" "${rest[@]}"
}

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
    # von shell-apply erzeugt: bleibt, wie es ist (shell-apply schreibt es am Ende neu)
    if enthaelt "$ziel" "${ERZEUGT[@]}" && [ -f "$ziel" ] && [ ! -L "$ziel" ] && grep -q "$ERZEUGT_KOPF" "$ziel"; then
        [ "$DRY" -eq 0 ] && printf '%s\n' "$ziel" >> "$MANIFEST.neu"
        GLEICH=$((GLEICH + 1))
        return 0
    fi
    if [ -f "$ziel" ] && [ ! -L "$ziel" ] && gleich "$quelle" "$ziel"; then
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

vervollstaendigung() { # quelle ziel
    local d
    d="$(dirname "$1")"
    for d in "$(dirname "$2")" "$(dirname "$(dirname "$2")")"; do
        if [ -L "$d" ]; then
            warnung "~/${d#"$HOME"/} ist ein Link – Vervollständigung für shell-set dort nicht installiert"
            return 0
        fi
    done
    installiere_datei "$1" "$2"
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

# settings.json beim ersten Mal aus der Vorlage anlegen, mit dem Tastaturlayout aus localectl.
# Eine vorhandene settings.json wird nie verändert.
erzeuge_settings() {
    local ziel="$CONF/hypr-shell/settings.json" vorlage="$REPO/settings/settings.example.json" layout variante
    [ -e "$ziel" ] || [ -L "$ziel" ] && return 0
    { read -r layout; read -r variante; } < <(tastatur)
    if [ "$DRY" -eq 1 ]; then probe "neu: ~/.config/hypr-shell/settings.json (Tastatur: $layout ${variante:-})"; return 0; fi
    mkdir -p "$CONF/hypr-shell"
    jq --indent 2 --arg l "$layout" --arg v "$variante" '.input.layout = $l | .input.variant = $v' "$vorlage" > "$ziel.neu" \
        || cp "$vorlage" "$ziel.neu"
    mv "$ziel.neu" "$ziel"
    vermerke neu.txt "$ziel"
    printf '%s\n' "$ziel" >> "$MANIFEST.neu"
    ok "Einstellungen angelegt, Tastaturlayout übernommen: $layout${variante:+ ($variante)}"
}

# Dateien aus settings.json erzeugen (Waybar, Hyprland, hypridle, hyprlock, rofi)
einstellungen_anwenden() {
    local extra="$CONF/hypr/hypr-shell-settings.lua" neu=0
    if [ "$DRY" -eq 1 ]; then probe "shell-apply: Dateien aus ~/.config/hypr-shell/settings.json erzeugen"; return 0; fi
    command -v jq >/dev/null 2>&1 || { warnung "jq fehlt – Einstellungen werden erst angewendet, wenn jq installiert ist"; return 0; }
    [ -e "$extra" ] || neu=1
    if "$BIN/shell-apply" --no-reload --no-migrate 2> "$DATA/.apply.log"; then
        ok "Einstellungen angewendet"
    else
        warnung "shell-apply meldete einen Fehler: $(tail -n1 "$DATA/.apply.log")"
    fi
    if [ -s "$DATA/.apply.log" ]; then
        warnung "settings.json enthält Werte, die nicht passen (es gelten die Standardwerte):"
        sed 's/^shell-apply: /      /' "$DATA/.apply.log" >&2
    fi
    rm -f "$DATA/.apply.log"
    if [ -e "$extra" ]; then
        [ "$neu" -eq 1 ] && vermerke neu.txt "$extra"
        printf '%s\n' "$extra" >> "$MANIFEST.neu"
    fi
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

# Ersatz-Profilbild für den Sperrbildschirm, wenn ~/.face fehlt: Anfangsbuchstabe des
# Benutzers in einem Kreis. ~/.face selbst wird nie angelegt oder verändert; hyprlock legt das
# echte Bild über den Ersatz, sobald es da ist.
erzeuge_ersatzbild() {
    local ziel="$DATA/face.png" im buchstabe schrift
    [ -e "$HOME/.face" ] && return 0
    [ -e "$ziel" ] && return 0
    im="$(command -v magick || command -v convert || true)"
    if [ -z "$im" ]; then
        warnung "ImageMagick fehlt – kein Ersatz-Profilbild für den Sperrbildschirm (eigenes Bild: ~/.face)"
        return 0
    fi
    buchstabe="$(printf '%s' "${USER:-$(id -un)}" | cut -c1 | tr '[:lower:]' '[:upper:]')"
    if [ "$DRY" -eq 1 ]; then probe "neu: ~/.local/share/hypr-shell/face.png (Ersatz-Profilbild mit $buchstabe)"; return 0; fi
    mkdir -p "$DATA"
    # fontconfig legt sonst einen Zwischenspeicher in ~/.cache an – der Installer schreibt nur
    # in seine eigenen Ordner, also einen Wegwerf-Ordner verwenden
    local cache rc=0
    cache="$(mktemp -d)"
    schrift="$( (XDG_CACHE_HOME="$cache" fc-match -f '%{file}' 'Inter:bold' 2>/dev/null) || true)"
    local args=(-size 256x256 xc:none -fill '#2a2a2e' -draw 'circle 128,128 128,2' -fill '#e6e6e6')
    [ -n "$schrift" ] && [ -f "$schrift" ] && args+=(-font "$schrift")
    args+=(-pointsize 120 -gravity center -annotate +0+4 "${buchstabe:-?}" "$ziel")
    XDG_CACHE_HOME="$cache" "$im" "${args[@]}" 2>/dev/null || rc=$?
    rm -rf "$cache"
    if [ "$rc" -eq 0 ]; then
        vermerke neu.txt "$ziel"
        printf '%s\n' "$ziel" >> "$MANIFEST.neu"
        ok "Ersatz-Profilbild für den Sperrbildschirm erzeugt (eigenes Bild: ~/.face)"
    else
        warnung "Ersatz-Profilbild konnte nicht erzeugt werden"
    fi
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
    # zuerst das System aktualisieren (Arch: keine Teil-Updates), mit --yes ohne Frage
    if [ "$DRY" -eq 1 ]; then
        probe "sudo pacman -Syu (System aktualisieren, wird vorher gefragt)"
    elif [ "$YES" -eq 1 ] || ja_nein "Zuerst das System aktualisieren (sudo pacman -Syu)? Empfohlen."; then
        sudo pacman -Syu --noconfirm || warnung "Systemaktualisierung meldete einen Fehler"
    else
        warnung "System nicht aktualisiert – neue Pakete passen eventuell nicht zu alten"
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

# Sprechen mit Missa (freiwillig): whisper.cpp, piper und ihre Modelle nur nach Rückfrage holen.
# Mit --yes wird nicht gefragt und nichts geholt; ohne die Programme fehlen Taste und Mikrofon-Knopf.
STIMME_PAKETE=(whisper-cpp piper-tts-bin sox)
declare -A STIMME_ALTERNATIVEN=([whisper-cpp]="whisper.cpp" [piper-tts-bin]="piper-tts")
WHISPER_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
PIPER_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx"
stimme_einrichten() {
    if [ "$DRY" -eq 1 ] || [ "$YES" -eq 1 ] || [ ! -t 0 ]; then return 0; fi
    if command -v whisper-cli >/dev/null 2>&1 && [ -f "$DATA/whisper/ggml-base.bin" ]; then return 0; fi
    ja_nein "Mit Missa sprechen einrichten (whisper.cpp, piper, deutsches Sprachmodell und Stimme, etwa 250 MB)? Nur nötig, wenn du Missa benutzt." || return 0
    local p kandidat gefunden
    for p in "${STIMME_PAKETE[@]}"; do
        gefunden=""
        # shellcheck disable=SC2086
        for kandidat in "$p" ${STIMME_ALTERNATIVEN[$p]:-}; do
            if pacman -Si "$kandidat" >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm "$kandidat" && gefunden=1; break; fi
            if command -v paru >/dev/null 2>&1 && paru -Si "$kandidat" >/dev/null 2>&1; then paru -S --needed --noconfirm "$kandidat" && gefunden=1; break; fi
        done
        [ -n "$gefunden" ] || warnung "Paket $p nicht gefunden – Sprechen mit Missa bleibt aus"
    done
    mkdir -p "$DATA/whisper" "$DATA/piper"
    curl -fL --progress-bar -o "$DATA/whisper/ggml-base.bin" "$WHISPER_URL" || warnung "Sprachmodell konnte nicht geladen werden"
    if ! curl -fL --progress-bar -o "$DATA/piper/de_DE-thorsten-medium.onnx" "$PIPER_URL" \
        || ! curl -fL -s -o "$DATA/piper/de_DE-thorsten-medium.onnx.json" "$PIPER_URL.json"; then
        warnung "Stimme konnte nicht geladen werden"
    fi
    ok "Sprechen mit Missa eingerichtet (einschalten: Einstellungen → Integrations → Talk to Missa)"
}

# ASUS-Laptop ohne asusctl: Pakete nur vorschlagen, nie ungefragt installieren
laptop_hinweis() {
    local hersteller=""
    hersteller="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    case "$hersteller" in
        *ASUS*)
            if ! command -v asusctl >/dev/null 2>&1; then
                warnung "ASUS-Laptop erkannt: Für Leistungsprofil, Ladegrenze und Tastaturlicht in hypr-shell asusctl installieren"
                warnung "  (siehe https://asus-linux.org – z. B. Paket asusctl; für den Grafik-Modus zusätzlich supergfxctl)"
            fi ;;
    esac
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
    pruefe_hyprland
    if [ "$DRY" -eq 0 ] && ! ja_nein "Dateien nach ~/.config, ~/.local/bin, ~/.local/share und ~/Pictures/Wallpapers kopieren (alte werden gesichert)?"; then
        echo "Abgebrochen."
        exit 1
    fi

    if [ "$NOPKG" -eq 0 ]; then
        pakete
        # Hyprland kam eventuell eben erst dazu: Version jetzt prüfen, bevor Dateien kopiert werden
        [ "$DRY" -eq 1 ] || pruefe_hyprland
    else
        info "Pakete übersprungen (--no-packages)"
    fi

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
    installiere_datei "$REPO/settings/settings.example.json" "$DATA/settings.example.json"
    installiere_datei "$REPO/settings/schema.json" "$DATA/schema.json"
    # Tab-Vervollständigung für shell-set (bash, fish); ein verlinkter Ordner wird nicht angefasst
    vervollstaendigung "$REPO/settings/completions/shell-set.bash" "$HOME/.local/share/bash-completion/completions/shell-set"
    vervollstaendigung "$REPO/settings/completions/shell-set.fish" "$CONF/fish/completions/shell-set.fish"
    # mitgelieferte Bilder nur nach ~/Pictures/Wallpapers, wenn sie dort fehlen
    local w
    for w in "$REPO"/wallpapers/*; do
        [ -f "$w" ] || continue
        if [ ! -e "$WALLS/$(basename "$w")" ]; then
            if [ "$DRY" -eq 1 ]; then probe "neu: ~/Pictures/Wallpapers/$(basename "$w")"
            else mkdir -p "$WALLS"; cp "$w" "$WALLS/"; vermerke neu.txt "$WALLS/$(basename "$w")"; fi
        fi
    done

    erzeuge_settings
    erzeuge_env
    erzeuge_ersatzbild
    einstellungen_anwenden
    # kein fc-cache: das schriebe nach ~/.cache; fontconfig findet neue Schriften von selbst

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
        pkill -SIGUSR2 -x waybar 2>/dev/null || true
        "$BIN/shell-quickshell" restart >/dev/null 2>&1 || true
        local err
        err="$(hyprctl configerrors 2>/dev/null || true)"
        if [ -n "$err" ] && [ "$err" != "no errors" ]; then warnung "hyprctl configerrors: $err"; else ok "Konfiguration ohne Fehler geladen"; fi
    fi

    if [ "$NOPKG" -eq 0 ]; then fehlende_programme; fi
    dienste_pruefen
    laptop_hinweis
    stimme_einrichten

    echo
    if [ "$DRY" -eq 1 ]; then
        info "Probelauf beendet – nichts wurde verändert."
        return 0
    fi
    info "Fertig. So geht es weiter:"
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        echo "    1. Die laufende Sitzung ist neu geladen. Für Autostart und Sperren einmal ab- und wieder anmelden."
    else
        echo "    1. Abmelden."
        echo '    2. Im Login-Manager „Hyprland“ wählen und anmelden.'
    fi
    if ! grep -qE '"location"[[:space:]]*:[[:space:]]*"[^"]+"' "$CONF/hypr-shell/settings.json" 2>/dev/null; then
        echo "    •  Wetter-Ort eintragen: ~/.config/hypr-shell/settings.json → \"weather\": { \"location\": \"Zürich\" }"
        echo "       (oder im Panel unten rechts auf das Zahnrad klicken)"
    fi
    echo "    •  Eigenes Profilbild: ~/.face   Eigene Hintergrundbilder: ~/Pictures/Wallpapers"
    echo
    echo "    Später aktualisieren:     ./install.sh --update"
    echo "    Alles zurücknehmen:       ./install.sh --restore     (Stand vor dieser Installation)"
    echo "    Ganz entfernen:           ./install.sh --uninstall   (Stand vor der ersten Installation)"
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

if [ "$UPDATE" -eq 1 ]; then
    [ "$MODE" = install ] || fehler "--update passt nicht zu --restore oder --uninstall."
    # vor dem Holen prüfen: ein zu altes Hyprland bricht ab, bevor etwas verändert wird
    pruefe_hyprland
    aktualisieren
fi

case "$MODE" in
    install) installieren ;;
    restore) wiederherstellen ;;
    uninstall) entfernen ;;
esac
