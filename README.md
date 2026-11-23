# hypr-shell

Eigenes Hyprland-Setup im Glas-Look, angelehnt an „DarkShadow's Shell“:
halbtransparente, unscharfe Flächen, stark gerundete Ecken und Farben,
die automatisch aus dem Hintergrundbild entstehen. Gedacht für Arch-basierte
Systeme (CachyOS) mit Hyprland ab 0.55 (Lua-Konfiguration).

## Installation

```bash
gh repo clone Louidos/hypr-shell && cd hypr-shell && ./install.sh
```

## Start

Nach der Installation abmelden und im Login-Manager „Hyprland“ wählen.

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
