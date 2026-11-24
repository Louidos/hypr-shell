#!/usr/bin/env bash
# Prüft "Programme mitfärben" (shell-appcolors) in einem leeren Home mit Attrappen für qt6ct, firefox,
# vesktop und spicetify: Vorlagen sind vollständig, eingeschaltete Programme bekommen die Farben,
# ein Bildwechsel bringt neue Farben, Abschalten holt jede Datei genau so zurück, wie sie war,
# und Programme, die fehlen, werden nicht angefasst und erscheinen nicht in den Einstellungen.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }
command -v python3 >/dev/null || { echo "Hinweis: python3 fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
unset XDG_CONFIG_HOME
DATA="$HOME/.local/share/hypr-shell"
C="$HOME/.config"
mkdir -p "$DATA" "$T/bin" "$C"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
# gleicher Inhalt? (cmp aus diffutils fehlt manchmal, sha256sum ist immer da)
gleich() { [ -e "$1" ] && [ -e "$2" ] && [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ]; }
printf '#!/bin/sh\nexit 0\n' > "$T/bin/qt6ct"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/firefox"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/vesktop"
chmod +x "$T/bin/qt6ct" "$T/bin/firefox" "$T/bin/vesktop"
ln -s "$REPO/tests/daten/spicetify" "$T/bin/spicetify"
ac() { PATH="$T/bin:$PATH" "$REPO/bin/shell-appcolors" "$@"; }
einstellen() { jq -n --argjson a "$1" '{theme: {apps: $a}}' > "$DATA/settings.effective.json"; }

# Farben wie von matugen: jeder Name bekommt eine Farbe aus Name und Durchgang
rendern() { # durchgang
    mkdir -p "$DATA/app-colors"
    python3 - "$REPO/config/matugen/templates/apps" "$DATA/app-colors" "$1" <<'PY'
import sys, re, os, hashlib
src, dst, run = sys.argv[1:4]
namen = {"primary","on_primary","primary_container","on_primary_container","secondary","on_secondary","tertiary",
  "surface","surface_dim","surface_bright","surface_container_lowest","surface_container_low","surface_container",
  "surface_container_high","surface_container_highest","on_surface","on_surface_variant","outline","outline_variant",
  "error","on_error","shadow","scrim","background","on_background","inverse_surface","inverse_on_surface","inverse_primary"}
ziel = {"gtk.css":"gtk.css","qt.conf":"qt.conf","firefox.css":"firefox.css","vesktop.css":"vesktop.css","spicetify.ini":"spicetify.ini"}
unbekannt = []
for f, out in ziel.items():
    t = open(os.path.join(src, f)).read()
    def farbe(m):
        if m.group(1) not in namen: unbekannt.append(m.group(1))
        h = hashlib.md5((m.group(1) + run).encode()).hexdigest()[:6]
        return h if m.group(2) == "hex_stripped" else "#" + h
    t = re.sub(r"\{\{colors\.(\w+)\.default\.(hex|hex_stripped)\}\}", farbe, t)
    if "{{" in t: unbekannt.append(f + ": Platzhalter übrig")
    open(os.path.join(dst, out), "w").write(t)
if unbekannt: print("unbekannt:", unbekannt); sys.exit(1)
PY
}

echo "== Vorlagen"
pruefe 'rendern 1' "alle Vorlagen nutzen nur bekannte matugen-Farben"
pruefe 'for f in gtk.css qt.conf firefox.css vesktop.css spicetify.ini; do grep -q "apps/$f" "$REPO/config/matugen/config.toml" || exit 1; done' "matugen kennt alle fünf Vorlagen"
pruefe '[ "$(grep -o "#[0-9a-f]\{6\}" "$DATA/app-colors/qt.conf" | wc -l)" -eq 63 ]' "Qt-Farbschema: drei Gruppen mit je 21 Farben"
if command -v matugen >/dev/null 2>&1; then
    mkdir -p "$T/mg/templates/apps" "$T/mg/out"
    cp "$REPO"/config/matugen/templates/apps/* "$T/mg/templates/apps/"
    sed -e "s|~/.config/matugen|$T/mg|" -e "s|~/.local/share/hypr-shell/app-colors|$T/mg/out|" "$REPO/config/matugen/config.toml" \
        | awk '/^\[templates\.apps-/ { p = 1 } /^\[templates\./ && !/apps-/ { p = 0 } p || /^\[config\]/' > "$T/mg/config.toml"
    pruefe 'matugen color hex "#8ab4f8" --mode dark -c "$T/mg/config.toml" >/dev/null 2>&1 && [ "$(ls "$T/mg/out" | wc -l)" -eq 5 ] && ! grep -q "{{" "$T"/mg/out/*' "echtes matugen rendert alle Vorlagen"
fi

# Ausgangslage des Benutzers: eigene Dateien, die nachher genau so zurückkommen müssen
mkdir -p "$C/gtk-3.0" "$C/qt6ct" "$HOME/.mozilla/firefox/abc.default-release/chrome" "$C/vesktop/settings"
printf '/* meine Anpassung */\nwindow { padding: 1px; }\n' > "$C/gtk-3.0/gtk.css"
printf '[Appearance]\nicon_theme=Papirus\nstyle=Fusion\n\n[Fonts]\ngeneral="Inter,10"\n' > "$C/qt6ct/qt6ct.conf"
printf '[Profile0]\nName=default-release\nIsRelative=1\nPath=abc.default-release\nDefault=1\n\n[General]\nStartWithLastProfile=1\n' > "$HOME/.mozilla/firefox/profiles.ini"
printf '#nav-bar { border: 0 }\n' > "$HOME/.mozilla/firefox/abc.default-release/chrome/userChrome.css"
printf '{"enabledThemes":["mein.theme.css"],"minimizeToTray":true}\n' > "$C/vesktop/settings/settings.json"
mkdir -p "$C/spicetify"; printf '[Setting]\ncurrent_theme = Sleek\ncolor_scheme = Nord\n' > "$C/spicetify/config-xpui.ini"
cp -a "$HOME" "$T/vorher"
liste() { (cd "$1" && find . \( -path ./.local -o -name spicetify.log \) -prune -o -print | LC_ALL=C sort); }

echo "== Standard: GTK und Qt an, die anderen aus"
einstellen '{}'
ac sync
pruefe 'grep -qxF "@import url(\"hypr-shell-colors.css\"); /* hypr-shell */" "$C/gtk-3.0/gtk.css" && grep -q "meine Anpassung" "$C/gtk-3.0/gtk.css"' "GTK 3: Farben eingebunden, eigene Zeilen bleiben"
pruefe '[ "$(head -n1 "$C/gtk-4.0/gtk.css")" = "@import url(\"hypr-shell-colors.css\"); /* hypr-shell */" ] && grep -q "@define-color accent_bg_color" "$C/gtk-4.0/hypr-shell-colors.css"' "GTK 4 (Nautilus): libadwaita-Farben"
pruefe 'grep -q "^custom_palette=true" "$C/qt6ct/qt6ct.conf" && grep -q "^color_scheme_path=$C/qt6ct/colors/hypr-shell.conf" "$C/qt6ct/qt6ct.conf" && grep -q "^icon_theme=Papirus" "$C/qt6ct/qt6ct.conf" && [ "$(grep -c "^\[Appearance\]" "$C/qt6ct/qt6ct.conf")" = 1 ]' "Qt: Farbschema in qt6ct, eigene Werte bleiben"
pruefe '[ ! -e "$C/qt5ct" ]' "Qt: qt5ct fehlt, wird nicht angelegt"
pruefe 'gleich "$HOME/.mozilla/firefox/abc.default-release/chrome/userChrome.css" "$T/vorher/.mozilla/firefox/abc.default-release/chrome/userChrome.css" && gleich "$C/vesktop/settings/settings.json" "$T/vorher/.config/vesktop/settings/settings.json" && [ ! -f "$HOME/spicetify.log" ]' "Firefox, Vesktop und Spotify bleiben aus"
pruefe '[ "$(ac status | jq -c "[.gtk.applied, .qt.applied, .firefox.applied]")" = "[true,true,false]" ]' "Status"

echo "== Bildwechsel"
alt="$(cat "$C/gtk-4.0/hypr-shell-colors.css")"
rendern 2; ac apply
pruefe '[ "$(cat "$C/gtk-4.0/hypr-shell-colors.css")" != "$alt" ] && gleich "$C/gtk-4.0/hypr-shell-colors.css" "$DATA/app-colors/gtk.css"' "Dateimanager (GTK 4) hat die neuen Farben"
pruefe '[ "$(grep -c "hypr-shell-colors.css" "$C/gtk-3.0/gtk.css")" = 1 ]' "Einbindung nur einmal"
pruefe 'gleich "$C/qt6ct/colors/hypr-shell.conf" "$DATA/app-colors/qt.conf"' "Qt hat die neuen Farben"

echo "== Firefox, Vesktop und Spotify einschalten"
einstellen '{"firefox": true, "vesktop": true, "spotify": true}'
ac sync
P="$HOME/.mozilla/firefox/abc.default-release"
pruefe '[ "$(head -n1 "$P/chrome/userChrome.css")" = "@import url(\"hypr-shell-colors.css\"); /* hypr-shell */" ] && grep -q "border: 0" "$P/chrome/userChrome.css" && grep -q "legacyUserProfileCustomizations.stylesheets\", true" "$P/user.js"' "Firefox: userChrome.css und user.js"
pruefe '[ "$(jq -c .enabledThemes "$C/vesktop/settings/settings.json")" = "[\"mein.theme.css\",\"hypr-shell.theme.css\"]" ] && [ "$(jq .minimizeToTray "$C/vesktop/settings/settings.json")" = true ] && grep -q "@name hypr-shell" "$C/vesktop/themes/hypr-shell.theme.css"' "Vesktop: Thema dazu, eigene Einstellungen bleiben"
pruefe 'grep -q "^current_theme = hypr-shell" "$C/spicetify/config-xpui.ini" && grep -q "^apply" "$HOME/spicetify.log" && [ -f "$C/spicetify/Themes/hypr-shell/color.ini" ]' "Spotify: spicetify-Thema und apply"
ac sync
pruefe '[ "$(jq -c .enabledThemes "$C/vesktop/settings/settings.json")" = "[\"mein.theme.css\",\"hypr-shell.theme.css\"]" ] && [ "$(grep -c legacyUserProfile "$P/user.js")" = 1 ]' "zweimal einschalten ändert nichts doppelt"

echo "== alles ausschalten: Ursprungszustand"
einstellen '{"gtk": false, "qt": false, "firefox": false, "vesktop": false, "spotify": false}'
ac sync
pruefe '[ "$(liste "$HOME")" = "$(liste "$T/vorher")" ]' "keine Datei mehr da, die vorher fehlte"
pruefe '( for f in .config/gtk-3.0/gtk.css .config/qt6ct/qt6ct.conf .mozilla/firefox/abc.default-release/chrome/userChrome.css .config/vesktop/settings/settings.json .config/spicetify/config-xpui.ini; do gleich "$HOME/$f" "$T/vorher/$f" || { echo "    anders: $f"; exit 1; }; done )' "jede geänderte Datei ist wieder wie vorher"
pruefe '[ "$(tail -n1 "$HOME/spicetify.log")" = apply ]' "Spotify: spicetify apply nach dem Zurücklegen"
pruefe '[ ! -d "$DATA/app-colors/backup/gtk" ] && [ "$(ac status | jq -c "[.gtk.applied, .spotify.applied]")" = "[false,false]" ]' "Sicherungen aufgeräumt"

echo "== gtk.css als Link (z. B. aus einem Dotfiles-Ordner)"
mkdir -p "$T/dotfiles"; printf '/* dotfiles */\n' > "$T/dotfiles/gtk.css"
ln -s "$T/dotfiles/gtk.css" "$C/gtk-3.0/gtk.css.neu"; mv -f "$C/gtk-3.0/gtk.css.neu" "$C/gtk-3.0/gtk.css"
einstellen '{"gtk": true, "qt": false}'
ac sync
pruefe '[ "$(cat "$T/dotfiles/gtk.css")" = "/* dotfiles */" ] && grep -q "dotfiles" "$C/gtk-3.0/gtk.css"' "das Linkziel bleibt unberührt"
einstellen '{"gtk": false, "qt": false}'
ac sync
pruefe '[ -L "$C/gtk-3.0/gtk.css" ] && [ "$(readlink "$C/gtk-3.0/gtk.css")" = "$T/dotfiles/gtk.css" ]' "nach dem Ausschalten wieder der Link"

echo "== fehlende Programme"
rm -f "$T/bin/vesktop" "$T/bin/firefox"
c="$(ac caps)"
if ! command -v vesktop >/dev/null && ! command -v firefox >/dev/null; then
    pruefe '[ "$(jq -c "[.vesktop, .firefox, .qtct, .spicetify]" <<<"$c")" = "[false,false,true,true]" ]' "Vesktop und Firefox fehlen: keine Zeile in den Einstellungen"
    einstellen '{"gtk": false, "qt": false, "vesktop": true, "firefox": true}'
    rm -rf "$C/vesktop"
    ac sync
    pruefe '[ ! -e "$C/vesktop" ] && ! grep -q hypr-shell "$P/chrome/userChrome.css"' "eingeschaltet, aber nicht installiert: nichts angefasst"
fi
pruefe 'jq -e "[.keys[] | select(.key | startswith(\"theme.apps.\")) | .requires] == [null, \"qtct\", \"firefox\", \"vesktop\", \"spicetify\"]" "$REPO/settings/schema.json" >/dev/null' "Einstellungen: Zeilen nur mit dem Programm"

echo "== Deinstallation legt alles zurück"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/firefox"; chmod +x "$T/bin/firefox"
einstellen '{"gtk": true, "qt": true, "firefox": true}'
ac sync
ac restore
pruefe 'gleich "$P/chrome/userChrome.css" "$T/vorher/.mozilla/firefox/abc.default-release/chrome/userChrome.css" && [ -L "$C/gtk-3.0/gtk.css" ] && [ ! -e "$C/gtk-4.0" ]' "restore: Ursprungszustand"
pruefe 'grep -q "shell-appcolors\" restore" "$REPO/install.sh"' "install.sh --uninstall ruft restore"
exit "$fehler"
