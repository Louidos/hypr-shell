#!/usr/bin/env bash
# Prüft den Befehl shell-set ohne Bildschirm in einem leeren HOME:
#   setzen mit Prüfung gegen das Schema (falscher Wert ändert nichts und nennt den Bereich),
#   get/list, reset (Schlüssel, Bereich, alles), undo/redo (höchstens 20 Schritte), Ziehen eines
#   Reglers (--live) ergibt einen Schritt, Profile, Export/Import mit Prüfung, kaputtes JSON,
#   Bildschirm drehen (shell-set monitor … rotate|mirror|transform), Tab-Vervollständigung für
#   bash und fish.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
export HOME="$T/home" KEINE_MELDUNG=1
mkdir -p "$HOME/.config/hypr-shell"
S="$HOME/.config/hypr-shell/settings.json"
LUA="$HOME/.config/hypr/hypr-shell-settings.lua"
printf '{\n  "weather": { "location": "Bern" }\n}\n' > "$S"

fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
ss() { "$REPO/bin/shell-set" "$@"; }
wert() { jq -c "$1" "$S"; }

echo "== setzen"
pruefe 'ss look.rounding 20 >/dev/null && [ "$(wert .look.rounding)" = 20 ]' "shell-set look.rounding 20 schreibt settings.json"
pruefe 'grep -q "\[\"rounding\"\] = 20" "$LUA"' "… und wirkt sofort (hypr-shell-settings.lua neu erzeugt)"
pruefe '[ "$(wert .weather.location)" = "\"Bern\"" ]' "andere Werte bleiben"
pruefe 'jq -e . "$S" >/dev/null && [ "$(wc -l < "$S")" -gt 3 ]' "Datei bleibt lesbar formatiert"
vorher="$(cat "$S")"
out="$(ss look.rounding abc 2>&1 || true)"
pruefe '! ss look.rounding abc >/dev/null 2>&1 && grep -q "between 0 and 30" <<<"$out" && [ "$vorher" = "$(cat "$S")" ]' "shell-set look.rounding abc nennt den Bereich und ändert nichts ($out)"
pruefe '! ss look.rounding 99 >/dev/null 2>&1 && [ "$vorher" = "$(cat "$S")" ]' "Wert ausserhalb des Bereichs wird abgelehnt"
pruefe '! ss panel.corner middle 2>&1 | grep -q "bottom-right" || ! ss panel.corner middle >/dev/null 2>&1' "Auswahl: erlaubte Werte genannt"
pruefe '! ss bar.heigth 40 >/dev/null 2>&1' "unbekannter Schlüssel wird abgelehnt"
pruefe 'ss look.blur.enabled off >/dev/null && [ "$(wert .look.blur.enabled)" = false ]' "Schalter: off = false"
pruefe 'ss bar.modules.left distro,clock >/dev/null && [ "$(wert .bar.modules.left)" = "[\"distro\",\"clock\"]" ]' "Liste als a,b"
pruefe 'ss panel.apps "[\"kitty\",\"firefox\"]" >/dev/null && [ "$(wert .panel.apps)" = "[\"kitty\",\"firefox\"]" ]' "Liste als JSON"
pruefe '! ss bar.modules.left distro,nix >/dev/null 2>&1 && [ "$(wert .bar.modules.left)" = "[\"distro\",\"clock\"]" ]' "unbekannter Listeneintrag wird abgelehnt"
pruefe 'ss theme.font.ui "Noto Sans" >/dev/null && [ "$(ss get theme.font.ui)" = "Noto Sans" ]' "Text mit Leerzeichen, get"
pruefe '[ "$(ss get bar.height)" = 30 ]' "get liefert den Standard, wenn nichts gesetzt ist"
pruefe 'ss list look | grep -q "^\* look.rounding = 20" && ss list look | grep -q "look.gaps.inner = 6 *(default 6)"' "list zeigt Wert, Standard und markiert Geändertes"
pruefe '! ss list nix >/dev/null 2>&1' "list mit unbekanntem Bereich"

