#!/usr/bin/env bash
# Erzeugt docs/einstellungen.md aus settings/schema.json (eine Tabelle je Bereich mit Schlüssel,
# Standard, erlaubten Werten, Erklärung und einem shell-set-Beispiel).
#
#   tests/doku-erzeugen.sh           prüfen: Rückgabe 1, wenn docs/einstellungen.md veraltet ist
#   tests/doku-erzeugen.sh --write   docs/einstellungen.md neu schreiben
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }
ZIEL="${DOKU_ZIEL:-docs/einstellungen.md}"
SCHEMA="${DOKU_SCHEMA:-settings/schema.json}"

erzeuge() {
    cat <<'MD'
# Einstellungen

<!-- erzeugt von tests/doku-erzeugen.sh aus settings/schema.json – nicht von Hand ändern.
     Neu erzeugen: tests/doku-erzeugen.sh --write -->

Alle Werte stehen in `~/.config/hypr-shell/settings.json`. Es gibt drei Wege, sie zu ändern – alle
schreiben in dieselbe Datei und wirken sofort:

1. **Einstellungs-App**: `SUPER + U` (oder das Zahnrad im Panel).
2. **Befehl**: `shell-set <schlüssel> <wert>`, z. B. `shell-set look.rounding 20`; `shell-set undo`
   nimmt die letzte Änderung zurück, `shell-set list` zeigt alles.
3. **Datei**: `~/.config/hypr-shell/settings.json` mit einem Editor öffnen. Fehlende Werte haben ihren
   Standard; ein falscher Wert wird gemeldet und durch den Standard ersetzt.

Ein Schlüssel wie `look.gaps.inner` steht in der Datei verschachtelt:
`{ "look": { "gaps": { "inner": 10 } } }`. Die Erklärungen sind dieselben wie in der App (Englisch).

MD
    jq -r '
    def show: if type == "string" then (if . == "" then "\"\"" else . end) else tojson end;
    def code: "`" + (show | gsub("\\|"; "\\|")) + "`";
    def allowed:
      if .type == "bool" then "`true`, `false`"
      elif .type == "int" then "ganze Zahl \(.min) … \(.max)" + (if .unit then " \(.unit)" else "" end)
      elif .type == "number" then "Zahl \(.min) … \(.max), Schritt \(.step)" + (if .unit then " \(.unit)" else "" end)
      elif .type == "enum" then (.values | map("`\(.)`") | join(", "))
      elif .type == "list" then "Liste aus " + (.values | map("`\(.)`") | join(", "))
      elif .type == "stringlist" then "Liste von Texten"
      elif .type == "color" then "Farbe `#rrggbb`"
      elif .type == "keybind" then "Tasten wie `SUPER + Q`" + (if .required then " (nicht leer)" else ", leer = keine Taste" end)
      elif .type == "objectlist" then "Liste von Einträgen mit " + (.fields | map("`\(.key)`") | join(", "))
      else "Text" + (if .pattern then " (Format geprüft)" else "" end) end;
    def example:
      if .type == "bool" then (.default | not | tostring)
      elif .type == "int" or .type == "number" then
        (if .default + .step <= .max then .default + .step else .default - .step end) as $v
        | ($v * 1000 | round / 1000 | tostring)
      elif .type == "enum" then .default as $d | ([.values[] | select(. != $d)] | first // $d)
      elif .type == "list" then (.values[0:2] | join(","))
      elif .type == "stringlist" then (.default + ["code"] | join(","))
      elif .type == "color" then "\"#a6e3a1\""
      elif .type == "keybind" then (if (.key | endswith("_mod")) then "\"ALT\"" else "\"SUPER + B\"" end)
      elif .type == "objectlist" then
        if .key == "monitors.outputs" then "'"'"'[{\"name\":\"eDP-1\",\"scale\":\"1.5\"}]'"'"'"
        elif .key == "keybinds.custom" then "'"'"'[{\"keys\":\"SUPER + B\",\"command\":\"firefox\"}]'"'"'"
        else "'"'"'[]'"'"'" end
      elif .key == "weather.location" then "\"Zürich\""
      elif .key == "desktop.screen" then "eDP-1"
      elif .key == "input.layout" then "de"
      elif .key == "input.variant" then "nodeadkeys"
      elif .key == "monitors.scale" then "1.5"
      elif (.key | startswith("theme.font.")) then "\"Noto Sans\""
      elif .key == "theme.cursor.name" then "Adwaita"
      elif .key == "theme.icons" then "Adwaita"
      elif .key == "apps.terminal" then "foot"
      elif .key == "apps.files" then "thunar"
      elif .key == "apps.browser" then "chromium"
      elif .key == "apps.launcher" then "\"fuzzel\""
      else (.default | tostring) end;
    def bereichname: {
        bar: "Leiste", look: "Fenster: Abstände, Rundung, Blur, Animationen", theme: "Farben, Glas, Schriften, Mauszeiger",
        input: "Eingabe", monitors: "Bildschirme", desktop: "Desktop: Uhr und Kacheln", dashboard: "Dashboard",
        weather: "Wetter", panel: "Hot-Corner-Panel", lock: "Sperren und Standby", apps: "Standard-Programme",
        keybinds: "Tastenkürzel"
      }[.] // .;
    .keys as $keys
    | ([$keys[].key | split(".")[0]] | reduce .[] as $b ([]; if index([$b]) then . else . + [$b] end)) as $bereiche
    | ($bereiche[] as $b
        | "## \($b) – \($b | bereichname)\n",
          "| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |",
          "| --- | --- | --- | --- | --- |",
          ($keys[] | select(.key | split(".")[0] == $b)
            | "| `\(.key)` | \(.default | code) | \(allowed) | \(.description | gsub("\\|"; "\\|")) | `shell-set \(.key) \(example)` |"),
          "")
    ' "$SCHEMA"
}

if [ "${1:-}" = --write ]; then
    erzeuge > "$ZIEL"
    echo "geschrieben: $ZIEL"
    exit 0
fi
if [ -f "$ZIEL" ] && [ "$(erzeuge | sha256sum)" = "$(sha256sum < "$ZIEL")" ]; then
    echo "  ok: $ZIEL passt zum Schema"
    exit 0
fi
echo "  FEHLER: $ZIEL passt nicht zum Schema – neu erzeugen mit: tests/doku-erzeugen.sh --write"
[ -f "$ZIEL" ] && diff <(erzeuge) "$ZIEL" | head -n 20
exit 1
