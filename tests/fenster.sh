#!/usr/bin/env bash
# Prüft Titelleiste, Fenster-Knöpfe und Minimieren ohne Bildschirm:
#   1. hyprland.lua mit geladenem hyprbars (Attrappe): Glas-Titelleiste, drei Knöpfe (Schliessen,
#      Maximieren, Minimieren) im Windows-Stil rechts bzw. macOS-Stil links, Doppelklick maximiert,
#      keine Titelleiste für Ausnahmen, Vollbild, Dialoge, Spiele/Videos; nur-schwebend; aus = nichts
#   2. ohne hyprbars: keine Plugin-Werte, keine Fehler
#   3. shell-window minimize/restore mit hyprctl-Attrappe: Versteck special:minimiert, Fokus aufs
#      nächste Fenster, Zurückholen auf die aktuelle Arbeitsfläche an die alte Stelle
#   4. Kürzel SUPER + M / SUPER + SHIFT + M, Abmelden auf CTRL + SUPER + M
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
leiste() { # settings-json hyprbars(0/1) -> Zeilen: "config …", "button …", "rule …"
    printf '%s\n' "$1" > "$HOME/.config/hypr-shell/settings.json"
    "$REPO/bin/shell-apply" --no-reload --no-migrate >/dev/null 2>&1
    HL_ATTRAPPE_HYPRBARS="$2" "$lua" - <<'LUA'
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
for _, a in ipairs(A.aufrufe) do
    if a[1] == "config" and a[2].plugin then
        local h = a[2].plugin.hyprbars
        print("config " .. h.bar_buttons_alignment .. " " .. h.bar_color .. " blur=" .. tostring(h.bar_blur) .. " dbl=" .. h.on_double_click)
    elseif a[1] == "hyprbars_button" then
        print("button " .. a[2].bg_color .. " " .. a[2].icon .. " " .. a[2].action)
    elseif a[1] == "window_rule" and a[2]["hyprbars:no_bar"] then
        local m = {}
        for k, v in pairs(a[2].match) do m[#m + 1] = k .. "=" .. tostring(v) end
        table.sort(m)
        print("rule " .. a[2].name .. " " .. table.concat(m, ","))
    end
end
LUA
}
if [ -n "$lua" ]; then
    echo "== 1. Titelleiste mit hyprbars"
    w="$(leiste '{}' 1)"
    pruefe 'grep -q "^config right rgba(1a1a1d8c) blur=true dbl=.*maximized" <<<"$w"' "Glas-Titelleiste, Knöpfe rechts, Doppelklick maximiert"
    pruefe '[ "$(grep -c "^button" <<<"$w")" = 3 ] && grep -q "window.close()" <<<"$w" && grep -q "maximized" <<<"$w" && grep -q "shell-window minimize" <<<"$w"' "drei Knöpfe: Schliessen, Maximieren, Minimieren"
    pruefe 'grep -q "^button rgba(e8112366)" <<<"$w"' "Windows-Stil: Schliessen rot getönt"
    pruefe 'grep -q "^rule hypr-shell-bar-ausnahmen class=^(org.gnome.\*|firefox" <<<"$w" && grep -q "rule hypr-shell-bar-vollbild fullscreen=true" <<<"$w" && grep -q "rule hypr-shell-bar-dialog modal=true" <<<"$w" && grep -q "content=game" <<<"$w" && grep -q "content=video" <<<"$w"' "keine Titelleiste: Ausnahmen, Vollbild, Dialoge, Spiele, Videos"
    pruefe '! grep -q "bar-gekachelt" <<<"$w"' "an: auch gekachelte Fenster haben die Titelleiste"
    w="$(leiste '{"fenster": {"knoepfe": {"stil": "mac"}}}' 1)"
    pruefe 'grep -q "^config left" <<<"$w" && grep -q "^button rgb(ff5f57)" <<<"$w" && grep -q "^button rgb(febc2e)" <<<"$w" && grep -q "^button rgb(28c840)" <<<"$w"' "macOS-Stil: rote, gelbe, grüne Punkte links"
    w="$(leiste '{"fenster": {"knoepfe": {"stil": "mac", "seite": "rechts"}}}' 1)"
    pruefe 'grep -q "^config right" <<<"$w"' "Seite lässt sich festlegen"
    w="$(leiste '{"fenster": {"titelleiste": "nur-schwebend"}}' 1)"
    pruefe 'grep -q "rule hypr-shell-bar-gekachelt float=false" <<<"$w"' "nur-schwebend: gekachelte Fenster ohne Titelleiste"
    w="$(leiste '{"fenster": {"titelleiste": "aus"}}' 1)"
    pruefe '[ -z "$w" ]' "aus: keine Titelleiste, keine Knöpfe"
    echo "== 2. ohne hyprbars"
    w="$(leiste '{}' 0)"
    pruefe '[ -z "$w" ]' "Plugin fehlt: keine Plugin-Werte, Hyprland läuft ohne Knöpfe weiter"
fi

echo "== 3. Minimieren und Zurückholen"
ln -s "$REPO/tests/daten/hyprctl" "$T/bin/hyprctl"
export PATH="$T/bin:$PATH" HYPRLAND_INSTANCE_SIGNATURE=test XDG_RUNTIME_DIR="$T/run"
mkdir -p "$XDG_RUNTIME_DIR"
HYPRCTL_LOG="$T/log1" "$REPO/bin/shell-window" minimize
pruefe 'grep -q "window = \"address:0x55d3c0a1b2c0\", workspace = \"special:minimiert\", follow = false" "$T/log1"' "aktives Fenster wandert ins Versteck special:minimiert"
pruefe 'grep -q "hl.dsp.focus({ window = \"address:0x55d3c0a1b3d0\" })" "$T/log1"' "Fokus geht an das nächste Fenster der Arbeitsfläche"
pruefe '[ "$(jq -r ".[0].address" "$XDG_RUNTIME_DIR/hypr-shell/minimiert.json")" = 0x55d3c0a1b2c0 ]' "alte Stelle gemerkt"
# jetzt liegt kitty minimiert (Attrappe mit geänderter Liste), schwebend an 300,200 mit 800x500
jq '(.[] | select(.class == "kitty")) |= (.workspace = {"id": -98, "name": "special:minimiert"})' tests/daten/hyprctl-clients.json > "$T/clients.json"
jq '.[0].floating = true | .[0].at = [300, 200] | .[0].size = [800, 500]' "$XDG_RUNTIME_DIR/hypr-shell/minimiert.json" > "$T/m" && mv "$T/m" "$XDG_RUNTIME_DIR/hypr-shell/minimiert.json"
pruefe '[ "$(HYPRCTL_CLIENTS="$T/clients.json" "$REPO/bin/shell-window" list | jq -r ".[0].class")" = kitty ]' "Liste der minimierten Fenster"
HYPRCTL_CLIENTS="$T/clients.json" HYPRCTL_LOG="$T/log2" "$REPO/bin/shell-window" restore
pruefe 'grep -q "window = \"address:0x55d3c0a1b2c0\", workspace = \"1\", follow = true" "$T/log2" && grep -q "x = 300, y = 200" "$T/log2" && grep -q "x = 800, y = 500" "$T/log2" && grep -q "hl.dsp.focus({ window = \"address:0x55d3c0a1b2c0\" })" "$T/log2"' "zurück auf die aktuelle Arbeitsfläche, an die alte Stelle und Grösse, mit Fokus"
pruefe '[ "$(jq length "$XDG_RUNTIME_DIR/hypr-shell/minimiert.json")" = 0 ]' "danach nicht mehr gemerkt"
pruefe '[ "$(HYPRCTL_LOG="$T/log3" "$REPO/bin/shell-window" restore)" = "shell-window: nichts minimiert" ]' "nichts minimiert: Hinweis, nichts passiert"
pruefe '(unset HYPRLAND_INSTANCE_SIGNATURE; ! "$REPO/bin/shell-window" minimize 2>/dev/null)' "ohne Hyprland: Meldung"

echo "== 4. Kürzel"
pruefe '[ "$(jq -r ".keys[] | select(.key == \"keybinds.minimize\") | .default" settings/schema.json)" = "SUPER + M" ] && [ "$(jq -r ".keys[] | select(.key == \"keybinds.restore\") | .default" settings/schema.json)" = "SUPER + SHIFT + M" ] && [ "$(jq -r ".keys[] | select(.key == \"keybinds.exit\") | .default" settings/schema.json)" = "CTRL + SUPER + M" ]' "SUPER + M minimiert, SUPER + SHIFT + M holt zurück, Abmelden auf CTRL + SUPER + M"
exit "$fehler"
