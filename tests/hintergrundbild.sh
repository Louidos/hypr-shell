#!/usr/bin/env bash
# Prüft das mitgelieferte Startbild (theme.wallpaper_default) ohne Bildschirm:
#   1. wallpapers/hypr-shell-bluete.jpg: mindestens 2560×1440, höchstens etwa 1 MB, Quelle und
#      Lizenz in NOTICE
#   2. ohne eigene Auswahl ist das Blütenbild das Startbild; mit theme.wallpaper_default = grau das
#      graue Bild; eine eigene Auswahl bleibt; --standard vergisst sie wieder
#   3. Farbmodus auto (matugen) bleibt beim Blütenbild grau-weiss (nicht rosa)
# shellcheck disable=SC2016
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" KEINE_MELDUNG=1
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
mkdir -p "$HOME"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
B="$REPO/wallpapers/hypr-shell-bluete.jpg"

echo "== 1. Bild und Lizenz"
pruefe '[ -f "$B" ]' "wallpapers/hypr-shell-bluete.jpg ist da"
pruefe '[ "$(stat -c %s "$B")" -le 1150000 ]' "höchstens etwa 1 MB ($(stat -c %s "$B" 2>/dev/null) Bytes)"
im="$(command -v magick || command -v convert || true)"
if [ -n "$im" ]; then
    read -r bw bh < <("$im" "$B[0]" -format '%w %h\n' info: 2>/dev/null)
    pruefe '[ "${bw:-0}" -ge 2560 ] && [ "${bh:-0}" -ge 1440 ]' "mindestens 2560×1440 (${bw:-?}×${bh:-?})"
fi
pruefe 'grep -q "hypr-shell-bluete.jpg" NOTICE && grep -q "CC0" NOTICE && grep -q "commons.wikimedia.org" NOTICE' "Quelle, Urheber und Lizenz stehen in NOTICE"

echo "== 2. Startbild"
"$REPO/install.sh" --yes --no-packages > "$T/install.log" 2>&1 || { tail -n 20 "$T/install.log"; exit 1; }
D="$HOME/.local/share/hypr-shell"
W="$HOME/.local/bin/shell-wallpaper"
pruefe '[ -f "$D/wallpapers/hypr-shell-bluete.jpg" ] && [ -f "$HOME/Pictures/Wallpapers/hypr-shell-bluete.jpg" ]' "Installer legt das Blütenbild ab"
pruefe '[ "$(jq -r ".keys[] | select(.key == \"theme.wallpaper_default\") | .default" settings/schema.json)" = bluete ]' "Standard: bluete"
pruefe '[ "$("$W" --current)" = "$D/wallpapers/hypr-shell-bluete.jpg" ]' "ohne eigene Auswahl: das Blütenbild"
"$HOME/.local/bin/shell-set" theme.wallpaper_default grau >/dev/null 2>&1
pruefe '[ "$("$W" --current)" = "$D/wallpapers/hypr-shell-grau.png" ]' "theme.wallpaper_default grau: das graue Bild"
pruefe '! "$HOME/.local/bin/shell-set" theme.wallpaper_default rosa >/dev/null 2>&1' "unbekanntes Startbild wird abgelehnt"
"$HOME/.local/bin/shell-set" reset theme.wallpaper_default >/dev/null 2>&1
mkdir -p "$HOME/Pictures/Wallpapers"; cp "$D/wallpapers/hypr-shell-grau.png" "$HOME/Pictures/Wallpapers/eigenes.png"
printf '%s\n' "$HOME/Pictures/Wallpapers/eigenes.png" > "$D/wallpaper"
pruefe '[ "$("$W" --current)" = "$HOME/Pictures/Wallpapers/eigenes.png" ]' "eine eigene Auswahl bleibt"
"$W" --standard >/dev/null 2>&1
pruefe '[ ! -e "$D/wallpaper" ] && [ "$("$W" --current)" = "$D/wallpapers/hypr-shell-bluete.jpg" ]' "--standard vergisst die eigene Auswahl"
"$W" --restore >/dev/null 2>&1
pruefe '[ ! -e "$D/wallpaper" ]' "--restore merkt sich das Startbild nicht (es folgt theme.wallpaper_default)"

echo "== 3. Farben"
if command -v matugen >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    "$W" --colors >/dev/null 2>&1
    akzent="$(jq -r .accent "$HOME/.config/hypr-shell/colors.json" 2>/dev/null)"
    s="$(python3 -c 'import colorsys,sys; h=sys.argv[1].lstrip("#"); r,g,b=(int(h[i:i+2],16)/255 for i in (0,2,4)); print(round(colorsys.rgb_to_hls(r,g,b)[2],3))' "$akzent" 2>/dev/null)"
    pruefe 'awk -v s="${s:-1}" "BEGIN { exit !(s < 0.15) }"' "Farbmodus auto beim Blütenbild: grau-weiss (Akzent $akzent, Sättigung ${s:-?})"
else
    echo "  Hinweis: matugen fehlt, Farben nicht geprüft"
fi
exit "$fehler"
