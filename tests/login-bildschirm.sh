#!/usr/bin/env bash
# Prüft den Anmeldebildschirm (./install.sh --login-theme / --login-theme-remove) in einer
# Wurzel-Attrappe (HYPR_SHELL_ROOT, nie das echte /etc): bricht ohne SDDM ab, ohne etwas zu ändern,
# prüft das Thema im Testmodus des Greeters (echter sddm-greeter, sonst die QML-Attrappe),
# sichert und holt den vorherigen Stand genau zurück; die normale Installation fasst SDDM nicht an.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" HYPR_SHELL_ROOT="$T/root"
[ "$(id -u)" -eq 0 ] && export HYPR_SHELL_ALLOW_ROOT=1
R="$T/root"
mkdir -p "$HOME/.config/hypr-shell" "$HOME/.local/share/hypr-shell" "$T/bin" "$R/etc/systemd/system" "$R/usr/share/sddm/themes/breeze"
printf '{"accent": "#8ab4f8", "text": "#e3e2e6", "subtext": "#c4c6d0", "surface": "#111318", "error": "#ffb4ab"}\n' > "$HOME/.config/hypr-shell/colors.json"
printf '[Theme]\nCurrent=breeze\n\n[Users]\nMaximumUid=60000\n' > "$R/etc/sddm.conf"
printf 'breeze\n' > "$R/usr/share/sddm/themes/breeze/Main.qml"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
stand() { (cd "$R" && find . -printf '%y %p %l\n' | LC_ALL=C sort; find . -type f -exec md5sum {} + | LC_ALL=C sort); }
inst() { PATH="$T/bin:$PATH" "$REPO/install.sh" "$@" > "$T/out" 2>&1; }

# Greeter: der echte (CI mit sddm), sonst die QML-Attrappe, sonst einer, der nur wartet
echt="$(command -v sddm-greeter-qt6 || command -v sddm-greeter || true)"
qml="$(command -v qml6 || command -v qml || ls /usr/lib/qt6/bin/qml 2>/dev/null || true)"
if [ -n "$echt" ]; then
    echo "Hinweis: echter Greeter ($echt)"
elif [ -n "$qml" ]; then
    echo "Hinweis: Greeter-Attrappe mit $qml"
    printf '#!/bin/sh\n# --test-mode --theme DIR\nexec "%s" "%s" -- "$3"\n' "$qml" "$REPO/tests/daten/sddm-attrappe.qml" > "$T/bin/sddm-greeter-qt6"
    chmod +x "$T/bin/sddm-greeter-qt6"
else
    echo "Hinweis: weder sddm-greeter noch qml – nur der Ablauf wird geprüft"
    printf '#!/bin/sh\nsleep 30\n' > "$T/bin/sddm-greeter-qt6"; chmod +x "$T/bin/sddm-greeter-qt6"
fi

echo "== kein SDDM: Abbruch ohne Änderung"
vorher="$(stand)"
ln -s /usr/lib/systemd/system/gdm.service "$R/etc/systemd/system/display-manager.service"
pruefe '! inst --login-theme --yes && grep -q "Aktiver Anmeldemanager ist gdm, nicht SDDM" "$T/out"' "GDM aktiv: klare Meldung"
rm "$R/etc/systemd/system/display-manager.service"
pruefe '! inst --login-theme --yes && grep -q "ist keiner, nicht SDDM" "$T/out"' "kein Anmeldemanager: klare Meldung"
pruefe '[ "$(stand)" = "$vorher" ] && [ ! -e "$HOME/.local/share/hypr-shell/login-theme" ]' "nichts geändert"

ln -s /usr/lib/systemd/system/sddm.service "$R/etc/systemd/system/display-manager.service"
vorher="$(stand)"

