# Dock

Ein schwebendes, abgerundetes Glas-Dock mittig an der unteren Bildschirmkante, mit den
angehefteten und den laufenden Programmen. Die Leiste (Waybar) bleibt, wie sie ist.

![Dock](screenshots/dock.png)

- Standardmässig **an**; `shell-set dock.enabled false` schaltet es ganz ab (kein Fenster,
  keine Abfrage, der Desktop sieht aus wie vorher).
- Schwebt und reserviert keinen Platz; mit `dock.mode reserve` halten Fenster Abstand.
- Fensteränderungen kommen als Ereignisse (Wayland foreign-toplevel über Quickshell), es wird
  nichts im Takt abgefragt und nichts übers Netz geladen.
- Erreichbar über `shell-quickshell ipc dock toggle|show|hide|focus`.

## Einträge

`dock.items` legt Reihenfolge und Art fest. Standard: Dateimanager, Terminal, Browser (je nur,
wenn installiert), Trenner, Ordner Downloads, Trenner, Papierkorb.

| Art (`type`) | Feld | Wirkung |
| --- | --- | --- |
| `app` | `desktop_id` (z. B. `firefox`) | Programm starten oder nach vorn holen |
| `folder` | `path` (z. B. `~/Downloads`) | Ordner im Dateimanager öffnen |
| `separator` | – | Trenner (nie doppelt, nie am Rand) |
| `trash` | – | Papierkorb öffnen, Symbol zeigt leer/gefüllt |
| `launcher` | – | Starter öffnen |

Fehlt ein Programm, ein Ordner oder der Papierkorb, fehlt der Eintrag still.

Laufende Programme, die nicht angeheftet sind, stehen rechts neben den angehefteten
(`dock.show_running`). Mehrere Fenster einer App teilen sich ein Symbol.

### Welches Symbol bekommt ein Fenster?

In dieser Reihenfolge:

1. `StartupWMClass` aus dem Desktop-Eintrag
2. ID oder Name des Desktop-Eintrags
3. `class`/`app_id` in Kleinschreibung (auch gegen den letzten Teil der Eintrags-ID, z. B.
   `firefox` ↔ `org.mozilla.firefox`)
4. Flatpak-ID (`org.example.App`)
5. Steam-Spiele über `steam_app_<id>` (Eintrag mit `steam_icon_<id>` bzw.
   `steam://rungameid/<id>`)

Klappt nichts, bekommt das Fenster ein eigenes Symbol aus dem Fenstertitel – nie einen leeren
Platz.

## Bedienung

- **Klick**: Läuft das Programm nicht, startet es. Läuft es, kommt sein Fenster nach vorn
  (mit Wechsel der Arbeitsfläche); ein weiterer Klick geht zum nächsten Fenster derselben App.
- **Anzeige**: ein Punkt unter laufenden Programmen, zwei bei mehreren Fenstern, kräftiger beim
  aktiven Fenster (`dock.indicator`: dot, line, none).
- **Volles Dock**: Die Symbole werden bis `dock.icon_min_size` kleiner; reicht das nicht, lässt
  sich das Dock mit dem Mausrad verschieben. Länger als `dock.max_length` wird es nie.
- Klicks neben dem Dock gehen an die Fenster darunter (die Eingabefläche ist genau das Glas).

## Menü, Ziehen und Tastatur

| Aktion | Wirkung |
| --- | --- |
| Mittelklick | neues Fenster (Desktop-Aktion „new-window“, sonst die App noch einmal starten) |
| Rechtsklick | Glas-Menü: New window, die Desktop-Aktionen der App (z. B. „New Private Window“), Keep in Dock / Remove from Dock, Close all |
| Ziehen im Dock | umsortieren (die anderen rücken zur Seite); gespeichert sofort in `dock.items` |
| Herausziehen (über 50 px weg) | löst den Eintrag; ein laufendes Programm bleibt offen |
| Laufendes Programm ins Dock ziehen | heftet es an dieser Stelle an |
| Maus ruht auf einer App mit mehreren Fenstern | Liste der Fenster, mit Vorschau bei `dock.previews` |
| Mausrad über einem Symbol | zwischen den Fenstern der App wechseln |
| Klick und Halten auf einem Ordner | die 10 neuesten Dateien |
| Rechtsklick auf den Papierkorb | „Empty trash“ – leert erst nach einem zweiten Klick |
| `SUPER + B` | Tastatur: Pfeile wählen, Enter startet oder holt nach vorn, Menütaste oder `SHIFT + F10` öffnet das Menü, Esc verlässt das Dock |

