# Testdaten für das Dock

`applications/` enthält Desktop-Einträge für die Zuordnung Fenster → Programm im
Oberflächentest (`tests/oberflaeche.sh`):

| Fenster (app_id/class) | Erwarteter Eintrag | Weg |
| --- | --- | --- |
| `kitty` | `kitty` | Name/ID des Eintrags |
| `firefox` | `firefox` | Name/ID des Eintrags (mit Desktop-Aktionen) |
| `org.example.FlatNotes` | `org.example.FlatNotes` | Flatpak-ID |
| `jetbrains-idea` | `idea` | `StartupWMClass` |
| `steam_app_570` | `Dota 2` | Steam-Spiel (`steam_icon_570`, `steam://rungameid/570`) |