echo "== Thema, das im Testmodus nicht startet"
mkdir -p "$T/kaputt"
printf '#!/bin/sh\necho "file:///x/Main.qml:12: ReferenceError: foo is not defined"\nsleep 30\n' > "$T/kaputt/sddm-greeter-qt6"
chmod +x "$T/kaputt/sddm-greeter-qt6"
pruefe '! PATH="$T/kaputt:$PATH" "$REPO/install.sh" --login-theme --yes > "$T/out" 2>&1 && grep -q "startet im Testmodus nicht" "$T/out" && [ "$(stand)" = "$vorher" ]' "Abbruch, nichts geändert"

echo "== --login-theme"
export HYPR_SHELL_GREETER_ZEIT=12
pruefe 'inst --login-theme --yes' "läuft durch ($(tail -n1 "$T/out" 2>/dev/null))"
if grep -q "Thema startet im Testmodus (" "$T/out"; then echo "  ok: Thema startet im Testmodus ohne Fehler"
else echo "  FEHLER: Testmodus"; cat "$T/out"; fehler=1; fi
Z="$R/usr/share/sddm/themes/hypr-shell"
pruefe '[ -f "$Z/Main.qml" ] && [ -f "$Z/metadata.desktop" ] && [ -f "$Z/fonts/BebasNeue-Regular.ttf" ] && [ -f "$Z/background.png" ]' "Thema mit Schrift und Hintergrund"
pruefe 'grep -qx "accent=#8ab4f8" "$Z/theme.conf" && grep -qx "surface=#111318" "$Z/theme.conf"' "Farben aus dem Hintergrundbild"
pruefe 'grep -qx "Current=hypr-shell" "$R/etc/sddm.conf.d/99-hypr-shell.conf"' "sddm.conf.d/99-hypr-shell.conf"
pruefe 'grep -qx "Current=hypr-shell" "$R/etc/sddm.conf" && grep -qx "MaximumUid=60000" "$R/etc/sddm.conf"' "Thema in /etc/sddm.conf (dort stand breeze), Rest bleibt"
pruefe '[ -f "$R/usr/share/sddm/themes/breeze/Main.qml" ]' "anderes Thema bleibt"
pruefe 'inst --login-theme --yes && grep -qx "Current=breeze" "$HOME/.local/share/hypr-shell/login-theme/sddm.conf"' "zweiter Aufruf: Sicherung bleibt die erste"

echo "== --uninstall lässt die Sicherung des Anmeldebildschirms stehen"
pruefe 'grep -q "! -name login-theme" "$REPO/install.sh"' "Sicherung bleibt bei --uninstall"

echo "== --login-theme-remove"
pruefe 'inst --login-theme-remove --yes' "läuft durch"
pruefe '[ "$(stand)" = "$vorher" ]' "vorheriger Zustand genau zurück"
pruefe '[ ! -e "$HOME/.local/share/hypr-shell/login-theme" ]' "Sicherung aufgeräumt"
pruefe '! inst --login-theme-remove --yes && grep -q "nicht installiert" "$T/out"' "zweimal entfernen: Meldung"

echo "== ohne /etc/sddm.conf und sddm.conf.d"
rm -f "$R/etc/sddm.conf"
vorher="$(stand)"
inst --login-theme --yes >/dev/null 2>&1 || true
pruefe '[ ! -e "$R/etc/sddm.conf" ] && [ -f "$R/etc/sddm.conf.d/99-hypr-shell.conf" ]' "nur die eigene Datei in sddm.conf.d"
inst --login-theme-remove --yes >/dev/null 2>&1 || true
pruefe '[ "$(stand)" = "$vorher" ]' "danach genau wie vorher (auch sddm.conf.d wieder weg)"

echo "== die normale Installation fasst den Anmeldemanager nicht an"
body="$(awk '/^installieren\(\) \{/ { p = 1 } p { print } p && /^\}/ { exit }' "$REPO/install.sh")"
pruefe '[ -n "$body" ] && ! grep -Eq "SDDM|login_thema|sddm" <<<"$body"' "installieren() kennt SDDM nicht"
pruefe '[ "$(grep -Ec "[^_a-z]login_thema([^_(a-z]|\$)" "$REPO/install.sh")" = 1 ] && grep -q "login) login_thema ;;" "$REPO/install.sh"' "nur über --login-theme"
exit "$fehler"
