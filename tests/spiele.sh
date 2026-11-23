#!/usr/bin/env bash
# Prüft shell-games mit einem Beispiel-Steam-Ordner (zwei Bibliotheken, localconfig.vdf, Covers in
# beiden Ablagen von Steam) und eigenen Einträgen; dazu den automatischen Gaming-Modus über die
# Vollbild-Ereignisse aus hyprland.lua.
# shellcheck disable=SC2016,SC2034,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
unset HYPRLAND_INSTANCE_SIGNATURE
S="$HOME/.local/share/Steam"
mkdir -p "$S/steamapps" "$T/lib2/steamapps" "$S/userdata/123/config" "$S/appcache/librarycache/570" "$S/appcache/librarycache/1091500/abc" "$HOME/.local/share/hypr-shell" "$T/bin"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
manifest() { printf '"AppState"\n{\n\t"appid"\t\t"%s"\n\t"name"\t\t"%s"\n\t"LastPlayed"\t\t"%s"\n}\n' "$2" "$3" "$4" > "$1/steamapps/appmanifest_$2.acf"; }
printf '"libraryfolders"\n{\n\t"0"\n\t{\n\t\t"path"\t\t"%s"\n\t}\n\t"1"\n\t{\n\t\t"path"\t\t"%s"\n\t}\n}\n' "$S" "$T/lib2" > "$S/steamapps/libraryfolders.vdf"
manifest "$S" 570 "Dota 2" 1700000000
manifest "$T/lib2" 1091500 "Cyberpunk 2077" 1700005000
manifest "$S" 1493710 "Proton Experimental" 1700009000
manifest "$S" 400 "Portal" 0
# localconfig: Portal wurde zuletzt gespielt (neuer als das Manifest)
printf '"UserLocalConfigStore"\n{\n\t"Software"\n\t{\n\t\t"Valve"\n\t\t{\n\t\t\t"Steam"\n\t\t\t{\n\t\t\t\t"apps"\n\t\t\t\t{\n\t\t\t\t\t"400"\n\t\t\t\t\t{\n\t\t\t\t\t\t"LastPlayed"\t\t"1700009999"\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n}\n' > "$S/userdata/123/config/localconfig.vdf"
touch "$S/appcache/librarycache/570_library_600x900.jpg" "$S/appcache/librarycache/1091500/abc/library_600x900.jpg"
printf '#!/bin/sh\necho "$*" >> "%s/steam.log"\n' "$T" > "$T/bin/steam"; chmod +x "$T/bin/steam"
g() { PATH="$T/bin:$PATH" "$REPO/bin/shell-games" "$@"; }

echo "== Steam"
l="$(g list)"
pruefe '[ "$(jq -r "map(.name) | join(\",\")" <<<"$l")" = "Portal,Cyberpunk 2077,Dota 2" ]' "zuletzt gespielte zuerst, beide Bibliotheken, Proton ist kein Spiel"
pruefe '[ "$(jq -r ".[] | select(.id == \"570\") | .cover" <<<"$l")" = "$S/appcache/librarycache/570_library_600x900.jpg" ] && [ "$(jq -r ".[] | select(.id == \"1091500\") | .cover" <<<"$l")" = "$S/appcache/librarycache/1091500/abc/library_600x900.jpg" ]' "Cover aus beiden Ablagen von Steam"
g launch 570; sleep 0.3
pruefe 'grep -qx "steam://rungameid/570" "$T/steam.log"' "Klick startet das Spiel über Steam"
pruefe '! g launch "570; rm -rf /" 2>/dev/null' "ungültige ID wird abgelehnt"

echo "== eigene Einträge"
echo '{"games": {"custom_enabled": false, "custom": [{"name": "Diablo IV", "command": "echo battle > '"$T"'/custom.log", "image": ""}]}}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
pruefe '! g list | jq -e "map(.source) | index(\"custom\")" >/dev/null' "standardmässig aus: keine eigenen Einträge"
echo '{"games": {"custom_enabled": true, "custom": [{"name": "Diablo IV", "command": "echo battle > '"$T"'/custom.log", "image": ""}]}}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
pruefe '[ "$(g list | jq -r ".[-1].name")" = "Diablo IV" ]' "eingeschaltet: eigener Eintrag erscheint"
g launch custom:0; sleep 0.5
pruefe '[ "$(cat "$T/custom.log" 2>/dev/null)" = battle ]' "eigener Eintrag startet seinen Befehl"
pruefe '[ "$(HOME="$T/ohne" g list)" = "[]" ]' "ohne Steam und ohne eigene Einträge: leer (Tab ausgeblendet)"

echo "== automatischer Gaming-Modus"
echo '{}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
g auto fullscreen 2 steam_app_570 0xabc
pruefe '[ -e "$HOME/.local/share/hypr-shell/gaming" ] && [ "$(cat "$HOME/.local/share/hypr-shell/gaming-auto")" = 0xabc ]' "Spiel im Vollbild: Gaming-Modus an"
g auto fullscreen 0 steam_app_570 0xabc
pruefe '[ ! -e "$HOME/.local/share/hypr-shell/gaming" ]' "Vollbild verlassen: wieder aus"
g auto fullscreen 2 firefox 0xdef
pruefe '[ ! -e "$HOME/.local/share/hypr-shell/gaming" ]' "kein Spiel (Firefox im Vollbild): nichts passiert"
g auto fullscreen 2 gamescope 0x111; g auto close 0x111
pruefe '[ ! -e "$HOME/.local/share/hypr-shell/gaming" ]' "Spiel geschlossen: wieder aus"
"$REPO/bin/shell-toggle" gaming on >/dev/null; g auto fullscreen 2 steam_app_1 0x222; g auto fullscreen 0 steam_app_1 0x222
pruefe '[ -e "$HOME/.local/share/hypr-shell/gaming" ]' "von Hand eingeschalteter Gaming-Modus bleibt an"
"$REPO/bin/shell-toggle" gaming off >/dev/null
echo '{"games": {"auto_gaming": false}}' > "$HOME/.local/share/hypr-shell/settings.effective.json"
g auto fullscreen 2 steam_app_570 0xabc
pruefe '[ ! -e "$HOME/.local/share/hypr-shell/gaming" ]' "abgeschaltet (games.auto_gaming): nichts passiert"
pruefe 'grep -q "window.fullscreen" config/hypr/hyprland.lua && grep -q "shell-games auto" config/hypr/hyprland.lua' "hyprland.lua meldet Vollbild-Wechsel"
exit "$fehler"
