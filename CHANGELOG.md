# Changelog

Alle spürbaren Änderungen an diesem Projekt stehen in dieser Datei.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionen nach [Semantic Versioning](https://semver.org/lang/de/).

## Unveröffentlicht

### Geändert
- Uhr, Kacheln, Dashboard, Panel und Sperrbildschirm sehen jetzt aus wie die Vorlage: Desktop-Uhr in JetBrainsMono, Kacheln für CPU, RAM und GPU (schlafende NVIDIA-Karte zeigt „–“), Tab-Leiste über die ganze Breite, drei Ringe ohne Swap, neuer Performance-Tab, Screenshot-Karte mit Hinweis, CPU und RAM auf dem Sperrbildschirm (#21)

### Behoben
- Profilbild, Cover, Hintergrundbild-Vorschauen und App-Symbole fehlen nicht mehr; ohne `~/.face` steht überall der Anfangsbuchstabe, auch auf dem Sperrbildschirm (#20)

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
