#!/usr/bin/env bash
# Prüft shell-osd ohne Bildschirm mit Attrappen für wpctl, brightnessctl und shell-quickshell:
# Lautstärke ±5 % höchstens 100 %, stumm, Mikrofon, Helligkeit; jede Taste zeigt die eigene Anzeige
# (ipc osd show) und nur diese; swayosd kommt nirgends mehr vor. Dazu das Power-Menü im Probelauf.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
mkdir -p "$HOME/.local/bin" "$T/bin"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }

# Attrappen: Zustand in Dateien
echo 0.50 > "$T/vol"; echo no > "$T/mute"; echo no > "$T/micmute"; echo 50 > "$T/hell"
cat > "$T/bin/wpctl" <<'W'
#!/usr/bin/env bash
d="$(dirname "$0")/.."
case "$1" in
    get-volume) if [ "$2" = @DEFAULT_AUDIO_SOURCE@ ]; then m="$(cat "$d/micmute")"; v=0.80; else m="$(cat "$d/mute")"; v="$(cat "$d/vol")"; fi
                printf 'Volume: %s%s\n' "$v" "$([ "$m" = yes ] && echo ' [MUTED]')" ;;
    set-mute) f="$d/mute"; [ "$2" = @DEFAULT_AUDIO_SOURCE@ ] && f="$d/micmute"
              case "$3" in toggle) if [ "$(cat "$f")" = yes ]; then echo no > "$f"; else echo yes > "$f"; fi ;; 0) echo no > "$f" ;; 1) echo yes > "$f" ;; esac ;;
    set-volume) shift; lim=9; if [ "$1" = -l ]; then lim="$2"; shift 2; fi
                v="$(cat "$d/vol")"; s="${2%\%*}"; r="${2: -1}"
                awk -v v="$v" -v s="$s" -v r="$r" -v l="$lim" 'BEGIN { n = (r == "+") ? v + s / 100 : v - s / 100; if (n > l) n = l; if (n < 0) n = 0; printf "%.2f\n", n }' > "$d/vol" ;;
esac
W
cat > "$T/bin/brightnessctl" <<'B'
#!/usr/bin/env bash
d="$(dirname "$0")/.."
args=("$@"); dev=""
for ((i = 0; i < ${#args[@]}; i++)); do [ "${args[$i]}" = -d ] && dev="${args[$((i + 1))]}"; done
echo "$dev" >> "$d/geraete"
for a in "$@"; do
    case "$a" in *%+) n=$(( $(cat "$d/hell") + ${a%\%+} )); [ $n -gt 100 ] && n=100; echo $n > "$d/hell" ;;
                 *%-) n=$(( $(cat "$d/hell") - ${a%\%-} )); [ $n -lt 0 ] && n=0; echo $n > "$d/hell" ;;
                 -m) echo "intel_backlight,backlight,$(cat "$d/hell"),$(cat "$d/hell")%,100" ;; esac
done
B
printf '#!/usr/bin/env bash\necho "$*" >> "%s/anzeige"\n' "$T" > "$HOME/.local/bin/shell-quickshell"
chmod +x "$T/bin/"* "$HOME/.local/bin/shell-quickshell"
osd() { PATH="$T/bin:$PATH" "$REPO/bin/shell-osd" "$@"; }
letzte() { tail -n1 "$T/anzeige"; }

echo "== Lautstärke"
osd volume up
pruefe '[ "$(cat "$T/vol")" = 0.55 ] && [ "$(letzte)" = "ipc osd show volume 55 false" ]' "Lauter: +5 %, Anzeige zeigt 55 %"
for _ in 1 2 3 4 5 6 7 8 9 10 11; do osd volume up; done
pruefe '[ "$(cat "$T/vol")" = 1.00 ] && [ "$(letzte)" = "ipc osd show volume 100 false" ]' "nie über 100 %"
osd volume down
pruefe '[ "$(letzte)" = "ipc osd show volume 95 false" ]' "Leiser: −5 %"
osd volume mute
pruefe '[ "$(letzte)" = "ipc osd show volume 95 true" ]' "Stumm wird angezeigt"
osd volume up
pruefe '[ "$(cat "$T/mute")" = no ]' "Lauter hebt Stumm auf"
osd mic mute
pruefe '[ "$(letzte)" = "ipc osd show mic 80 true" ]' "Mikrofon stumm"

echo "== Helligkeit"
osd brightness up
pruefe '[ "$(letzte)" = "ipc osd show brightness 55 false" ]' "Bildschirm heller"
osd kbd down
pruefe '[ "$(tail -n1 "$T/geraete")" = "*::kbd_backlight" ] && grep -q "ipc osd show kbd" "$T/anzeige"' "Tastaturlicht über das kbd_backlight-Gerät"

echo "== ohne Programme kein Fehler"
mkdir -p "$T/nix"
for p in bash awk grep head cut tr cat sed dirname readlink; do ln -s "$(command -v "$p")" "$T/nix/$p"; done
pruefe 'PATH="$T/nix" HOME="$T/leer" "$REPO/bin/shell-osd" volume up 2>"$T/err" && [ ! -s "$T/err" ]' "fehlt wpctl/pamixer, passiert still nichts"

echo "== nur die eigene Anzeige"
pruefe '! grep -rq "swayosd" config/hypr/hyprland.lua install.sh && grep -qF "local osd = bin .. \"shell-osd \"" config/hypr/hyprland.lua && grep -qF "osd .. \"volume up\"" config/hypr/hyprland.lua' "Lautstärketasten rufen shell-osd, swayosd ist weg"

echo "== Power-Menü"
pruefe 'HYPR_SHELL_POWER_DRYRUN=1 "$REPO/bin/shell-powermenu" shutdown && [ "$(cat "$HOME/.local/share/hypr-shell/power-dryrun.log")" = shutdown ]' "Probelauf führt nichts aus und vermerkt die Aktion"
pruefe 'grep -q "confirm: true" quickshell/power/PowerMenu.qml && [ "$(grep -c "confirm: true" quickshell/power/PowerMenu.qml)" = 2 ]' "Restart und Shutdown verlangen einen zweiten Druck"
exit "$fehler"