echo "== undo und redo"
ss look.rounding 5 >/dev/null
pruefe 'ss undo >/dev/null && [ "$(wert .look.rounding)" = 20 ]' "undo nimmt die letzte Änderung zurück"
pruefe 'ss undo >/dev/null && [ "$(wert .theme.font.ui)" = null ]' "noch ein undo"
pruefe 'ss redo >/dev/null && ss redo >/dev/null && [ "$(wert .look.rounding)" = 5 ]' "redo stellt beides wieder her"
pruefe 'grep -q "\[\"rounding\"\] = 5" "$LUA"' "undo/redo wirken sofort"
pruefe '! ss redo >/dev/null 2>&1' "nichts mehr zum Wiederholen"
for i in $(seq 1 25); do ss bar.height $((30 + i)) >/dev/null; done
pruefe '[ "$(find "$HOME/.local/share/hypr-shell/history/undo" -name "*.json" | wc -l)" = 20 ]' "Verlauf hält die letzten 20 Schritte"
n=0; while ss undo >/dev/null 2>&1; do n=$((n + 1)); done
pruefe '[ "$n" = 20 ] && [ "$(wert .bar.height)" = 35 ]' "20 Schritte zurück"
ss reset all >/dev/null; ss weather.location Bern >/dev/null
ss look.rounding 10 >/dev/null
for v in 11 12 13 14; do ss --live look.rounding "$v"; done
ss look.rounding 15 >/dev/null
pruefe 'ss undo >/dev/null && [ "$(wert .look.rounding)" = 10 ]' "Ziehen eines Reglers (--live …, dann Endwert) ist ein Schritt"

echo "== reset"
ss look.gaps.inner 9 >/dev/null; ss look.gaps.outer 30 >/dev/null; ss bar.height 40 >/dev/null
pruefe 'ss reset look.gaps.inner >/dev/null && [ "$(wert .look.gaps.inner)" = null ] && [ "$(wert .look.gaps.outer)" = 30 ]' "reset eines Schlüssels"
pruefe 'ss reset look >/dev/null && [ "$(wert .look)" = null ] && [ "$(wert .bar.height)" = 40 ]' "reset eines Bereichs"
pruefe 'ss reset all >/dev/null && [ "$(cat "$S" | jq -c .)" = "{}" ]' "reset all"
pruefe 'ss undo >/dev/null && [ "$(wert .bar.height)" = 40 ]' "reset lässt sich rückgängig machen"

echo "== Profile, Export und Import"
ss look.rounding 22 >/dev/null; ss bar.position bottom >/dev/null
stand="$(jq -cS . "$S")"
pruefe 'ss profile save mein-profil >/dev/null && [ -f "$HOME/.config/hypr-shell/profiles/mein-profil.json" ]' "profile save"
ss reset all >/dev/null; ss look.gaps.inner 1 >/dev/null
pruefe 'ss profile load mein-profil >/dev/null && [ "$(jq -cS . "$S")" = "$stand" ]' "profile load stellt alle Werte wieder her"
pruefe 'ss profile list | grep -qx mein-profil' "profile list"
pruefe '! ss profile save "../böse" >/dev/null 2>&1' "Profilname wird geprüft"
pruefe 'ss export "$T/export.json" >/dev/null && [ "$(jq -cS . "$T/export.json")" = "$stand" ]' "export"
echo '{"bar": {"height": 5}}' > "$T/falsch.json"
pruefe '! ss import "$T/falsch.json" >/dev/null 2>&1 && [ "$(jq -cS . "$S")" = "$stand" ]' "import mit falschem Wert wird abgelehnt"
echo '{"bar": {"height": 33' > "$T/kaputt.json"
pruefe '! ss import "$T/kaputt.json" >/dev/null 2>&1 && [ "$(jq -cS . "$S")" = "$stand" ]' "import mit kaputtem JSON wird abgelehnt"
echo '{"bar": {"height": 33}}' > "$T/gut.json"
pruefe 'ss import "$T/gut.json" >/dev/null && [ "$(wert .bar.height)" = 33 ] && ss undo >/dev/null && [ "$(jq -cS . "$S")" = "$stand" ]' "import, undo"
pruefe 'ss profile delete mein-profil >/dev/null && ! ss profile list | grep -q mein-profil' "profile delete"

echo "== kaputte settings.json"
printf '{ "bar": ' > "$S"
pruefe '! ss look.rounding 3 >/dev/null 2>&1 && [ "$(cat "$S")" = "{ \"bar\": " ]' "kaputtes JSON: shell-set ändert nichts und sagt, was zu tun ist"
pruefe 'ss import "$T/gut.json" >/dev/null && [ "$(wert .bar.height)" = 33 ]' "import repariert die Datei"
printf '{ "bar": ' > "$S"
out="$(ss look.rounding 3 2>&1 || true)"; chk="$("$REPO/bin/shell-apply" --check || true)"
pruefe '! grep -q "jq:" <<<"$out$chk" && ! grep -qF "$S" <<<"$out$chk" && grep -q "Unfinished JSON" <<<"$out" && grep -q "^JSON: Unfinished JSON" <<<"$chk"' "Meldung ohne »jq:« und ohne Dateipfad ($chk)"
: > "$S"
out="$(ss look.rounding 3 2>&1 || true)"; chk="$("$REPO/bin/shell-apply" --check || true)"
pruefe '! ss look.rounding 3 >/dev/null 2>&1 && grep -q "(the file is empty)" <<<"$out" && [ "$chk" = "JSON: the file is empty" ]' "leere Datei: verständliche Meldung ($chk)"
pruefe '"$REPO/bin/shell-apply" --no-reload 2>/dev/null && grep -q "^settings.json is not valid JSON (the file is empty)" "$HOME/.local/share/hypr-shell/settings.errors"' "… auch beim Anwenden"
echo '{"look": 5, "bar": {"height": 33}}' > "$S"
pruefe 'ss look.rounding 18 >/dev/null 2>&1 && [ "$(wert .look)" = "{\"rounding\":18}" ] && [ "$(wert .bar.height)" = 33 ]' "Gruppe als einzelner Wert ({\"look\": 5}): setzen ersetzt die Gruppe"
echo '{"look": 5, "bar": {"height": 33}}' > "$S"
pruefe 'ss reset look.rounding >/dev/null 2>&1 && [ "$(wert .look)" = null ] && [ "$(wert .bar.height)" = 33 ]' "… reset entfernt sie"
echo '{"look": {"gaps": [1]}}' > "$S"
pruefe 'ss look.gaps.inner 9 >/dev/null 2>&1 && [ "$(wert .look.gaps)" = "{\"inner\":9}" ]' "… auch tiefer verschachtelt"

