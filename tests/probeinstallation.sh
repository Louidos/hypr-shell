#!/usr/bin/env bash
# Probeinstallation in einem leeren HOME:
#   1. eine "alte" Datei liegt schon da (kitty.conf)
#   2. ./install.sh --yes --no-packages: alle Dateien kommen an, alte Datei ist gesichert
#   3. keine Datei zeigt auf einen fremden Pfad (Symlinks, feste Pfade)
#   4. --dry-run ändert nichts
#   5. --restore holt die alte Datei zurück und entfernt neue Dateien
#   6. --uninstall entfernt alles wieder
#   7. ein Dotfiles-Ordner (Symlink) wird nicht durchschrieben
#   8. ein zu altes Hyprland (vorgetäuscht 0.54) bricht vor jeder Änderung ab
#   9. --update holt den neuen Stand und lässt settings.json, user.lua, hypr-shell-local.lua in Ruhe
# Prüfungen werden als Text an pruefe übergeben und dort ausgewertet:
# shellcheck disable=SC2016,SC2034,SC2088
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"

TESTHOME="$(mktemp -d)"
trap 'rm -rf "$TESTHOME"' EXIT
unset HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME XDG_DATA_HOME
[ "$(id -u)" -eq 0 ] && export HYPR_SHELL_ALLOW_ROOT=1   # nur für Test-Container

fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
inst() { HOME="$TESTHOME" "$REPO/install.sh" "$@" > "$TESTHOME/.ausgabe" 2>&1 || { cat "$TESTHOME/.ausgabe"; return 1; }; }
zustand() { # Inhalt aller Dateien und Ziele aller Links unter TESTHOME
    (cd "$TESTHOME" && {
        find . -path ./.ausgabe -prune -o -type l -printf 'L %p %l\n' | sort
        find . -path ./.ausgabe -prune -o -type f -print0 | sort -z | xargs -0 -r sha256sum
    })
}

# erwartete Ziele aus dem Repo ableiten
erwartet=()
while IFS= read -r -d '' f; do
    rel="${f#config/}"
    erwartet+=(".config/$rel")
done < <(find config -type f ! -name .gitkeep -print0)
while IFS= read -r -d '' f; do erwartet+=(".local/bin/$(basename "$f")"); done < <(find bin -type f ! -name .gitkeep -print0)
while IFS= read -r -d '' f; do erwartet+=(".local/share/hypr-shell/wallpapers/$(basename "$f")"); done < <(find wallpapers -type f ! -name .gitkeep -print0)
if [ -n "$(find quickshell -name '*.qml' -print -quit)" ]; then
    while IFS= read -r -d '' f; do erwartet+=(".config/quickshell/hypr-shell/${f#quickshell/}"); done < <(find quickshell -type f ! -name .gitkeep -print0)
fi
while IFS= read -r -d '' f; do erwartet+=(".local/share/fonts/hypr-shell/$(basename "$f")"); done < <(find quickshell/common/fonts -type f -print0)
erwartet+=(".local/share/hypr-shell/VERSION" ".local/share/hypr-shell/schema.json" ".config/hypr-shell/settings.json"
          ".config/hypr/hypr-shell-settings.lua" ".local/share/hypr-shell/settings.effective.json"
          ".local/share/bash-completion/completions/shell-set" ".config/fish/completions/shell-set.fish")

echo "== 1. alte Datei anlegen"
mkdir -p "$TESTHOME/.config/kitty"
echo "# meine alte kitty.conf" > "$TESTHOME/.config/kitty/kitty.conf"
mkdir -p "$TESTHOME/.config/hypr/config"
printf 'source = ~/.config/hypr/config/env.conf\n' > "$TESTHOME/.config/hypr/hyprland.conf"
printf 'env = LIBVA_DRIVER_NAME,nvidia\nenv = XCURSOR_SIZE,32\n  env = __GLX_VENDOR_LIBRARY_NAME, nvidia # Kommentar\n' > "$TESTHOME/.config/hypr/config/env.conf"

