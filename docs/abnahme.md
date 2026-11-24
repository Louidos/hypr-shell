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
| Ladegrenze auf 80, dann wieder auf 100 stellen: `cat /sys/class/power_supply/BAT*/charge_control_end_threshold` zeigt 100 | Schreiben über asusctl automatisch mit Attrappe (`tests/laptop.sh`), auch nach Reset und mit der alten Schreibweise; echter Akku von Hand |

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

## Dock (Version 1.7.0)

| Punkt | Prüfung |
| --- | --- |
| Dock mittig unten, 10 px vom Rand, abgerundet, Glas | Lage und Masse automatisch (`tests/oberflaeche.sh`); Blur von Hand |
| Angeheftete Programme starten, laufende zeigen einen Punkt, Klick holt nach vorn | Punkt automatisch (Testfenster); Starten und nach vorn holen von Hand |
| kitty, Firefox, Flatpak, Steam-Spiel bekommen das richtige Symbol | automatisch (`tests/fixtures/dock/`) |
| Klicks neben dem Dock erreichen das Fenster darunter | von Hand (Eingabefläche = Glas) |
| `dock.enabled` false: kein Dock-Fenster, Bildschirm wie vorher | automatisch |
| In Ruhe höchstens 1 % CPU | automatisch (Unterschied mit/ohne Dock über 10 s); auf dem Gerät mit `pidstat 30 1 -p $(pgrep -f hypr-shell)` |
| Rechtsklick-Menü mit Desktop-Aktionen | automatisch |
| Umsortiert bleibt nach `shell-quickshell restart` gleich | automatisch |
| Herausziehen löst an, Programm bleibt offen | automatisch (Lösen); Ziehen mit der Maus von Hand |
| Ordner, Trenner, Papierkorb nur, wenn eingetragen und vorhanden | automatisch |
| Ganz mit der Tastatur bedienbar (SUPER+B) | automatisch (Tasten über IPC); echte Tastatur von Hand |
| Ohne Benachrichtigungsdienst keine Zähler, kein Fehler | automatisch |
| Vergrösserung als Welle, andere springen nicht | Rechenweg automatisch; Aussehen von Hand |
| smart: weg bei überdeckendem Fenster, zurück über die Kante | Logik automatisch; mit echten Fenstern und Maus von Hand |
| `anim_ms` 0: keine Bewegung | automatisch |
| 20 Symbole ohne Ruckeln | Rechenzeit automatisch; flüssige Darstellung von Hand (GPU) |
| Jeder Wert in der App, wirkt sofort | automatisch (Schema, `shell-set`, Voreinstellung aus der App) |
| Voreinstellungen lassen `dock.items` in Ruhe | automatisch (`tests/dock.sh`) |
| Export, Reset all, Import: gleiche Darstellung | automatisch (Lage und Screenshot) |
| Werte ausserhalb begrenzt, kaputte Datei abgelehnt | automatisch |
| Leiste und Dock überdecken sich nicht | automatisch (Leiste unten, vier Voreinstellungen); Leiste oben mit Dock oben von Hand |
| Vollbild-Spiel: Dock weg und danach wieder da | automatisch (Vollbild-Testfenster, Gaming-Modus); echtes Spiel von Hand |
| Zweiter Bildschirm, Abstecken | automatisch (sway headless); echter Monitor und Skalierung 1.25/2.0 von Hand |
| Bildwechsel färbt das Dock um | automatisch |
| Nach `hyprctl reload` ein Dock pro Bildschirm, `hyprctl configerrors` leer | von Hand (echtes Hyprland); `Hyprland --verify-config` automatisch |

## Bildschirmgrösse und Skalierung (#111)

| Punkt | Prüfung |
| --- | --- |
| Bei 1280×720 ist jedes Panel vollständig sichtbar und bedienbar | Lage automatisch (`tests/bildschirmgroessen.sh`, sway headless, alle Panels, Dock, Widgets, Karten); Bedienen von Hand |
| 4K und Skalierung 2 sehen gleich gross aus wie der Laptop, nicht winzig | Faktor und Lage automatisch (4K mit Skalierung 1 und 2); Augenschein am echten 4K-Bildschirm von Hand |
| Hochformat: nichts abgeschnitten, Dashboard und Einstellungen umgeordnet | automatisch (Bildschirm um 90° gedreht, Seitenleiste oben); Augenschein von Hand |
| Nach dem Ändern von Auflösung oder Skalierung passt sich alles ohne Neustart an | automatisch (Wechsel im laufenden sway); am Laptop von Hand: `hyprctl keyword monitor eDP-1,preferred,auto,1.25` und zurück, Panels öffnen |
| Zwei Bildschirme mit verschiedener Grösse: jedes Panel rechnet mit seinem | automatisch (2560×1440 neben 1280×720, Abstecken); echter zweiter Monitor von Hand |
| Leiste, Sperr- und Login-Bildschirm bei 1280×720 und 4K | Schriftgrösse der Leiste automatisch (`tests/waybar.sh`); Sperrbildschirm und SDDM am echten Bildschirm von Hand |
| Lokal ohne Quickshell | nicht lokal getestet, CI entscheidet (Arch-Container mit Quickshell) |

