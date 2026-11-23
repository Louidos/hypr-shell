# Abnahme

Checkliste aller „Fertig, wenn“-Punkte. **Automatisch** = in der CI geprüft
(`tests/*.sh`, Arch-Container, unsichtbarer Wayland-Compositor). **Von Hand** = nur auf
dem echten Rechner in einer Hyprland-Sitzung prüfbar.

## Gruppe 1: Grundgerüst und Installer

| Punkt | Prüfung |
| --- | --- |
| Frischer Klon + `./install.sh` läuft ohne Fehler durch | automatisch (Dateien, `tests/probeinstallation.sh`); Paketinstallation von Hand |
| `--dry-run` ändert nichts | automatisch |
| `--restore` stellt die vorherigen Dateien wieder her | automatisch |
| Nach Neuanmeldung: `hyprctl configerrors` leer | Lua-Aufrufe automatisch gegen die dokumentierte API geprüft; echte Sitzung von Hand |
| Hintergrundbild da, Farben passen zum Bild | automatisch (awww + matugen im Test-Compositor) |
| Alle Kürzel funktionieren | Belegung automatisch; Wirkung von Hand |
| Steam und Spiele starten wie vorher | von Hand (alte Umgebungsvariablen werden übernommen, keine Fensterregeln für Spiele) |

## Gruppe 2: Leiste

| Punkt | Prüfung |
| --- | --- |
| Leiste erscheint nach Login und nach `hyprctl reload` | Start automatisch (Test-Compositor); Login von Hand |
| Klick auf Arbeitsfläche wechselt, Uhr und Lautstärke stimmen | von Hand |
| Farben ändern sich mit dem Hintergrundbild | automatisch |

## Gruppe 3: Desktop-Widgets

| Punkt | Prüfung |
| --- | --- |
| Uhr und Ringe sichtbar, hinter Fenstern | sichtbar: automatisch (Screenshot); Ebene `bottom` |
| Werte ändern sich, kaum CPU im Leerlauf | Abfrage alle 2 s ohne Prozess-Start; von Hand mit `top` |
| Andere Auflösung | Positionen und Grössen relativ; von Hand |

## Gruppe 4: Dashboard

| Punkt | Prüfung |
| --- | --- |
| Kürzel und Kante öffnen, Esc schliesst | Öffnen per IPC automatisch; Kante und Esc von Hand |
| Alle vier Tabs zeigen echte Werte | automatisch (Screenshots, Wetter mit Netz) |
| Klick auf ein Bild ändert Hintergrund und Farben überall | `shell-wallpaper` automatisch; Klick von Hand |
| Systemwerte nur bei offenem Panel | automatisch (Tabs per Loader) |

## Gruppe 5: Hot-Corner-Panel

| Punkt | Prüfung |
| --- | --- |
| Ecke und SUPER+A öffnen, Verlassen schliesst | Öffnen per IPC automatisch; Ecke von Hand |
| Jeder Schalter zeigt den echten Zustand und ändert ihn | Gaming-Modus automatisch; WLAN, Bluetooth, DND, Keep Awake von Hand |
| Screenshots landen im Bilderordner und in der Zwischenablage | von Hand |
| Geänderte App-Liste erscheint ohne Neustart | `watchChanges` automatisch geprüft; von Hand |

## Gruppe 6: Lockscreen

| Punkt | Prüfung |
| --- | --- |
| SUPER+L sperrt, Passwort entsperrt | **von Hand** |
| Konfiguration ohne Fehlermeldung | automatisch (hyprlock im Test-Compositor) |
| Mit Keep Awake wird nicht gesperrt | **von Hand** (nach 5 Minuten warten) |
