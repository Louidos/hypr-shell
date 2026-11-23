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

## Widgets verschieben

| Punkt | Prüfung |
| --- | --- |
| Eine verschobene Uhr steht nach Done und nach Neuanmeldung am neuen Platz | automatisch: Done speichert, nach Neustart der Oberfläche steht die Uhr dort (`tests/oberflaeche.sh`); Ziehen mit der echten Maus von Hand |
| Cancel und Esc lassen alles wie vorher | Cancel automatisch, Esc (gleiche Funktion) über `ipc desktop cancel`; die Taste selbst von Hand |
| Ausserhalb des Modus nehmen die Widgets keine Klicks an | leere Eingabefläche (`mask`) automatisch; von Hand |
| Mausrad skaliert, Hilfslinien rasten ein | von Hand |

## Doku der Einstellungen

| Punkt | Prüfung |
| --- | --- |
| Jeder Schlüssel aus dem Schema steht in docs/einstellungen.md | automatisch (`tests/doku.sh`) |
| Ein neuer Schlüssel ohne neu erzeugte Doku macht die CI rot | automatisch (`tests/doku.sh` prüft das mit einem zusätzlichen Test-Schlüssel) |
| Das README erklärt die drei Wege in wenigen Zeilen | automatisch (Stichworte und Link); Lesbarkeit von Hand |
| About: „Open settings.json“ und „Open docs“ | von Hand (öffnen Terminal bzw. Browser) |

## Neue Panels, Laptop, Missa, Anbindungen und Optik (Version 1.3.0 bis 1.6.0)

Zur Prüfung auf dem echten Rechner (ROG Zephyrus M16). Was die CI nicht kann: echtes
Hyprland mit Maus und Tastatur, Blur, asusctl/supergfxctl, Mikrofon und Lautsprecher,
echtes WLAN und Bluetooth, FUSE-Einhängen, echte Server (Missa-Core, Nextcloud, CalDAV,
Sensor) und der echte SDDM-Anmeldebildschirm.

### Gruppe 1: Gemeinsame Panel-Grundlage

| Punkt | Prüfung |
| --- | --- |
| Dashboard bei offenem Panel öffnen schliesst das Panel | automatisch (`tests/oberflaeche.sh`, IPC) |
| Dashboard und Panel sehen aus und reagieren wie vorher | Screenshots automatisch (CI-Branch `ci/screenshots`); Blur und Animationen von Hand |
| Alle bestehenden Tests grün | automatisch |

### Gruppe 2: Starter

| Punkt | Prüfung |
| --- | --- |
| SUPER+R und SUPER+Space öffnen den Starter, Tippen und Enter startet | Belegung und Suche automatisch; Start einer App von Hand |
| `=12*8` zeigt 96 | automatisch |
| Mit eigenem Befehl (`apps.launcher`) startet wieder rofi | automatisch (Belegung) |

### Gruppe 3: Benachrichtigungen

| Punkt | Prüfung |
| --- | --- |
| `notify-send Test` zeigt eine Karte und steht danach im Verlauf | automatisch (D-Bus im Test) |
| Mit Nicht stören keine Karte, Verlauf füllt sich | automatisch |
| Nach Neuanmeldung genau ein Benachrichtigungsdienst (kein swaync mehr) | von Hand (`busctl --user list \| grep Notifications`) |

### Gruppe 4: Lautstärke-Anzeige und Power-Menü

| Punkt | Prüfung |
| --- | --- |
| Lautstärketasten zeigen nur die neue Anzeige | Anzeige automatisch (`tests/osd.sh`); Tasten und „kein swayosd“ von Hand |
| SUPER+Escape öffnet das Menü, Shutdown braucht eine Bestätigung | automatisch (Probelauf ohne echtes Herunterfahren) |

### Gruppe 5: Zwischenablage

| Punkt | Prüfung |
| --- | --- |
| Drei Texte in richtiger Reihenfolge, Enter fügt ein | Reihenfolge automatisch (`tests/zwischenablage.sh`); Einfügen in ein Fenster von Hand |
| Bild mit Vorschau | automatisch |
| „Clear all“ leert den Verlauf | automatisch |

### Gruppe 6: Fenster-Übersicht

| Punkt | Prüfung |
| --- | --- |
| SUPER+Tab zeigt alle Fenster an der richtigen Arbeitsfläche | Daten automatisch (`tests/uebersicht.sh`); Vorschaubilder von Hand |
| Klick springt hin, Ziehen verschiebt | Befehle automatisch; Maus von Hand |

### Gruppe 7: Unterseiten und Schalter im Panel

| Punkt | Prüfung |
| --- | --- |
| Neues WLAN nur im Panel verbinden | Ablauf mit nmcli-Attrappe automatisch; echtes WLAN von Hand |
| Ausgabegerät wechseln wirkt sofort | von Hand |
| Ohne Bluetooth-Adapter fehlt der Schalter ohne Fehler | automatisch |

### Gruppe 8: Kürzel-Spickzettel

| Punkt | Prüfung |
| --- | --- |
| SUPER+F1 zeigt jedes Kürzel (ohne ausgeschaltete Anbindungen) | automatisch (Belegungen aus hyprland.lua mit Beschreibung) |
| Geändertes Kürzel steht nach `hyprctl reload` richtig drin | von Hand |

### Gruppe 9: ROG-Laptop