echo "== Zahlen"
echo '{}' > "$S"
for v in nan NaN -nan; do
    pruefe '! ss bar.opacity "$v" >/dev/null 2>&1 && [ "$(jq -c . "$S")" = "{}" ]' "»$v« wird abgelehnt"
done
pruefe '! ss bar.opacity inf >/dev/null 2>&1 && ss bar.opacity .5 >/dev/null && [ "$(wert .bar.opacity)" = 0.5 ]' "unendlich abgelehnt, .5 geht"

echo "== Vervollständigung"
pruefe 'ss __complete keys | grep -qx look.rounding && ss __complete areas | grep -qx look.blur && [ "$(ss __complete values bar.position | tr "\n" " ")" = "top bottom " ]' "Schlüssel, Bereiche und Werte aus dem Schema"
mkdir -p "$T/bin"; ln -s "$REPO/bin/shell-set" "$T/bin/shell-set"
echo "== Bildschirm drehen"
pruefe 'ss monitors.outputs "[{\"name\":\"eDP-1\",\"resolution\":\"2560x1600\",\"scale\":\"1.6\"}]" >/dev/null && [ "$(jq -r ".monitors.outputs[0] | has(\"transform\")" "$S")" = false ]' "alter Eintrag ohne transform wird angenommen"
pruefe '[ "$(ss get monitors.outputs | jq -r ".[0].transform")" = normal ]' "… und gilt als normal"
pruefe 'ss monitor eDP-1 rotate 90 >/dev/null && [ "$(jq -c ".monitors.outputs[0]" "$S")" = "{\"name\":\"eDP-1\",\"resolution\":\"2560x1600\",\"scale\":\"1.6\",\"transform\":\"90\"}" ]' "shell-set monitor eDP-1 rotate 90: Drehung gesetzt, übrige Werte bleiben"
pruefe 'grep -q "\"90\"" "$LUA"' "… und wirkt sofort (hypr-shell-settings.lua)"
pruefe 'ss monitor eDP-1 mirror on >/dev/null && [ "$(jq -r ".monitors.outputs[0].transform" "$S")" = flipped-90 ]' "mirror on behält die Drehung (flipped-90)"
pruefe 'ss monitor eDP-1 rotate 270 >/dev/null && [ "$(jq -r ".monitors.outputs[0].transform" "$S")" = flipped-270 ]' "rotate behält die Spiegelung (flipped-270)"
pruefe 'ss monitor eDP-1 mirror off >/dev/null && ss monitor eDP-1 rotate 0 >/dev/null && [ "$(jq -r ".monitors.outputs[0].transform" "$S")" = normal ]' "zurück auf normal"
pruefe 'ss monitor HDMI-A-1 transform flipped >/dev/null && [ "$(jq -c ".monitors.outputs[1]" "$S")" = "{\"name\":\"HDMI-A-1\",\"transform\":\"flipped\"}" ]' "neuer Bildschirm wird angehängt"
vorher="$(cat "$S")"
for falsch in "monitor eDP-1 rotate 45" "monitor eDP-1 rotate links" "monitor eDP-1 mirror vielleicht" "monitor eDP-1 transform sideways" "monitor eDP-1 drehen 90" "monitor e;x rotate 90" "monitor eDP-1"; do
    # shellcheck disable=SC2086
    out="$(ss $falsch 2>&1 || true)"
    # shellcheck disable=SC2086
    pruefe '! ss $falsch >/dev/null 2>&1 && grep -qE "invalid|unknown|shell-set monitor" <<<"$out" && [ "$vorher" = "$(cat "$S")" ]' "abgelehnt mit Meldung: shell-set $falsch ($out)"
