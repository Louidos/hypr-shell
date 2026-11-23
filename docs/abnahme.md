# Abnahme

Checkliste aller „Fertig, wenn“-Punkte. **Automatisch** = in der CI geprüft
(`tests/*.sh`, Arch-Container, unsichtbarer Wayland-Compositor). **Von Hand** = nur auf
dem echten Rechner in einer Hyprland-Sitzung prüfbar.

## Gruppe 1: Grundgerüst und Installer

| Punkt | Prüfung |
| --- | --- |
| Frischer Klon + `./install.sh` läuft ohne Fehler durch | automatisch (Dateien, `tests/probeinstallation.sh`); Paketinstallation und Systemupdate von Hand |
| Hyprland unter 0.55: Abbruch vor jeder Änderung | automatisch (vorgetäuschte Version 0.54) |
| `--update` lässt settings.json, user.lua, hypr-shell-local.lua in Ruhe | automatisch |
| `--dry-run` ändert nichts | automatisch |
| `--restore` stellt die vorherigen Dateien wieder her | automatisch |
| Nach Neuanmeldung: `hyprctl configerrors` leer | automatisch mit echtem Hyprland (`Hyprland --verify-config`, `tests/hyprland-echt.sh`); laufende Sitzung von Hand |
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

## Bilder und Symbole

| Punkt | Prüfung |
| --- | --- |
| Profilbild, erste Wallpaper-Karte, erstes App-Symbol sichtbar | automatisch (`tests/oberflaeche.sh`: Ausschnitt nicht einfarbig) |
| Ohne `~/.face` Anfangsbuchstabe (Dashboard, Panel, Sperrbildschirm) | automatisch (Panel, Ersatzbild für hyprlock); Sperrbildschirm mit runden Ecken von Hand |
| Runde Ecken der Bilder mit Grafikkarte | von Hand (die CI hat keine Shader) |

## Laptop

| Punkt | Prüfung |
| --- | --- |
| Akkustand in der Leiste stimmt mit `upower -i $(upower -e \| grep BAT)` | von Hand |
| `monitors.scale`, `input.touchpad.natural_scroll`, `input.touchpad.tap_to_click` wirken sofort | Werte an Hyprland automatisch (`tests/hyprland-lua.sh`); Wirkung von Hand |
| XWayland-Fenster (Steam) bei Skalierung über 1 scharf | von Hand |
| GPU-Kachel zeigt „–“, solange die NVIDIA-Karte schläft, und weckt sie nicht | automatisch mit nachgebauter Karte (`tests/dashboard.sh`); echte Karte von Hand: `cat /sys/bus/pci/devices/*/power/runtime_status` |
| Zahnrad im Panel öffnet settings.json im Terminal | von Hand |

## Einstellungen in settings.json (Schema, shell-apply)

| Punkt | Prüfung |
| --- | --- |
| Abstand, Leisten-Höhe oder Sperrzeit in settings.json ändern wirkt innerhalb von zwei Sekunden ohne Abmelden | Erzeugte Dateien automatisch (`tests/einstellungen.sh`); Wirkung (Quickshell → `shell-apply` → `hyprctl reload`, Waybar, hypridle) von Hand |
| Tippfehler in settings.json: Benachrichtigung, Desktop läuft weiter | Standardwert bzw. letzter gültiger Stand automatisch; Benachrichtigung von Hand |
| settings.json von v1.0.0 funktioniert unverändert | automatisch |
| Kein einstellbarer Wert steht mehr fest in config/ oder Theme.qml | automatisch: Standardwerte ergeben genau die Dateien in `config/`, jeder Schlüssel wird gelesen |
| Farbmodus `grey` / `custom` färbt alles um | von Hand (matugen im Test-Compositor nur mit `auto`) |
| Symbolthema (`theme.icons`) wechselt nach dem automatischen Neustart der Oberfläche | von Hand |

## Befehl shell-set

| Punkt | Prüfung |
| --- | --- |
| `shell-set look.rounding 20` ändert die Fenster-Rundung sofort, `shell-set undo` nimmt es zurück | Datei und erzeugte Hyprland-Werte automatisch (`tests/shell-set.sh`); sichtbare Wirkung von Hand |
| `shell-set look.rounding abc` meldet den erlaubten Bereich und ändert nichts | automatisch |
| Ein gespeichertes Profil stellt nach `load` alle Werte wieder her | automatisch |
| Tab-Vervollständigung in bash und fish | bash automatisch; fish automatisch, wenn fish installiert ist, sonst von Hand |

## Einstellungs-App

| Punkt | Prüfung |
| --- | --- |
| SUPER+U öffnet die App, jede Seite zeigt alle Werte ihres Bereichs aus dem Schema | Kürzel automatisch (`tests/hyprland-lua.sh`); jede Seite per IPC geöffnet, Screenshot `docs/screenshots/settings-<seite>.png` und Log ohne QML-Fehler (`tests/oberflaeche.sh`); die Zeilen entstehen aus dem Schema |
| Ein Regler ändert den Desktop sichtbar, während man ihn zieht | automatisch: Ziehen mit dem sway-Zeiger, `hypr-shell-settings.lua` ändert sich schon vor dem Loslassen; sichtbare Wirkung in Hyprland von Hand |
| Reset, Reset page und Undo stellen die vorherigen Werte her | Undo und Reset page automatisch (Klick); Reset je Zeile von Hand |
| Die Suche findet „blur“, „clock“ und „battery“ | automatisch |
| Monitors: neue Auflösung ohne Bestätigung nach 15 s zurück | von Hand (braucht echte Bildschirme und Hyprland) |
| Blur hinter dem Fenster | von Hand (die CI hat keinen Blur) |

## Tastenkürzel einstellen

| Punkt | Prüfung |
| --- | --- |
| Ein geändertes Kürzel wirkt sofort, das alte ist frei | erzeugte Belegung automatisch (`tests/tastenkuerzel.sh`); Wirkung nach dem automatischen `hyprctl reload` von Hand |
| Eine doppelte Belegung wird abgelehnt und benannt | automatisch (`shell-set`, beide Richtungen); in der App wird die Aktion genannt und nicht gespeichert – Aufnehmen per Tastendruck von Hand |
| Ohne Einträge in `keybinds` gelten alle bisherigen Kürzel | automatisch (genau die bisherigen Kürzel) |
| SUPER+U lässt sich nicht leeren | automatisch |