„Close all“ schliesst die Fenster wie ein Klick aufs X und beendet nie Prozesse.

**Zähler**: Hat der Benachrichtigungsdienst von hypr-shell ungelesene Meldungen einer App
(`dock.badges`), steht eine kleine Zahl am Symbol; ein Klick auf das Symbol gilt als gelesen.
Ohne Dienst (`notifications.enabled` aus) gibt es keine Zähler.

**Vorschläge**: Ist Nextcloud oder Missa eingeschaltet, bietet das Menü eines Ordners bzw. des
Papierkorbs „Add Nextcloud folder“ bzw. „Add Missa folder“ an – angeheftet wird nichts von selbst.

Starter und Fenster-Übersicht bieten kein Ziehen an; Programme kommen dort deshalb über
„Keep in Dock“ ins Dock.

## Werte

| Name | Standard | Bereich / Werte | Wirkung |
| --- | --- | --- | --- |
| `dock.enabled` | `true` | bool | Dock an/aus |
| `dock.position` | `bottom` | bottom, left, right, top | Kante |
| `dock.monitor` | `all` | all, primary, Name | Auf welchen Bildschirmen |
| `dock.running_per_monitor` | `false` | bool | Nur Fenster dieses Bildschirms zeigen |
| `dock.mode` | `floating` | floating, reserve | Schwebt oder Fenster weichen aus |
| `dock.layer` | `top` | top, bottom | Über oder unter Fenstern |
| `dock.margin` | `10` | 0–100 px | Abstand zum Rand |
| `dock.icon_size` | `48` | 16–128 px | Symbolgrösse |
| `dock.icon_min_size` | `24` | 16–64 px | Kleinste Grösse, wenn es eng wird |
| `dock.padding` | `8` | 0–40 px | Innenabstand |
| `dock.spacing` | `6` | 0–40 px | Abstand zwischen Symbolen |
| `dock.radius` | `22` | 0 bis halbe Höhe | Eckenrundung |
| `dock.max_length` | `90` | 20–100 % | Höchstlänge relativ zur Kante |
| `dock.glass_opacity` | `-1` | -1 oder 0.0–1.0 | Deckkraft des Glases; -1 = wie die Panels (`theme.glass`) |
| `dock.blur` | `true` | bool | Weichzeichner dahinter |
| `dock.border_width` | `1` | 0–6 px | Randstärke |
| `dock.border_color` | `auto` | auto, Farbe | Randfarbe |
| `dock.shadow` | `medium` | none, soft, medium, strong | Schatten |
| `dock.color_mode` | `wallpaper` | wallpaper, dark, light, custom | Farbquelle |
| `dock.custom_color` | `#1e1e2e` | Farbe | Nur bei custom |
| `dock.labels` | `hover` | never, hover, always | Namen anzeigen |
| `dock.indicator` | `dot` | dot, line, none | Anzeige „läuft“ |
| `dock.indicator_color` | `auto` | auto, Farbe | Farbe der Anzeige |
| `dock.show_running` | `true` | bool | Nicht angeheftete laufende Apps zeigen |
| `dock.trash` | `true` | bool | Papierkorb rechts |
| `dock.launcher_button` | `false` | bool | Startknopf links (öffnet den Starter) |
| `dock.badges` | `true` | bool | Zähler für Benachrichtigungen |
| `dock.previews` | `true` | bool | Fenstervorschau in der Fensterliste |
| `dock.items` | Standardliste | Liste | Reihenfolge und Art der Einträge |

Zahlen ausserhalb des Bereichs werden auf die Grenze gesetzt (mit Hinweis), statt verworfen.