echo "== 2. Installation"
inst --yes --no-packages
fehlend=0
for e in "${erwartet[@]}"; do
    if [ ! -f "$TESTHOME/$e" ]; then echo "  fehlt: ~/$e"; fehlend=1; fi
done
pruefe '[ $fehlend -eq 0 ]' "alle ${#erwartet[@]} Dateien angekommen"
pruefe '[ -x "$TESTHOME/.local/bin/shell-wallpaper" ]' "Skripte in ~/.local/bin sind ausführbar"
pruefe '[ "$(sha256sum < config/kitty/kitty.conf)" = "$(sha256sum < "$TESTHOME/.config/kitty/kitty.conf")" ]' "kitty.conf ersetzt"
backup="$(find "$TESTHOME/.config" -maxdepth 1 -name 'hypr-shell-backup-*' | head -n1)"
pruefe '[ -n "$backup" ] && grep -q "meine alte" "$backup/dateien/.config/kitty/kitty.conf"' "alte kitty.conf gesichert"
pruefe '[ -f "$TESTHOME/Pictures/Wallpapers/hypr-shell-grau.png" ]' "Startbild in ~/Pictures/Wallpapers"
envlua="$TESTHOME/.config/hypr/hypr-shell-env.lua"
pruefe 'grep -qx "hl.env(\"LIBVA_DRIVER_NAME\", \"nvidia\")" "$envlua" && grep -qx "hl.env(\"__GLX_VENDOR_LIBRARY_NAME\", \"nvidia\")" "$envlua"' "alte Umgebungsvariablen (NVIDIA) übernommen"
pruefe '! grep -q XCURSOR "$envlua"' "Mauszeiger-Variablen nicht doppelt"
pruefe '[ -f "$TESTHOME/.config/hypr/hyprland.conf" ]' "alte hyprland.conf bleibt liegen (Lua hat Vorrang)"
if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    pruefe '[ -s "$TESTHOME/.local/share/hypr-shell/face.png" ]' "Ersatz-Profilbild für hyprlock (ohne ~/.face)"
else
    echo "  Hinweis: ImageMagick fehlt, Ersatz-Profilbild nicht geprüft"
fi
pruefe '[ ! -e "$TESTHOME/.face" ]' "~/.face wird nicht angelegt"
pruefe 'jq -e ".input.layout | test(\"^[a-z]+$\")" "$TESTHOME/.config/hypr-shell/settings.json" >/dev/null && jq -e ".bar.height == 30" "$TESTHOME/.config/hypr-shell/settings.json" >/dev/null' "settings.json aus der Vorlage, Tastaturlayout eingetragen"
pruefe '[ ! -e "$TESTHOME/.config/hypr/hypr-shell-local.lua" ]' "keine hypr-shell-local.lua mehr (alles in settings.json)"
pruefe 'head -n1 "$TESTHOME/.config/hypr/hypr-shell-settings.lua" | grep -q "erzeugt von hypr-shell"' "shell-apply hat die Dateien erzeugt"

echo "== 3. keine fremden Pfade"
fremd="$(find "$TESTHOME" -type l -exec sh -c 'case "$(readlink -f "$1")" in "$2"/*) ;; *) echo "$1";; esac' _ {} "$TESTHOME" \; )"
pruefe '[ -z "$fremd" ]' "keine Symlinks nach ausserhalb ($fremd)"
pruefe '! grep -rIl --exclude=.ausgabe -- "$REPO" "$TESTHOME"' "keine Datei verweist auf den Repo-Ordner"
pruefe '! grep -rIlE "/home/[a-z]|/root/" "$TESTHOME/.config" "$TESTHOME/.local/bin"' "keine festen Benutzerpfade"
dateien_ausserhalb="$(cd "$TESTHOME" && find . -type f ! -path './.config/*' ! -path './.local/bin/*' ! -path './.local/share/*' ! -path './Pictures/Wallpapers/*' ! -name .ausgabe)"
pruefe '[ -z "$dateien_ausserhalb" ]' "nur in erlaubten Ordnern geschrieben ($dateien_ausserhalb)"

