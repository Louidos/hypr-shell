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
