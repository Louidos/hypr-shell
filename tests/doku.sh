#!/usr/bin/env bash
# Prüft, dass die README jedes Tastenkürzel aus hyprland.lua nennt, die Installation in drei Zeilen
# beschreibt und die drei Wege zum Anpassen erklärt, und dass docs/einstellungen.md genau zum Schema
# passt (sonst neu erzeugen: tests/doku-erzeugen.sh --write).
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

echo "== Einstellungen (docs/einstellungen.md aus dem Schema)"
pruefe 'tests/doku-erzeugen.sh >/dev/null' "docs/einstellungen.md passt zum Schema (sonst: tests/doku-erzeugen.sh --write)"
if command -v jq >/dev/null; then
    fehlend=""
    while IFS= read -r k; do grep -qF "| \`$k\` |" docs/einstellungen.md || fehlend="$fehlend $k"; done < <(jq -r '.keys[].key' settings/schema.json)
    pruefe '[ -z "$fehlend" ]' "jeder Schlüssel aus dem Schema steht in docs/einstellungen.md ($fehlend)"
    # ein neuer Schlüssel ohne neu erzeugte Doku muss auffallen
    tmp="$(mktemp)"
    jq '.keys += [{key: "test.neu", type: "bool", default: true, title: "Neu", description: "Neu", page: "about", section: "Test", icon: ""}]' settings/schema.json > "$tmp"
    pruefe '! DOKU_SCHEMA="$tmp" tests/doku-erzeugen.sh >/dev/null 2>&1' "neuer Schlüssel ohne neu erzeugte Doku wird erkannt"
    rm -f "$tmp"
fi
pruefe 'grep -q "docs/einstellungen.md" README.md && grep -q "SUPER + U" README.md && grep -q "shell-set" README.md && grep -q "settings.json" README.md' "README nennt die drei Wege und verlinkt die Übersicht"

echo "== Screenshots"
while IFS= read -r b; do
    pruefe '[ -f "$b" ]' "Bild vorhanden: $b"
done < <(grep -oE 'docs/screenshots/[a-z-]+\.png' README.md | sort -u)

exit "$fehler"
