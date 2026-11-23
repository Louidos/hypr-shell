# Tastenkürzel

## Die wichtigsten Kürzel

| Kürzel | Wirkung |
| --- | --- |
| `SUPER + Enter` | Terminal öffnen |
| `CTRL + SUPER + Enter` | App-Suche (Starter) |
| `SUPER + Q` | aktives Fenster schliessen |
| `CTRL + SUPER + Escape` | Notfall: Tastatur zurück (alle Panels zu, Dock-Tastatur-Modus aus, Fokus auf das Fenster unter der Maus) |

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

## Was sich geändert hat (Fenster-Knöpfe)

| Funktion | vorher | jetzt |
| --- | --- | --- |
| Fenster wechseln mit Vorschau | – | `ALT + Tab`, rückwärts `ALT + SHIFT + Tab` |
| Fenster minimieren | – | `SUPER + M` |
| Minimiertes Fenster zurückholen | – | `SUPER + SHIFT + M` |
| Abmelden | `SUPER + M` | `CTRL + SUPER + M` |

Wer ein Kürzel selbst geändert hat (`shell-set keybinds.…` oder Einstellungs-App → Keybinds),
behält es auch nach einem Update. Hat jemand früher `SUPER + Q` ausdrücklich für das Terminal
eingetragen, bleibt das so; Schliessen liegt dann nur auf `SUPER + C`.

Alle Kürzel zeigt `SUPER + F1` (Spickzettel) und die Tabelle in der [README](../README.md#tastenkürzel).

## Tastatur geht nicht

Bekommt ein Programm keine Tasten mehr (die Kürzel von Hyprland gehen aber noch), hält meist eine
Fläche der Shell die Tastatur:

1. `CTRL + SUPER + Escape` drücken – schliesst alle Panels der Shell, beendet den Tastatur-Modus
   des Docks (`SUPER + B`) und jede Submap von Hyprland und gibt den Fokus dem Fenster unter der Maus.
   Dasselbe auf der Befehlszeile: `shell-diag freigeben`.
2. Geht es danach noch nicht: `shell-diag tastatur` zeigt, welche Fläche der Shell die Tastatur will,
   welches Panel offen ist, in welcher Submap Hyprland steckt und welches Fenster aktiv ist.
3. Hilft beides nicht, liegt es nicht an der Shell (z. B. Eingabegerät): `hyprctl devices`.

Der Tastatur-Modus des Docks endet von selbst bei jeder anderen Taste, einem Klick daneben, wenn ein
Panel aufgeht, das Dock verschwindet oder nach `dock.keyboard_timeout_s` Sekunden ohne Taste
(Standard 10, 0 = nie). Solange er läuft, steht am Dock ein Hinweis mit den Tasten.
