#!/usr/bin/env bash
# Prüft, dass die README jedes Tastenkürzel aus hyprland.lua und jede Einstellung aus
# settings.example.json nennt und die Installation in drei Zeilen beschreibt.
# shellcheck disable=SC2016
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }

echo "== Installation"
pruefe 'grep -qF "gh repo clone Louidos/hypr-shell && cd hypr-shell && ./install.sh" README.md' "Installation in einer Zeile"
pruefe 'grep -q "Hyprland“ wählen" README.md' "Hinweis: abmelden und Hyprland wählen"
for o in --yes --dry-run --no-packages --update --restore --uninstall; do
    pruefe 'grep -q -- "$o" README.md' "Option $o beschrieben"
done

echo "== Tastenkürzel"
lua=$(command -v lua5.4 || command -v lua || true)
if [ -n "$lua" ]; then
    while IFS= read -r k; do
        case "$k" in "SUPER + "[0-9]|"SUPER + SHIFT + "[0-9]) k="${k%[0-9]}1" ;; esac
        pruefe 'grep -qF "$k" README.md' "README nennt $k"
    done < <(HOME=/tmp "$lua" - <<'LUA' | sort -u
package.path = "./config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")
for k in pairs(A.binds) do print(k) end
LUA
    )
else
    echo "  Hinweis: lua fehlt, Kürzel übersprungen."
fi

echo "== Einstellungen"
if command -v jq >/dev/null; then
    while IFS= read -r p; do
        pruefe 'grep -qF "\`$p\`" README.md' "README nennt $p"
    done < <(jq -r 'paths(scalars) | map(select(type == "string")) | join(".")' settings/settings.example.json | sort -u)
fi

echo "== Screenshots"
while IFS= read -r b; do
    pruefe '[ -f "$b" ]' "Bild vorhanden: $b"
done < <(grep -oE 'docs/screenshots/[a-z-]+\.png' README.md | sort -u)

exit "$fehler"