| Punkt | Prüfung |
| --- | --- |
| Profilwechsel im Panel stimmt mit `asusctl profile get` überein | Attrappe automatisch (`tests/laptop.sh`); echtes asusctl von Hand |
| Ladegrenze bleibt nach einem Neustart | von Hand (wird bei jeder Anmeldung von `shell-laptop apply` gesetzt) |
| Ohne asusctl erscheint nichts davon | automatisch |

### Gruppe 10: Spiele

| Punkt | Prüfung |
| --- | --- |
| Tab zeigt die letzten Spiele mit Cover, Klick startet | Liste automatisch (`tests/spiele.sh`); Start von Hand |
| Beim Spielstart Blur und Animationen aus, danach wieder an | Ereignisse automatisch; im echten Spiel von Hand |

### Gruppe 11: Ordner und Schalter für Anbindungen

| Punkt | Prüfung |
| --- | --- |
| Frische Installation: alle Anbindungen aus, kein Dienst, Ordner, Lesezeichen, Netzverkehr | automatisch (`tests/anbindungen.sh`) |
| `~/Nextcloud` im Dateimanager, Datei öffnen und anlegen, liegt auf dem Server | automatisch gegen lokalen WebDAV-Testserver, wenn FUSE geht (in der CI nicht); echte Nextcloud von Hand |
| Ausschalten hängt aus, entfernt Lesezeichen, stoppt Dienst, Zugangsdaten bleiben | automatisch |
| `~/Missa` mit Eingang und Ausgabe nur bei eingeschaltetem Missa | automatisch |
| Ohne rclone ein Hinweis statt Fehler | automatisch |
| Kein Passwort in `git grep` und settings.json | automatisch |

### Gruppe 12: Missa-Chat

| Punkt | Prüfung |
| --- | --- |
| Antwort läuft sichtbar ein und lässt sich abbrechen | automatisch gegen den lokalen Testserver (`tests/missa-chat.sh`, Oberflächentest) |
| Nach Neustart der Oberfläche dieselbe Sitzung | automatisch |
| Falscher Schlüssel: klare Meldung, Schlüssel in keinem Log | automatisch |
| Yes und No nur nach einer Rückfrage | automatisch |
| Missa aus: SUPER+I tut nichts, keine Netzanfrage | automatisch |
| Echter Missa-Core | von Hand (Adresse, Schlüssel und Gerätename eintragen) |

### Gruppe 13: Mit Missa sprechen

| Punkt | Prüfung |
| --- | --- |
| Gesprochener Satz steht im Chat und wird beantwortet | Ablauf mit Attrappen automatisch (`tests/sprache.sh`); echtes Mikrofon und whisper.cpp von Hand |
| Antwort wird vorgelesen, Esc stoppt | Attrappe automatisch; Ton von Hand |
| Ohne whisper.cpp und piper kein Fehler und kein Mikrofon-Knopf | automatisch |
| Schalter aus: nichts nimmt auf, Taste tut nichts | automatisch |
| Keine Audiodatei bleibt liegen | automatisch |

### Gruppe 14: Missa bedient den Rechner

| Punkt | Prüfung |
| --- | --- |
| „Öffne meine letzte PDF im Download-Ordner“ öffnet die Datei | automatisch (Aufträge vom Testserver, `tests/missa-agent.sh`) |
| `rechner_befehl` in `ask` erst nach Klick, in `read` gar nicht | automatisch |
| Lesen in `~/.ssh` in jeder Stufe abgelehnt | automatisch |
| Schalter im Panel trennt sofort, Symbol verschwindet | automatisch (Agent und Leistenzustand); Leiste von Hand |
| Jede Aktion im Verlauf | automatisch |
| Frische Installation: kein Agent, kein Symbol, kein Schalter | automatisch |
| Gegen den echten Missa-Core (Geräte-Anschluss v1) | von Hand |

### Gruppe 15: Homelab, Kalender, Sensor

| Punkt | Prüfung |
| --- | --- |
| Schalter aus: kein Tab, keine Termine, keine Kachel, keine Netzanfrage | automatisch (`tests/anbindungen-dashboard.sh`) |
| Eingeschaltet ohne Einträge: Tab „Lab“ zeigt eine Anleitung | automatisch |
| Server nicht erreichbar: Dashboard bleibt flüssig | automatisch (3 s Zeitlimit, Zwischenspeicher) |
| Kein Token in `git grep` und settings.json | automatisch |

### Gruppe 16: Apps mitfärben

| Punkt | Prüfung |
| --- | --- |
| Nach einem Bildwechsel hat der Dateimanager die neuen Farben | Dateien automatisch (`tests/apps-farben.sh`); Nautilus neu öffnen und ansehen von Hand |
| Abschalten bringt das ursprüngliche Aussehen zurück | automatisch (jede Datei Byte für Byte, auch Links) |
| Nicht installierte Programme tauchen nicht auf | automatisch (Einstellungen und `shell-appcolors caps`) |
| Firefox, Vesktop, Spotify im echten Programm | von Hand (Firefox und Spotify brauchen einen Neustart) |

### Gruppe 17: Login-Bildschirm

| Punkt | Prüfung |
| --- | --- |
| Normale Installation fasst den Anmeldemanager nicht an | automatisch (`tests/login-bildschirm.sh`) |
| `--login-theme-remove` stellt den vorherigen Zustand her | automatisch in einer Wurzel-Attrappe |
| Thema startet im Testmodus ohne Fehler | automatisch (`sddm-greeter-qt6 --test-mode` in der CI) |
| Anmelden mit dem neuen Bildschirm, Sitzung „Hyprland“ wählbar | von Hand |