## Bildschirme drehen (#112)

| Punkt | Prüfung |
| --- | --- |
| Monitors: jeden Bildschirm auf 0°, 90°, 180°, 270° drehen und spiegeln | Knöpfe, Schalter und settings.json automatisch (`tests/oberflaeche.sh`); Übersetzung 0–7 automatisch (`tests/hyprland-lua.sh`) und von echtem Hyprland angenommen (`tests/hyprland-echt.sh`) |
| Ohne Keep springt die Drehung nach 15 Sekunden zurück | automatisch (mit und ohne Keep) |
| `shell-set` dreht und lehnt ungültige Werte ab | automatisch (`tests/shell-set.sh`, bash- und fish-Vervollständigung) |
| Einstellungen ohne `transform` funktionieren unverändert | automatisch (alter Eintrag gilt als normal, gleiche Hyprland-Aufrufe) |
| Panels passen nach dem Drehen | automatisch (`tests/bildschirmgroessen.sh`, Ausgabe um 90° gedreht) |
| **Bildschirm drehen am echten Laptop** | von Hand: Einstellungen → Monitors → eDP-1 auf 90°, Bild steht hochkant, Panels und Dock passen, Touchscreen/Stift treffen (falls vorhanden); ohne Keep nach 15 s zurück; `shell-set monitor eDP-1 rotate 0` |
| Zwei Bildschirme mit fester Lage: Hinweis bei Überlappung | Rechenweg automatisch (`tests/monitore.sh`); Anzeige mit echtem zweitem Monitor von Hand |
| Lokal ohne Hyprland/Quickshell | nicht lokal getestet, CI entscheidet |

## Dock und Leiste nach dem Schliessen von Programmen (#117)

| Punkt | Prüfung |
| --- | --- |
| Liste der laufenden Programme stimmt nach jedem Schliessen innert 1 s | automatisch (`tests/oberflaeche.sh`: 25-mal öffnen und schliessen, auch mit offenem Menü) |
| Schliessen bei offener Fensterliste/Vorschau: Popup zu, kein Verweis, keine Meldung im Log | automatisch (Fensterliste und Menü, Prüfung auf tote Verweise, Log ohne Warnungen) |
| Ein Panel ohne Fenster (Bildschirm weg, Missa aus) blockiert das Dock nicht | automatisch (unbekanntes Panel, Rückfall nach 1.5 s) |
| Leiste/Oberfläche starten nach einem Absturz neu, ohne Endlosschleife | automatisch (`tests/waechter.sh`) |
| **50-mal Programm öffnen und schliessen am echten Laptop** | von Hand: kitty, Dateimanager, Firefox, ein Fenster mit Dialog, ein Vollbild-Programm; schliessen per SUPER+Q, Rechtsklick im Dock („Close“), im Programm selbst, bei offener Fensterliste und bei verstecktem Dock – danach reagieren Dock und Leiste sofort, `journalctl --user -b \| grep -i quickshell` ohne Fehler |
| Lokal ohne Quickshell/Hyprland | nicht lokal getestet, CI entscheidet |

## Tastatur bleibt nicht hängen (#118)

| Punkt | Prüfung |
| --- | --- |
| Nach SUPER+B und einer anderen Taste, einem Panel, Verstecken oder 10 s ohne Taste gehört die Tastatur wieder dem Programm | automatisch (`tests/oberflaeche.sh`: Buchstabe, Panel, Verstecken, Notfall, Zeitüberschreitung) |
| Kein Panel offen → keine Fläche der Shell will die Tastatur | automatisch (`ipc shell keyboard` leer) |
| CTRL+SUPER+Escape: Kürzel in jeder Submap, Submap verlassen, Fokus unter die Maus | automatisch (`tests/tastatur.sh` mit hyprctl-Attrappe) |
| **Tastatur am echten Laptop** | von Hand: SUPER+B, dann einen Buchstaben → sofort in kitty tippen; SUPER+B, dann in kitty klicken → tippen; SUPER+B, dann SUPER+A (Panel) und zu → tippen; Vollbild an/aus; `hyprctl layers` zeigt ohne offenes Panel keine hypr-shell-Fläche mit Tastatur; CTRL+SUPER+Escape bei offenem Panel und bei offenem Dock-Tastatur-Modus |
| Lokal ohne Quickshell/Hyprland | nicht lokal getestet, CI entscheidet |