done
pruefe '! ss monitors.outputs "[{\"name\":\"X\",\"transform\":\"sideways\"}]" >/dev/null 2>&1 && [ "$vorher" = "$(cat "$S")" ]' "ungültige Drehung über monitors.outputs wird abgelehnt"
ss undo >/dev/null 2>&1 || true

komplett() { PATH="$T/bin:$PATH" bash -c 'source settings/completions/shell-set.bash; COMP_WORDS=("$@"); COMP_CWORD=$(($# - 1)); _shell_set; printf "%s\n" "${COMPREPLY[@]}"' _ "$@"; }
pruefe 'komplett shell-set look.ro | grep -qx look.rounding' "bash: Schlüssel"
pruefe '[ "$(komplett shell-set panel.corner bottom- | tr "\n" " ")" = "bottom-right bottom-left " ]' "bash: Werte"
pruefe 'komplett shell-set pro | grep -qx profile' "bash: Befehle"
pruefe '[ "$(komplett shell-set monitor eDP-1 r | tr "\n" " ")" = "rotate " ] && [ "$(komplett shell-set monitor eDP-1 rotate "" | tr "\n" " ")" = "0 90 180 270 " ]' "bash: monitor … rotate 0 90 180 270"
pruefe '[ "$(komplett shell-set monitor eDP-1 mirror "" | tr "\n" " ")" = "on off " ] && komplett shell-set monitor "" | grep -qx eDP-1' "bash: mirror on/off, Bildschirmnamen"
if command -v fish >/dev/null 2>&1; then
    pruefe 'PATH="$T/bin:$PATH" fish -c "source settings/completions/shell-set.fish; complete -C \"shell-set look.ro\"" | grep -q "^look.rounding"' "fish: Schlüssel"
    pruefe 'PATH="$T/bin:$PATH" fish -c "source settings/completions/shell-set.fish; complete -C \"shell-set monitor eDP-1 rotate \"" | grep -qx 270' "fish: monitor … rotate"
else
    pruefe 'grep -q "complete -c shell-set" settings/completions/shell-set.fish' "fish-Datei vorhanden (fish fehlt, nicht ausgeführt)"
fi

echo "== Design-Werte (Karten, Leuchten, Abstände, Schrift)"
pruefe 'ss theme.card.opacity 0.15 >/dev/null && [ "$(wert .theme.card.opacity)" = 0.15 ]' "theme.card.opacity 0.15"
pruefe '! ss theme.card.opacity 0.5 >/dev/null 2>&1 && ! ss theme.card.hover 0.6 >/dev/null 2>&1 && ! ss theme.card.border_opacity 2 >/dev/null 2>&1' "Karten: Werte über der Grenze (0.4, 0.5, 1) abgelehnt"
pruefe '! ss theme.card.color blau >/dev/null 2>&1 && ss theme.card.color "#ddeeff" >/dev/null' "Kartenfarbe: nur Farben"
pruefe 'ss theme.border.glow true >/dev/null && [ "$(wert .theme.border.glow)" = true ] && ! ss theme.border.glow vielleicht >/dev/null 2>&1' "Leuchten an, kein Unsinn"
pruefe '! ss theme.border.glow_size 41 >/dev/null 2>&1 && ss theme.border.glow_size 40 >/dev/null && ! ss theme.border.glow_opacity 1.5 >/dev/null 2>&1' "Leuchten: Grösse 0–40, Deckkraft 0–1"
pruefe '! ss theme.spacing.scale 0.4 >/dev/null 2>&1 && ! ss theme.spacing.scale 2.5 >/dev/null 2>&1 && ss theme.spacing.scale 1.5 >/dev/null' "Abstände: Faktor 0.5–2"
pruefe 'ss set theme.spacing.panel 20 theme.spacing.card 16 theme.spacing.gap 12 >/dev/null && [ "$(wert "[.theme.spacing.panel, .theme.spacing.card, .theme.spacing.gap]")" = "[20,16,12]" ] && ! ss theme.spacing.gap -1 >/dev/null 2>&1' "Innenabstände und Lücke"
pruefe 'ss theme.font.title_weight demibold >/dev/null && ! ss theme.font.title_weight heavy >/dev/null 2>&1 && ! ss theme.font.text_weight 900 >/dev/null 2>&1' "Schriftdicke: normal, medium, demibold, bold"
pruefe '! ss theme.font.title_scale 0.5 >/dev/null 2>&1 && ss theme.font.title_scale 1.25 >/dev/null' "Titelgrösse 0.8–2"
pruefe '! ss theme.pill.opacity 0.1 >/dev/null 2>&1 && ss theme.pill.opacity 0.8 >/dev/null' "Pille: 0.3–1"
pruefe 'ss reset theme >/dev/null && [ "$(wert .theme)" = null ]' "reset theme entfernt alle Design-Werte wieder"

exit "$fehler"