echo "== 4. --dry-run ändert nichts"
echo "# Änderung" >> "$TESTHOME/.config/hypr/hyprland.lua"
vorher="$(zustand)"
inst --dry-run
pruefe '[ "$vorher" = "$(zustand)" ]' "Probelauf hat nichts verändert"
pruefe 'grep -q "ersetzen: ~/.config/hypr/hyprland.lua" "$TESTHOME/.ausgabe"' "Probelauf zeigt geplante Änderung"
inst --restore --dry-run
pruefe '[ "$vorher" = "$(zustand)" ]' "Probelauf von --restore hat nichts verändert"

echo "== 5. --restore"
inst --restore --yes
pruefe 'grep -q "meine alte" "$TESTHOME/.config/kitty/kitty.conf"' "alte kitty.conf zurück"
pruefe '[ ! -e "$TESTHOME/.config/hypr/hyprland.lua" ] && [ ! -e "$TESTHOME/.config/hypr/hypr-shell-settings.lua" ]' "neu hinzugekommene hyprland.lua und hypr-shell-settings.lua entfernt"

echo "== 6. erneut installieren, dann --uninstall"
inst --yes --no-packages
pruefe '[ -f "$TESTHOME/.config/hypr/hyprland.lua" ]' "zweite Installation"
inst --uninstall --yes
pruefe 'grep -q "meine alte" "$TESTHOME/.config/kitty/kitty.conf"' "Ursprungszustand nach --uninstall"
pruefe '[ ! -e "$TESTHOME/.config/hypr/hyprland.lua" ] && [ ! -e "$TESTHOME/.local/bin/shell-wallpaper" ] && [ ! -e "$TESTHOME/.config/hypr/hypr-shell-settings.lua" ]' "Dateien von hypr-shell entfernt"
pruefe '[ ! -d "$TESTHOME/.local/share/hypr-shell" ]' "Datenordner entfernt"

echo "== 7. Symlink-Ordner wird nicht durchschrieben"
rm -rf "$TESTHOME/.config/kitty"
mkdir -p "$TESTHOME/dotfiles/kitty"
echo "# dotfile" > "$TESTHOME/dotfiles/kitty/kitty.conf"
dotfile_vorher="$(stat -c %Y-%s "$TESTHOME/dotfiles/kitty/kitty.conf")"
sleep 1
ln -s "$TESTHOME/dotfiles/kitty" "$TESTHOME/.config/kitty"
inst --yes --no-packages
pruefe '[ "$dotfile_vorher" = "$(stat -c %Y-%s "$TESTHOME/dotfiles/kitty/kitty.conf")" ] && [ "$(ls "$TESTHOME/dotfiles/kitty")" = kitty.conf ]' "Dotfiles-Ordner unberührt"
pruefe '[ ! -L "$TESTHOME/.config/kitty" ]' "~/.config/kitty ist jetzt ein eigener Ordner"
inst --restore --yes
pruefe '[ -L "$TESTHOME/.config/kitty" ]' "Link nach --restore wieder da"

echo "== 8. zu altes Hyprland: Abbruch vor jeder Änderung"
mkdir -p "$TESTHOME/.fakebin"
printf '#!/bin/sh\necho "Hyprland 0.54.2 built from branch v0.54.2 at commit 0000000"\n' > "$TESTHOME/.fakebin/Hyprland"
chmod +x "$TESTHOME/.fakebin/Hyprland"
vorher="$(zustand)"
for opt in "--yes --no-packages" "--yes" "--dry-run" "--update --yes --no-packages"; do
    # shellcheck disable=SC2086 # Optionen absichtlich getrennt
    if PATH="$TESTHOME/.fakebin:$PATH" HOME="$TESTHOME" "$REPO/install.sh" $opt > "$TESTHOME/.ausgabe" 2>&1; then
        pruefe 'false' "Abbruch mit $opt"
    else
        pruefe 'grep -q "sudo pacman -Syu hyprland" "$TESTHOME/.ausgabe" && [ "$vorher" = "$(zustand)" ]' "Abbruch mit $opt: Hinweis sudo pacman -Syu hyprland, nichts verändert"
    fi
