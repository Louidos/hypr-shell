# Changelog

Alle spürbaren Änderungen an diesem Projekt stehen in dieser Datei.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionen nach [Semantic Versioning](https://semver.org/lang/de/).

## Unveröffentlicht

### Hinzugefügt
- Leiste, Abstände, Blur, Animationen, Farben, Schriften, Eingabe, Bildschirme, Sperrzeiten und Standard-Programme sind in settings.json einstellbar und wirken sofort; ein falscher Wert oder kaputtes JSON legt nichts lahm, eine Benachrichtigung nennt Schlüssel und Grund (#31)
- Befehl `shell-set` zum Ändern, Zurücksetzen und Rückgängigmachen von Einstellungen, dazu Profile, Export/Import und Tab-Vervollständigung für bash und fish (#33)
- Einstellungs-App (SUPER+U oder Zahnrad im Panel) mit Schaltern, Reglern, Listen, Farbwähler, Suche, Zurücksetzen, Undo und Profilen; Bildschirme mit 15-Sekunden-Bestätigung (#35)

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
