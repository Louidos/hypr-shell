# hypr-shell

Eigenes Hyprland-Setup im Glas-Look, angelehnt an „DarkShadow's Shell“:
halbtransparente, unscharfe Flächen, stark gerundete Ecken und Farben,
die automatisch aus dem Hintergrundbild entstehen. Gedacht für Arch-basierte
Systeme (CachyOS) mit Hyprland ab 0.55 (Lua-Konfiguration).

## Installation

```bash
gh repo clone Louidos/hypr-shell && cd hypr-shell && ./install.sh
```

Der Installer installiert die nötigen Pakete (pacman, Rest mit paru), kopiert die
Dateien nach `~/.config`, `~/.local/bin`, `~/.local/share/hypr-shell` und
`~/Pictures/Wallpapers` und sichert jede ersetzte Datei vorher nach
`~/.config/hypr-shell-backup-<Zeit>/`.

| Option | Wirkung |
| --- | --- |
| `--yes` | keine Rückfrage |
| `--dry-run` | nur anzeigen, was passieren würde |
| `--no-packages` | keine Pakete installieren, nur Dateien |
| `--restore [ORDNER]` | Stand vor der letzten Installation zurückholen |
| `--uninstall` | alles von hypr-shell entfernen, Ursprungszustand zurück |

## Start

Nach der Installation abmelden und im Login-Manager „Hyprland“ wählen.
Eigene Hintergrundbilder gehören nach `~/Pictures/Wallpapers`; setzen mit
`shell-wallpaper <bild>` – die Farben passen sich automatisch an.
Eigene Hyprland-Anpassungen gehören nach `~/.config/hypr/user.lua`
(wird nie überschrieben).

## Leiste

Oben sitzt eine flache, halbtransparente Waybar: links das Distro-Symbol (öffnet den
Starter), die Arbeitsflächen 1–4 und das aktuelle Lied; rechts Lautstärke, Uhr,
Bluetooth, WLAN, ein roter Punkt während einer Bildschirmaufnahme und der
Ausschalt-Knopf (sperren, abmelden, neu starten, herunterfahren).

## Desktop

Hinter den Fenstern stehen eine grosse gestapelte Uhr (oben links) und drei
Glas-Kacheln mit Ringen für CPU, Arbeitsspeicher und Datenträger (linker Rand).
Position und Grösse stehen in `~/.config/hypr-shell/settings.json` unter `desktop`
(`x`/`y` als Anteil der Bildschirmbreite/-höhe, `scale`, `enabled`); Änderungen
wirken sofort.

## Dashboard

Ein Glas-Panel gleitet unten in der Mitte hoch – mit **SUPER+ALT+D**, wenn die Maus
die Mitte der unteren Bildschirmkante berührt, oder mit **SUPER+W** direkt im Tab
Wallpaper. **Esc** oder Maus weg schliesst es.

| Tab | Inhalt |
| --- | --- |
| Dashboard | Wetter, Profil mit Begrüssung, Musik, Uhr, Kalender, Ringe für CPU/RAM/Disk/Swap |
| Wallpaper | alle Bilder aus `~/Pictures/Wallpapers` mit Suche; Klick setzt Bild und Farben |
| Performance | CPU (Modell, Temperatur, Last), GPU (Modell, Temperatur, Grafikspeicher), Datenträger, Netzwerk, Arbeitsspeicher |
| About | System, Distribution, Version von hypr-shell, Hyprland und Quickshell |

Das Wetter kommt ohne API-Schlüssel von open-meteo.com; den Ort einmal in
`~/.config/hypr-shell/settings.json` unter `weather.location` eintragen (z. B. `"Zürich"`).
Systemwerte werden nur abgefragt, solange das Dashboard offen ist; eine schlafende
NVIDIA-Karte wird dafür nicht geweckt.

## Hot-Corner-Panel

Berührt die Maus die Ecke unten rechts (oder **SUPER+A**), wächst ein schmales
Glas-Panel heraus; es schliesst, sobald die Maus es verlässt.

- **Kopf**: Profilbild (`~/.face`), „Good evening, <Benutzer>“, Datum, Uhrzeit
- **Keep Awake**: verhindert Sperren und Standby (über `systemd-inhibit`, hypridle hält sich daran)
- **Apps**: Suchfeld (Enter startet den ersten Treffer), „All“ öffnet rofi, Raster mit
  den Apps aus `panel.apps` – nicht installierte fallen weg
- **Now playing**: Titel oder „Nothing playing“, zurück / Play / weiter
- **Screenshot**: Screen, Region, Ordner (`~/Pictures/Screenshots`, zusätzlich in der Zwischenablage)
- **Quick Toggles**: WLAN, Bluetooth, Nicht stören, Gaming-Modus (Blur, Animationen und
  Schatten aus – bleibt auch nach `hyprctl reload`), Einstellungen (öffnet `settings.json`)

Reihenfolge und Sichtbarkeit der Karten (`panel.sections`), App-Liste (`panel.apps`) und
Schalter (`panel.toggles`) stehen in `settings.json` und wirken sofort.

## Aufbau

| Ordner | Inhalt |
| --- | --- |
| `config/` | Dotfiles, die nach `~/.config` kopiert werden |
| `quickshell/` | QML-Oberfläche: `desktop/`, `dashboard/`, `panel/`, `common/` |
| `bin/` | Hilfsskripte für `~/.local/bin` |
| `wallpapers/` | mitgelieferte Hintergrundbilder |
| `settings/` | `settings.example.json` mit allen einstellbaren Werten |
| `tests/` | Prüfskripte |
| `docs/` | Doku und Screenshots |

## Projektstand

Version: 0.0.0 – Grundstruktur, noch keine Funktion.
Änderungen stehen in [CHANGELOG.md](CHANGELOG.md).
