#!/usr/bin/env bash
# Prüft ALT+Tab ohne Bildschirm (die Leiste selbst prüft tests/oberflaeche.sh):
#   1. hyprland.lua: ALT+Tab und ALT+SHIFT+Tab öffnen den Umschalter; Submap hypr-shell-switcher mit
#      Wechseln beim Loslassen von ALT (Alt_L/Alt_R, release), Escape bricht ab, Q/Entf schliesst;
#      ein anderer Modifikator (SUPER + Tab) wechselt beim Loslassen von SUPER; aus = keine Kürzel
#   2. shell-switcher: betritt die Submap; antwortet die Oberfläche nicht, sofort wieder hinaus
# shellcheck disable=SC2016,SC2034
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" KEINE_MELDUNG=1 HYPR_SHELL_INPUT_DEVICES=/nonexistent
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
mkdir -p "$HOME/.config/hypr-shell" "$T/bin"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
lua=$(command -v lua5.4 || command -v lua || true)
kuerzel() { # settings-json -> "global: …" und "submap: …" (Tasten|Aktion|release)
    printf '%s\n' "$1" > "$HOME/.config/hypr-shell/settings.json"
    "$REPO/bin/shell-apply" --no-reload --no-migrate >/dev/null 2>&1
    "$lua" - <<'LUA'
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
for k, a in pairs(A.binds) do
    if type(a) == "table" and tostring(a.arg):find("shell-switcher", 1, true) then print("global: " .. k .. "|" .. tostring(a.arg):match("shell%-switcher (%a+)")) end
end
local s = A.submaps["hypr-shell-switcher"]
if s then
    for k, a in pairs(s.binds) do
        print("submap: " .. k .. "|" .. tostring(a.arg):match("shell%-switcher (%a+)") .. "|" .. tostring(s.flags[k].release == true))
    end
end
LUA
}
if [ -n "$lua" ]; then
    echo "== 1. Kürzel und Submap"
    k="$(kuerzel '{}')"; [ -n "${ZEIGE:-}" ] && echo "$k"
    pruefe 'grep -qx "global: ALT + Tab|next" <<<"$k" && grep -qx "global: ALT + SHIFT + Tab|prev" <<<"$k"' "ALT+Tab vorwärts, ALT+SHIFT+Tab rückwärts"
    pruefe 'grep -qx "submap: ALT + Alt_L|commit|true" <<<"$k" && grep -qx "submap: ALT + Alt_R|commit|true" <<<"$k" && grep -qx "submap: Alt_L|commit|true" <<<"$k"' "ALT loslassen wechselt (beide ALT-Tasten)"
    pruefe 'grep -qx "submap: Escape|cancel|false" <<<"$k" && grep -qx "submap: ALT + Escape|cancel|false" <<<"$k"' "Escape bricht ab (mit und ohne ALT)"
    pruefe 'grep -qx "submap: ALT + Q|close|false" <<<"$k" && grep -qx "submap: ALT + Delete|close|false" <<<"$k"' "Q und Entf schliessen das gewählte Fenster"
    pruefe 'grep -qx "submap: ALT + Tab|next|false" <<<"$k" && grep -qx "submap: ALT + right|next|false" <<<"$k" && grep -qx "submap: ALT + left|prev|false" <<<"$k"' "in der Submap: Tab und Pfeile wählen"
    k="$(kuerzel '{"keybinds": {"switcher": "SUPER + grave", "switcher_back": "SUPER + SHIFT + grave"}}')"
    pruefe 'grep -qx "global: SUPER + grave|next" <<<"$k" && grep -qx "submap: SUPER + Super_L|commit|true" <<<"$k"' "eigenes Kürzel: Loslassen des eigenen Modifikators wechselt"
    k="$(kuerzel '{"switcher": {"enabled": false}}')"
    pruefe '[ -z "$k" ]' "aus: kein Kürzel, keine Submap"
fi

echo "== 2. shell-switcher"
ln -s "$REPO/tests/daten/hyprctl" "$T/bin/hyprctl"
printf '#!/bin/sh\nexit 1\n' > "$T/bin/qs"; chmod +x "$T/bin/qs"
mkdir -p "$HOME/.config/quickshell/hypr-shell"; touch "$HOME/.config/quickshell/hypr-shell/shell.qml"
export PATH="$T/bin:$PATH" HYPRLAND_INSTANCE_SIGNATURE=test
HYPRCTL_LOG="$T/log" "$REPO/bin/shell-switcher" next
pruefe '[ "$(sed -n 1p "$T/log")" = "dispatch hl.dsp.submap(\"hypr-shell-switcher\")" ] && [ "$(sed -n 2p "$T/log")" = "dispatch hl.dsp.submap(\"reset\")" ]' "Submap betreten; Oberfläche antwortet nicht → sofort wieder hinaus"
: > "$T/log"; HYPRCTL_LOG="$T/log" "$REPO/bin/shell-switcher" cancel
pruefe 'grep -q "submap(\"reset\")" "$T/log"' "Abbrechen verlässt die Submap immer"
pruefe '! "$REPO/bin/shell-switcher" xyz 2>/dev/null' "unbekannter Befehl: Meldung"
exit "$fehler"
