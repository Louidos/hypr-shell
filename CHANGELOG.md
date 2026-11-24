# Changelog

Alle spürbaren Änderungen an diesem Projekt stehen in dieser Datei.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionen nach [Semantic Versioning](https://semver.org/lang/de/).

## Unveröffentlicht

### Behoben
- Das Dock verdeckt das Dashboard und andere Flächen nicht mehr; es fährt weg, solange sie offen sind, und ist nach dem Schliessen sofort wieder da (einstellbar unter Dock → „When a panel is open“: hide, behind oder stay) (#138)

## 1.10.0 – 2026-11-24

### Hinzugefügt
- Fenster haben oben rechts Knöpfe zum Minimieren, Maximieren und Schliessen (umstellbar auf macOS-Stil); minimierte Fenster liegen im Dock und kommen per Klick an ihre alte Stelle zurück (SUPER+M, SUPER+SHIFT+M) (#120)
- Mit ALT+Tab zwischen offenen Programmen wechseln, mit Vorschaubildern: zuletzt benutzte zuerst, ALT loslassen wechselt, Escape bricht ab, auch minimierte Fenster und andere Arbeitsflächen (#121)
- Fenster an den Rand ziehen: oben Vollbild, seitlich halbe Breite, in die Ecke ein Viertel, mit Vorschau; Fenster sind jetzt standardmässig frei verschiebbar (Kacheln weiter einstellbar, SUPER+SHIFT+T); SUPER+Pfeile docken an (#122)
- App-Raster wie Start-Menü/Launchpad: SUPER allein antippen, der neue Knopf im Dock oder ein Klick auf das Logo in der Leiste zeigt alle Apps mit Suche, Kategorien, Favoriten und zuletzt benutzten; Rechtsklick heftet im Dock an, merkt Favoriten oder öffnet ein neues Fenster; neues Leisten-Modul `apps` (#123)

### Geändert
- Einheitlicher Glas-Look: grau durchsichtig, feiner weisser Rand und runde Ecken (14 px) überall – Leiste (jetzt schwebend), Dock, Panels, Menüs, Benachrichtigungen, rofi – auch an den Programmfenstern (leicht durchsichtig, Spiele, Videos und Bildbearbeitung undurchsichtig); bei hellem Hintergrundbild wird das Glas automatisch dunkler; Voreinstellungen glass, minimal und gaming mit Live-Vorschau (#119)
- Abmelden liegt jetzt auf CTRL+SUPER+M (vorher SUPER+M, das jetzt minimiert); selbst gesetzte Kürzel bleiben (#120)
- Fokus in eine Richtung liegt jetzt auf SUPER+ALT+Pfeile (vorher SUPER+Pfeile, die jetzt andocken); neue Fenster öffnen schwebend statt gekachelt (fenster.modus); selbst gesetzte Kürzel bleiben (#122)
- Klick auf das Logo in der Leiste öffnet jetzt das App-Raster; der Starter (Suche) liegt auf Rechtsklick und weiter auf SUPER+R, SUPER+Space und ALT+Space (#123)

### Behoben
- Ein eigenes Kürzel auf einer fest belegten Taste (Lautstärke, Helligkeit, Medien) wird abgelehnt statt die Hyprland-Konfiguration zu stören (#88)
- Bei einem Kürzel-Konflikt mit den Arbeitsflächen-Tasten nennt die Meldung die kollidierende Kombination (z. B. `SUPER + SHIFT + 1`) statt nur den Modifikator (#88)
- `shell-set` stürzt nicht mehr ab, wenn in settings.json eine Gruppe ein einzelner Wert ist (z. B. `{"look": 5}`); Setzen ersetzt sie, Zurücksetzen entfernt sie (#90)
- `shell-set` lehnt `nan` als Zahl ab, statt den Wert still zu löschen (#90)
- Klarere Meldungen bei kaputter settings.json: eine leere Datei wird als leer gemeldet, ohne „jq: parse error“ und Dateipfad davor (#90)
- `shell-set --help` und `shell-apply --help` zeigen keine überzählige Zeile aus dem Skript mehr (#90)

## 1.9.2 – 2026-11-24

### Behoben
- Dock und Leiste reagieren nach dem Schliessen eines Programms wieder zuverlässig: Fensterliste, Vorschau und Menü eines geschlossenen Programms gehen sofort zu, ein hängengebliebenes Panel blockiert keine Klicks mehr im Dock, und stürzen Leiste oder Oberfläche ab, starten sie von selbst neu (#117)
- Die Tastatur bleibt nicht mehr beim Dock oder einem Panel hängen: der Tastatur-Modus des Docks (SUPER+B) endet bei jeder anderen Taste, einem Klick daneben, wenn ein Panel aufgeht, das Dock verschwindet oder nach 10 Sekunden (`dock.keyboard_timeout_s`); Flächen halten die Tastatur nur, solange sie sichtbar offen sind; das neue Notfall-Kürzel CTRL+SUPER+Escape gibt sie jederzeit frei, `shell-diag tastatur` zeigt, wer sie hat (#118)

## 1.9.1 – 2026-11-23

### Behoben
- Ist ein Konfigurationsordner ein Link auf einen schreibgeschützten Dotfiles-Ordner, ist die Kopie, die die Installation daraus macht, jetzt beschreibbar; vorher konnte die Installation nicht hineinschreiben (#132)

## 1.9.0 – 2026-11-23

### Hinzugefügt
- Bildschirme lassen sich in den Einstellungen (Seite Monitors) und mit `shell-set monitor <name> rotate 0|90|180|270` bzw. `mirror on|off` drehen und spiegeln, mit Bestätigung und automatischem Zurücksetzen nach 15 Sekunden; ein Touchscreen oder Stift dreht mit (#112)

### Behoben
- Bearbeiten-Modus der Desktop-Widgets (SUPER+ALT+W): keine Warnung „Binding loop“ mehr im Log beim Ein- und Ausblenden (#110)
- Ohne eigenes Profilbild (~/.face) zeigen Dashboard, Panel und Einstellungen den Anfangsbuchstaben, ohne bei jedem Öffnen „Cannot open“ ins Log zu schreiben (#110)
- Beim ersten Start (noch kein Verlauf, kein Chat, keine Farben aus dem Hintergrundbild) stehen keine Warnungen „File does not exist“ mehr im Log (#110)
- Sensor-Kachel heisst ohne Anbindung wie in den Einstellungen „Air quality“ statt „Sensor“; das Dock zeigt die Standard-Einträge auch, bevor das Schema gelesen ist (#110)
- Ist der unter Desktop → Screen eingestellte Bildschirm abgesteckt, erscheinen Widgets und Panels auf dem ersten Bildschirm und wechseln zurück, sobald er wieder da ist; ein Hinweis steht im Log (#110)
- Dashboard, Einstellungen, Spickzettel, Übersicht, Dock und Widgets rechnen ohne bekannten Bildschirm mit dem echten ersten Bildschirm statt mit fest 1920×1080 (#110)
- Einstellungen → Monitors zeigt die laufende und die eingestellte Auflösung immer zur Auswahl an, auch wenn sie nicht zu den sechs grössten gehört; ohne bekannte Bildrate steht kein „@ 0 Hz“ mehr da (#110)
- Fehlt beim Aufruf von shell-clipboard, shell-games, shell-laptop, shell-missa, shell-net oder shell-overview ein Argument, kommt eine klare Meldung; `shell-clipboard delete` ohne ID lief vorher still weiter (#110)
- Leiste, Dock, Widgets und alle Panels passen sich an Bildschirmgrösse, Skalierung und Hochformat an, nichts wird mehr abgeschnitten: Panels bleiben im freien Platz (ohne Leiste und reserviertes Dock) und rollen, wenn sie nicht passen; auf 4K mit Skalierung 1 ist alles grösser; im Hochformat ordnen sich Dashboard und Einstellungen um; jeder Bildschirm rechnet mit seiner eigenen Grösse, ohne Neustart (#111)
- Die Schrift der Leiste wird bei niedriger Leiste (`bar.height`) und grossem Schriftfaktor kleiner, statt über die Leiste zu ragen (#111)
- `shell-set help` zeigt am Ende nicht mehr die Zeile `set -euo pipefail` (#112)

## 1.8.0 – 2026-11-23

### Geändert
- Neutrale Grund-Kürzel: SUPER+Enter Terminal, CTRL+SUPER+Enter App-Suche, SUPER+Q Fenster schliessen (SUPER+C bleibt), dazu SUPER+F Vollbild; selbst geänderte Kürzel bleiben (#82)

## 1.7.0 – 2026-11-23

### Hinzugefügt
- Dock bis ins Detail einstellbar (Einstellungs-App → Dock) mit Live-Vorschau, fünf Voreinstellungen (mac, minimal, compact, island, full) sowie Export und Import (#80)
- Dock mit Vergrösserung beim Darüberfahren, Hüpfen beim Start und automatischem Verstecken (smart: nur wenn ein Fenster es überdeckt) (#79)
- Dock mit Menü per Rechtsklick, Sortieren per Ziehen, Ordnern, Papierkorb, Fensterliste mit Vorschau, Zählern für Benachrichtigungen und Tastaturbedienung (SUPER+B) (#78)
- Schwebendes Dock in der Mitte unten mit angehefteten und laufenden Programmen; Klick startet oder holt das Fenster nach vorn, abschaltbar mit `dock.enabled` (#77)

### Geändert
- Das Dock weicht der Leiste aus, verschwindet bei Vollbild und Spielen und passt sich Bildschirmen und Hintergrundbild an (#81)

### Behoben
- Ein leerer Name oder einer mit Anführungszeichen für das Symbolthema wird wieder abgelehnt (die Prüfung war beim Zusammenführen verloren gegangen) (#100)

## 1.6.0 – 2026-11-23

### Hinzugefügt
- Passender Login-Bildschirm (SDDM) im Stil des Sperrbildschirms, installierbar mit `./install.sh --login-theme`, zurück mit `--login-theme-remove`; ohne SDDM wird nichts geändert (#71)
- Dateimanager und weitere Programme übernehmen die Farben des Hintergrundbilds: GTK und Qt standardmässig, Firefox, Discord (Vesktop) und Spotify (spicetify) einzeln einschaltbar, wenn installiert; Abschalten legt die gesicherten Dateien zurück (#70)

### Behoben
- Ein Anführungszeichen, Backslash, `;` oder eine Klammer im Namen einer Schrift, eines Mauszeigers oder Symbolthemas wird abgelehnt statt die Leiste verschwinden zu lassen; leere Namen und Programme aus lauter Leerzeichen ebenso
- Missa-Agent: Ein Auftrag direkt nach einer Änderung der Einstellungen fragt nicht mehr fälschlich nach (#91)

## 1.5.0 – 2026-11-23

### Hinzugefügt
- Homelab-Übersicht über Missa (Tab Lab), Kalendertermine (CalDAV) und Sensor-Kachel im Dashboard, einschaltbar in den Einstellungen (#64)
- Missa kann am Rechner Dateien finden und öffnen, Programme und Fenster steuern und nach Bestätigung Befehle ausführen; sichtbar in der Leiste, sofort trennbar im Panel, jede Aktion im Verlauf, einschaltbar in den Einstellungen (#63)
- Mit Missa sprechen und Antworten vorlesen lassen (SUPER+SHIFT+I), lokal mit whisper.cpp und piper, einschaltbar in den Einstellungen (#62)
- Chat mit Missa direkt am Desktop (SUPER+I) und Missa-Karte im Dashboard, einschaltbar in den Einstellungen (#61)
- Nextcloud und Missa als Ordner im Dateimanager, alle persönlichen Anbindungen sind standardmässig aus und in den Einstellungen (Seite Integrations) einschaltbar; Zugangsdaten nur in `secrets.env` (#59)

## 1.4.0 – 2026-11-23

### Hinzugefügt
- Spiele-Tab im Dashboard (zuletzt gespielte Steam-Spiele mit Cover, eigene Einträge einschaltbar) und automatischer Gaming-Modus, solange ein Spiel im Vollbild läuft (#57)
- Leistungsprofil, Grafik-Modus, Ladegrenze und Tastaturlicht für ROG-Laptops (asusctl, supergfxctl) auf der neuen Einstellungsseite Laptop; sie erscheint nur, wenn der Rechner das kann (#56)

### Behoben
- Die Ladegrenze lässt sich wieder auf 100 % zurückstellen (Regler, `shell-set laptop.charge_limit 100` oder Reset); eine nur mit asusctl gesetzte Grenze lässt hypr-shell weiterhin in Ruhe

## 1.3.0 – 2026-11-23

### Hinzugefügt
- Übersicht aller Tastenkürzel (SUPER+F1): in Gruppen, mit Suche, immer aus den aktuellen Belegungen; eigene Kürzel unter „Custom“ (#53)
- WLAN, Bluetooth und Ton direkt im Panel (Unterseiten über einen Pfeil am Schalter oder Klick auf das Symbol in der Leiste), dazu Schalter für Leistungsprofil und Nachtlicht mit Zeitplan; fehlende Geräte blenden ihren Schalter aus (#52)
- Fenster-Übersicht (SUPER+Tab): alle Arbeitsflächen mit ihren Fenstern, Klick springt hin, Ziehen verschiebt, Tippen filtert (#51)
- Verlauf der Zwischenablage (SUPER+SHIFT+V): Text und Bilder mit Vorschau, Suche, Enter fügt ein, Entf löscht, Clear all; Anzahl einstellbar, abschaltbar (#50)
- Anzeige für Lautstärke, Mikrofon, Bildschirm- und Tastaturhelligkeit sowie Power-Menü im Glas-Look (SUPER+Escape, Knopf in der Leiste); Restart und Shutdown brauchen einen zweiten Druck, swayosd wird nicht mehr gebraucht (#49)
- Benachrichtigungen im Glas-Look mit Verlauf (SUPER+N oder Glocke in der Leiste): Karten oben rechts mit Knöpfen, Verlauf nach App gruppiert, einzeln oder alle löschen, Nicht stören; ersetzt swaync (#48)
- App-Starter im Glas-Look mit Rechner (SUPER+R, SUPER+Space): Suche nach Name und Beschreibung, zuletzt benutzte zuerst, `=12*8` rechnet; mit `apps.launcher` lässt sich wieder rofi einstellen (#46)

### Geändert
- Es ist immer nur ein Panel offen: Öffnet man Dashboard, Panel oder Einstellungs-App, schliesst das andere; Esc und ein Klick daneben schliessen, SUPER+D öffnet zusätzlich das Dashboard (#44)

## 1.2.0 – 2026-11-23

### Hinzugefügt
- Leiste, Abstände, Blur, Animationen, Farben, Schriften, Eingabe, Bildschirme, Sperrzeiten und Standard-Programme sind in settings.json einstellbar und wirken sofort; ein falscher Wert oder kaputtes JSON legt nichts lahm, eine Benachrichtigung nennt Schlüssel und Grund (#31)
- Befehl `shell-set` zum Ändern, Zurücksetzen und Rückgängigmachen von Einstellungen, dazu Profile, Export/Import und Tab-Vervollständigung für bash und fish (#33)
- Einstellungs-App (SUPER+U oder Zahnrad im Panel) mit Schaltern, Reglern, Listen, Farbwähler, Suche, Zurücksetzen, Undo und Profilen; Bildschirme mit 15-Sekunden-Bestätigung (#35)
- Tastenkürzel ansehen, ändern und eigene anlegen (Einstellungs-App → Keybinds, `shell-set keybinds.…`); doppelte Belegungen werden abgelehnt und benannt, ohne Änderung gelten die bisherigen Kürzel (#37)
- Uhr und Kacheln mit der Maus verschieben und skalieren (SUPER+ALT+W oder „Edit on desktop“), mit Hilfslinien, Done, Cancel und Reset positions (#38)
- Vollständige Übersicht aller Einstellungen mit Beispielen (`docs/einstellungen.md`, aus dem Schema erzeugt); die Seite About der App öffnet settings.json und diese Übersicht (#39)

### Geändert
- Das Zahnrad im Panel öffnet die Einstellungs-App statt settings.json im Editor; neue Installationen tragen das Tastaturlayout direkt in settings.json ein, eine vorhandene `hypr-shell-local.lua` wird einmalig übernommen (#31, #35)

## 1.1.0 – 2026-11-23

### Hinzugefügt
- Akku-Anzeige in der Leiste, einstellbare Skalierung und Touchpad (`scale`, `natural_scroll`, `tap_to_click` in `hypr-shell-local.lua`), scharfe Spiele bei skaliertem Bildschirm (#22)
- `./install.sh --update` holt den neuen Stand und installiert ihn, eigene Einstellungen bleiben; der Installer bietet vorher ein Systemupdate an und sagt am Ende, was als Nächstes zu tun ist (#23)

### Geändert
- Uhr, Kacheln, Dashboard, Panel und Sperrbildschirm sehen jetzt aus wie die Vorlage: Desktop-Uhr in JetBrainsMono, Kacheln für CPU, RAM und GPU (schlafende NVIDIA-Karte zeigt „–“), Tab-Leiste über die ganze Breite, drei Ringe ohne Swap, neuer Performance-Tab, Screenshot-Karte mit Hinweis, CPU und RAM auf dem Sperrbildschirm (#21)

### Behoben
- Profilbild, Cover, Hintergrundbild-Vorschauen und App-Symbole fehlen nicht mehr; ohne `~/.face` steht überall der Anfangsbuchstabe, auch auf dem Sperrbildschirm (#20)
- Abbruch mit klarer Meldung bei zu altem Hyprland (unter 0.55), bevor etwas verändert wird (#23)
- Das Zahnrad im Panel öffnet `settings.json` im Terminal mit `$EDITOR` (sonst nano) statt über xdg-open (#23)

## 1.0.0 – 2026-11-23

### Hinzugefügt
- Grundstruktur des Projekts mit automatischer Prüfung bei jeder Änderung (#1)
- Installation mit einem Befehl, inklusive Sicherung und Wiederherstellung der alten Einstellungen; Hyprland mit Blur, runden Ecken, Tastenkürzeln, Hintergrundbild und daraus erzeugten Farben (#2)
- Leiste oben mit Arbeitsflächen, aktuellem Lied, Uhr, Lautstärke, WLAN, Bluetooth, Aufnahme-Punkt und Ausschalt-Menü; Farben passen sich dem Hintergrundbild an (#3)
- Grosse Uhr und Ringe für CPU, RAM und Datenträger auf dem Desktop, Position über settings.json einstellbar (#4)
- Dashboard mit Wetter, Kalender, Musik, Leistungswerten und Hintergrundbild-Auswahl; öffnet mit SUPER+ALT+D, SUPER+W oder an der Mitte der unteren Bildschirmkante (#5)
- Panel in der Bildschirmecke unten rechts (auch SUPER+A) mit Keep Awake, Apps, Musik, Screenshot und Schnellschaltern für WLAN, Bluetooth, Nicht stören und Gaming-Modus (#6)
- Sperrbildschirm mit grosser Uhr, Begrüssung und Power-Knöpfen; sperrt nach 5 Minuten automatisch, Standby nach 15 Minuten, Keep Awake setzt beides aus (#7)
- Anleitung für Installation, Tastenkürzel und Anpassung mit Screenshots (#8)
