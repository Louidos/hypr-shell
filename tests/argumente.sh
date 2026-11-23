#!/usr/bin/env bash
# Prüft, dass die Hilfsprogramme in bin/ bei einem fehlenden Argument mit einer klaren Meldung
# ("shell-x: … fehlt", Rückgabe 2) aufhören – nicht mit "Zeile N: 2: …" und nicht still weiterlaufen.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" KEINE_MELDUNG=1
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
mkdir -p "$HOME/.config/hypr-shell" "$HOME/.local/share/hypr-shell"
echo '{}' > "$HOME/.config/hypr-shell/settings.json"
fehler=0

echo "== fehlende Argumente"
while read -r prog args; do
    # shellcheck disable=SC2086
    aus="$(timeout 10 "$REPO/bin/$prog" $args 2>&1 </dev/null)"; rc=$?
    if [ "$rc" -eq 2 ] && grep -qE "^$prog: .*fehl" <<<"$aus" && ! grep -qE "line [0-9]+|Zeile [0-9]+" <<<"$aus"; then
        echo "  ok: $prog $args → $(head -n1 <<<"$aus")"
    else
        echo "  FEHLER: $prog $args (Rückgabe $rc): $(head -n2 <<<"$aus" | tr '\n' ' ')"; fehler=1
    fi
done <<'LISTE'
shell-clipboard copy
shell-clipboard paste
shell-clipboard delete
shell-games launch
shell-laptop profile set
shell-laptop charge set
shell-laptop kbd set
shell-laptop kbd color
shell-missa get
shell-net wifi connect
shell-net bt pair
shell-overview focus
LISTE
exit "$fehler"