done
rm -rf "$TESTHOME/.fakebin"

echo "== 9. --update"
if command -v git >/dev/null 2>&1; then
    G=(git -c user.name=Test -c user.email=test@localhost -c init.defaultBranch=main -c advice.detachedHead=false)
    quelle="$TESTHOME/.quelle"; klon="$TESTHOME/.klon"; uhome="$TESTHOME/.uhome"
    mkdir -p "$quelle" "$uhome"
    # Arbeitsstand des Repos (auch nicht eingecheckte Änderungen) als "GitHub"
    (cd "$REPO" && git ls-files -z --cached --others --exclude-standard | xargs -0 cp --parents -t "$quelle")
    "${G[@]}" -C "$quelle" init -q && "${G[@]}" -C "$quelle" add -A && "${G[@]}" -C "$quelle" commit -qm Stand
    "${G[@]}" clone -q "$quelle" "$klon"
    HOME="$uhome" "$klon/install.sh" --yes --no-packages > "$TESTHOME/.ausgabe" 2>&1 || { cat "$TESTHOME/.ausgabe"; fehler=1; }
    echo '{"weather": {"location": "Bern"}, "panel": {"width": 480}}' > "$uhome/.config/hypr-shell/settings.json"
    echo '-- meine user.lua' > "$uhome/.config/hypr/user.lua"
    echo 'return { kb_layout = "ch", kb_variant = "fr", scale = 2 }' > "$uhome/.config/hypr/hypr-shell-local.lua"
    eigene() { sha256sum "$uhome/.config/hypr-shell/settings.json" "$uhome/.config/hypr/user.lua" "$uhome/.config/hypr/hypr-shell-local.lua"; }
    eigen_vorher="$(eigene)"
    # neuer Stand auf "GitHub"
    echo "9.9.9" > "$quelle/VERSION"
    echo "# neu" >> "$quelle/config/kitty/kitty.conf"
    "${G[@]}" -C "$quelle" commit -qam "neuer Stand"
    if HOME="$uhome" "$klon/install.sh" --update --yes --no-packages > "$TESTHOME/.ausgabe" 2>&1; then
        pruefe '[ "$(cat "$uhome/.local/share/hypr-shell/VERSION")" = 9.9.9 ] && tail -n1 "$uhome/.config/kitty/kitty.conf" | grep -q "# neu"' "neuer Stand geholt und installiert"
        pruefe '[ "$eigen_vorher" = "$(eigene)" ]' "settings.json, user.lua und hypr-shell-local.lua unverändert"
    else
        cat "$TESTHOME/.ausgabe"
        pruefe 'false' "--update läuft durch"
    fi
    echo "lokale Änderung" >> "$klon/VERSION"
    echo "8.8.8" > "$quelle/VERSION"; "${G[@]}" -C "$quelle" commit -qam "noch neuer"
    pruefe '! HOME="$uhome" "$klon/install.sh" --update --yes --no-packages > "$TESTHOME/.ausgabe" 2>&1 && grep -q "git pull --ff-only ging nicht" "$TESTHOME/.ausgabe" && [ "$(cat "$uhome/.local/share/hypr-shell/VERSION")" = 9.9.9 ]' "--update bricht bei eigenen Änderungen ab, ohne zu installieren"
else
    echo "  Hinweis: git fehlt, --update nicht geprüft"
fi

if [ "$fehler" -ne 0 ]; then
    echo "Probeinstallation: FEHLER"
    exit 1
fi
echo "Probeinstallation: alles in Ordnung"
