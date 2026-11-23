# Tastenkürzel

## Die wichtigsten Kürzel

| Kürzel | Wirkung |
| --- | --- |
| `SUPER + Enter` | Terminal öffnen |
| `CTRL + SUPER + Enter` | App-Suche (Starter) |
| `SUPER + Q` | aktives Fenster schliessen |

Die übrigen Kürzel bleiben nah am Hyprland-Standard: `SUPER + 1…0` wechselt die
Arbeitsfläche, `SUPER + SHIFT + 1…0` schickt das Fenster dorthin, `SUPER` + linke/rechte
Maustaste verschiebt bzw. vergrössert Fenster, `SUPER + V` schaltet schwebend/gekachelt,
`SUPER + F` Vollbild, `SUPER + C` schliesst wie bisher ebenfalls.

## Was sich geändert hat (Version 1.8.0)

| Funktion | vorher | jetzt |
| --- | --- | --- |
| Terminal | `SUPER + Q` | `SUPER + Enter` |
| Fenster schliessen | `SUPER + C` | `SUPER + Q` (`SUPER + C` bleibt als zweite Taste) |
| App-Suche | `SUPER + R`, `SUPER + Space`, `ALT + Space` | zusätzlich `CTRL + SUPER + Enter` |
| Vollbild | – | `SUPER + F` (neu, Hyprland-üblich) |

Wer ein Kürzel selbst geändert hat (`shell-set keybinds.…` oder Einstellungs-App → Keybinds),
behält es auch nach einem Update. Hat jemand früher `SUPER + Q` ausdrücklich für das Terminal
eingetragen, bleibt das so; Schliessen liegt dann nur auf `SUPER + C`.

Alle Kürzel zeigt `SUPER + F1` (Spickzettel) und die Tabelle in der [README](../README.md#tastenkürzel).
