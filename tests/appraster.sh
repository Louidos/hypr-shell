#!/usr/bin/env bash
# App-Raster (Start-Menü/Launchpad) ohne Oberfläche: Einstellungen, SUPER antippen in hyprland.lua
# (Loslass-Kürzel, abschaltbar), Knopf in der Leiste und im Dock, Tastatur nur solange offen.
# Das Raster selbst (Suche, Kategorien, Favoriten, Menü, Start) prüft tests/oberflaeche.sh.
# shellcheck disable=SC2016,SC2034,SC2329
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export KEINE_MELDUNG=1 HYPR_SHELL_INPUT_DEVICES=/nonexistent
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
lua=$(command -v lua5.4 || command -v lua || true)
G=quickshell/apps/AppGrid.qml

# neues HOME mit settings.json ($1), shell-apply; gibt das HOME aus
home() {
    local h="$T/h$RANDOM$RANDOM"
    mkdir -p "$h/.config/hypr-shell"
    printf '%s\n' "$1" > "$h/.config/hypr-shell/settings.json"
    HOME="$h" "$REPO/bin/shell-apply" --no-reload >/dev/null 2>&1
    echo "$h"
}
# Kürzel aus hyprland.lua über die Attrappe: "Tasten<TAB>Befehl<TAB>release"
binds() {
    local h; h="$(home "$1")"
    HOME="$h" "$lua" - <<'LUA' | sort
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
for k, v in pairs(A.binds) do
    local f = A.flags[k] or {}
    print(k .. "\t" .. (type(v.arg) == "string" and v.arg or "") .. "\t" .. tostring(f.release == true))
end
LUA
}
waybar() { sed -E 's#^[[:space:]]*//.*$##' "$1/.config/waybar/config.jsonc" | jq -r "$2"; }

echo "== 1. Einstellungen"
S=settings/schema.json
d() { jq -c --arg k "$1" '.keys[] | select(.key == $k) | .default' "$S"; }
pruefe '[ "$(d appraster.enabled)" = true ] && [ "$(d appraster.super_tippen)" = true ] && [ "$(d appraster.dock_knopf)" = true ]' "an, SUPER antippen und Dock-Knopf sind Standard"
pruefe '[ "$(d appraster.kategorien)" = true ] && [ "$(d appraster.zuletzt)" = 8 ] && [ "$(d appraster.favoriten)" = "[]" ]' "Kategorien an, 8 zuletzt benutzte, keine Favoriten"
pruefe '[ "$(jq -r ".keys[] | select(.key | startswith(\"appraster.\")) | .page" "$S" | sort -u)" = system ]' "alle auf der Seite System (App grid)"
pruefe '[ "$(d dock.launcher_button)" = false ]' "dock.launcher_button bleibt wie er war"
pruefe 'jq -e ".keys[] | select(.key == \"bar.modules.left\") | .values | index(\"apps\")" "$S" >/dev/null' "Leisten-Modul apps wählbar"

if [ -n "$lua" ]; then
    echo "== 2. SUPER antippen (hyprland.lua)"
    std="$(binds '{}')"
    pruefe 'grep -qP "^SUPER \+ Super_L\t.*shell-quickshell ipc apps toggle\ttrue$" <<<"$std" && grep -qP "^SUPER \+ Super_R\t.*ipc apps toggle\ttrue$" <<<"$std"' "SUPER links und rechts: beim Loslassen (release) App-Raster"
    pruefe '! grep -P "^SUPER \+ Super_[LR]\t" <<<"$std" | grep -qv "apps toggle"' "SUPER allein macht nichts anderes"
    pruefe 'grep -qP "^SUPER \+ E\t.*nautilus\tfalse$" <<<"$std" && grep -qP "^SUPER \+ R\t.*launcher toggle\tfalse$" <<<"$std"' "SUPER + E und SUPER + R bleiben (beim Drücken, wie bisher)"
    aus="$(binds '{"appraster":{"super_tippen":false}}')"
    pruefe '! grep -q "Super_L" <<<"$aus" && [ "$(wc -l <<<"$aus")" -eq $(( $(wc -l <<<"$std") - 2 )) ]' "appraster.super_tippen = false: kein Kürzel auf SUPER allein, sonst alles gleich"
    weg="$(binds '{"appraster":{"enabled":false}}')"
    pruefe '! grep -q "Super_L" <<<"$weg"' "appraster.enabled = false: SUPER antippen tut nichts"
    pruefe 'grep -q "apps|" config/hypr/hyprland.lua' "Unschärfe hinter dem Raster (Layer hypr-shell-apps)"
else
    echo "  Hinweis: lua fehlt, hyprland.lua übersprungen"
fi

echo "== 3. Leiste und Dock"
h="$(home '{}')"
pruefe '[ "$(waybar "$h" ".\"custom/distro\".\"on-click\"")" = "\$HOME/.local/bin/shell-quickshell ipc apps toggle" ]' "Logo in der Leiste öffnet das App-Raster"
pruefe '[ "$(waybar "$h" ".\"custom/distro\".\"on-click-right\"")" = "\$HOME/.local/bin/shell-quickshell ipc launcher toggle" ]' "Rechtsklick aufs Logo: Starter (Suche)"
h="$(home '{"appraster":{"enabled":false},"apps":{"launcher":"fuzzel"}}')"
pruefe '[ "$(waybar "$h" ".\"custom/distro\".\"on-click\"")" = fuzzel ]' "Raster aus: Logo öffnet wie bisher den Starter"
h="$(home '{"bar":{"modules":{"left":["apps","workspaces"]}}}')"
pruefe '[ "$(waybar "$h" ".\"modules-left\" | join(\",\")")" = "custom/apps,hyprland/workspaces" ] && grep -q "#custom-apps" "$h/.config/waybar/style.css"' "Modul apps: eigener Knopf in der Leiste, gleich gestaltet"
pruefe 'grep -q "appraster.dock_knopf" quickshell/dock/Dock.qml && grep -q "gridOn ? \"apps\" : \"launcher\"" quickshell/dock/Dock.qml' "Dock: Startknopf (appraster.dock_knopf) öffnet das Raster"

echo "== 4. Raster (Quelltext)"
pruefe 'grep -q "AppGrid { }" quickshell/shell.qml' "in der Oberfläche eingebunden"
pruefe 'grep -q "keyboardFocus: WlrKeyboardFocus.Exclusive" "$G" && grep -q "name: \"apps\"" "$G"' "Overlay apps: Tastatur nur über Overlay (gibt sie beim Schliessen frei)"
# Reihenfolge in launch(): erst schliessen (Tastatur frei), dann starten
l="$(awk '/function launch\(e\)/,/^    }/' "$G")"
pruefe '[ "$(grep -n "ov.hide()" <<<"$l" | head -1 | cut -d: -f1)" -lt "$(grep -n "e.execute()" <<<"$l" | cut -d: -f1)" ]' "Start: zuerst zu (Tastatur frei), dann die App"
pruefe 'grep -q "launcher-recent.json" "$G" && grep -q "watchChanges: true" quickshell/launcher/Launcher.qml' "zuletzt benutzt gemeinsam mit dem Starter"
pruefe 'grep -q "Ui.set(\"appraster.favoriten\"" "$G" && grep -q "Ui.set(\"dock.items\"" "$G"' "Favoriten und Anheften über die Einstellungen (shell-set, bleibt erhalten)"
pruefe '! grep -qE "Timer|Process" "$G"' "keine Abfrage im Hintergrund"

if [ "$fehler" -eq 0 ]; then echo "App-Raster: alles ok"; else echo "App-Raster: FEHLER"; exit 1; fi
