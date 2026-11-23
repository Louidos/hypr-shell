#!/usr/bin/env bash
# Prüft die Daten und Aktionen der Fenster-Übersicht (shell-overview) mit einer hyprctl-Attrappe:
# jedes sichtbare Fenster an seiner Arbeitsfläche, versteckte fehlen; Klick → focus mit Adresse,
# Ziehen → move ohne Folgen; ungültige Adressen werden abgelehnt; ohne Hyprland leere Listen.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
ln -s "$REPO/tests/daten/hyprctl" "$T/bin/hyprctl"
export HYPRCTL_LOG="$T/log"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
ov() { PATH="$T/bin:$PATH" HYPRLAND_INSTANCE_SIGNATURE=x "$REPO/bin/shell-overview" "$@"; }

d="$(ov data)"
pruefe '[ "$(jq -r "[.clients[] | \"\(.workspace.id):\(.class)\"] | join(\",\")" <<<"$d")" = "1:kitty,1:firefox,3:org.gnome.Nautilus" ]' "alle offenen Fenster an der richtigen Arbeitsfläche, versteckte fehlen"
pruefe '[ "$(jq ".active" <<<"$d")" = 1 ] && [ "$(jq ".monitors | length" <<<"$d")" = 1 ]' "aktive Arbeitsfläche und Bildschirm"
ov focus 0x55d3c0a1b3d0
pruefe '[ "$(tail -n1 "$T/log")" = "dispatch hl.dsp.focus({ window = \"address:0x55d3c0a1b3d0\" })" ]' "Klick springt zum Fenster"
ov move 55d3c0a1b2c0 3
pruefe '[ "$(tail -n1 "$T/log")" = "dispatch hl.dsp.window.move({ window = \"address:0x55d3c0a1b2c0\", workspace = 3, follow = false })" ]' "Ziehen verschiebt das Fenster (ohne zu folgen)"
pruefe '! ov focus "0x1\") os.exit(" 2>/dev/null && ! ov move 0x12 "3; x" 2>/dev/null' "ungültige Adresse oder Arbeitsfläche wird abgelehnt"
pruefe '[ "$(env -u HYPRLAND_INSTANCE_SIGNATURE PATH="$T/bin:$PATH" "$REPO/bin/shell-overview" data | jq -c .clients)" = "[]" ]' "ohne Hyprland leere Listen"
exit "$fehler"
