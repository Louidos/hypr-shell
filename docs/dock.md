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

## Bewegung und Verstecken

- **Vergrösserung** (`dock.magnify`): Das Symbol unter der Maus wächst auf
  `dock.magnify_factor`, die Nachbarn bis `dock.magnify_range` weniger stark – als Welle nach
  dem Abstand zur Maus. Die Symbole wachsen von der Kante weg, das Glas wird nach beiden Seiten
  gleich länger, die anderen Symbole springen nicht. Scrollt ein volles Dock, bleibt die
  Vergrösserung aus.
- **Hüpfen beim Start** (`dock.bounce_on_launch`): bis das erste Fenster der App erscheint,
  höchstens 5 Sekunden.
- **Verstecken** (`dock.autohide`):
  - `never`: immer sichtbar
  - `always`: weg, sobald die Maus das Dock verlässt (nach `dock.hide_delay_ms`)
  - `smart` (Standard): nur weg, wenn ein Fenster der aktiven Arbeitsfläche die Fläche des Docks
    überdeckt; geprüft bei Fenster-Ereignissen von Hyprland, nicht im Takt
  - Ein schmaler, unsichtbarer Streifen an der Kante bleibt; Mauskontakt dort blendet das Dock nach
    `dock.show_delay_ms` ein.
  - Menü, Fensterliste, Ziehen, Tastatur (SUPER+B) und die offene Seite „Dock“ der Einstellungen
    halten es sichtbar.
- **Wenn ein Panel offen ist** (`dock.when_panel_open`): Dock und Panels liegen beide auf der
  Ebene Top, früher lag das Dock deshalb über dem Dashboard und verdeckte Kalender und Ringe.
  - `hide` (Standard): Überdeckt das offene Panel (Dashboard, Hot-Corner-Panel, Einstellungen,
    App-Raster, Starter …) die Fläche des Docks, gleitet das Dock über die Kante weg und kommt beim
    Schliessen sofort zurück. Ein Dock mit `dock.mode = reserve` zählt für die Panels dann nicht:
    das Dashboard nutzt die volle Höhe. Panels, die das Dock nicht berühren (z. B. das Power-Menü
    in der Mitte), lassen es stehen. Die offene Seite „Dock“ der Einstellungen zeigt es immer.
  - `behind`: das Dock bleibt, liegt aber unter dem Panel (Ebene Bottom, solange es überdeckt ist).
  - `stay`: das alte Verhalten, das Dock bleibt oben.
- **Dashboard-Kante**: Die Mitte der unteren Kante öffnet sonst das Dashboard. Solange das Dock
  unten versteckt ist (oder gerade über die Kante kam), blendet die Kante das Dock ein; ist das
  Dock normal sichtbar, öffnet die Kante darunter wie bisher das Dashboard. `SUPER + D` öffnet es
  immer.
- `dock.anim_ms` 0 schaltet alle Dock-Animationen ab; ebenso im Gaming-Modus und wenn die
  Animationen von hypr-shell (`look.animations.enabled`) aus sind.

## Zusammenspiel mit dem Rest

- **Leiste**: Liegt die Leiste (Waybar) auf derselben Kante, hält das Dock ihren Abstand ein
  (`dock.avoid_bar`, auch bei `reserve`); die Leiste selbst bleibt unverändert.
- **Panels**: Dashboard, Panel, Starter, Power-Menü und Benachrichtigungen liegen über dem Dock.
  Solange eines offen ist, nimmt das Dock keine Eingaben an; Esc und Klick daneben verhalten sich
  wie vorher.
- **Vollbild und Gaming-Modus** (`dock.hide_on_fullscreen`): Das Dock ist weg, auch die Kante
  blendet es nicht ein; danach ist es wieder da.
- **Mehrere Bildschirme**: `dock.monitor` (all, primary oder ein Name) und
  `dock.running_per_monitor`. An- und Abstecken im laufenden Betrieb gibt genau ein Dock pro
  Bildschirm. Die Symbole werden in doppelter Auflösung geladen und bleiben bei Skalierung 1.25
  und 2.0 scharf.
- **Hintergrundbild**: Mit `dock.color_mode` wallpaper färben sich Glas, Rand und Indikator beim
  Bildwechsel (`shell-wallpaper`) sanft mit um.
- `hyprctl reload` lässt die Oberfläche laufen; `shell-quickshell restart` startet sie neu – in
  beiden Fällen gibt es genau ein Dock pro Bildschirm.

| Helles Bild | Dunkles Bild |
| --- | --- |
| ![hell](screenshots/dock/hell.png) | ![dunkel](screenshots/dock/dunkel.png) |

## Einstellungen

Einstellungs-App → **Dock** (`SUPER + U`): alle Werte in den Abschnitten General, Size & Shape,
Glass & Color, Icons & Indicators, Motion, Behavior und Items. Schieberegler haben ein Zahlenfeld
(anklicken und eintippen), jeder Wert hat „Reset“, abhängige Werte sind grau, solange ihr Schalter
aus ist. Jede Änderung wirkt sofort am echten Dock; solange die Seite offen ist, bleibt das Dock
sichtbar.

**Items**: Liste zum Sortieren (am Griff ziehen oder Pfeile), Entfernen, Hinzufügen von
Programmen (Suche), Ordnern (Pfad oder Vorschlag), Trenner, Papierkorb und Startknopf.

**Voreinstellungen** (`settings/presets/dock/`, auch `shell-dock preset <name>`) ändern nur
dock.*-Werte, nie `dock.items`; alles, was eine Voreinstellung nicht nennt, kommt auf den Standard:

| Name | Wirkung |
| --- | --- |
| `mac` (Standard) | Werte wie in der Tabelle unten |
| `minimal` | 36 px, ohne Vergrösserung, `autohide` always, Indikator line, schwacher Schatten |
| `compact` | 40 px, Abstand 4, Rundung 14, ohne Namen |
| `island` | 56 px, Rundung halbe Höhe, Abstand 16, kräftiger Schatten |
| `full` | `max_length` 100, `margin` 0, Rundung 0, `mode` reserve |

| mac | minimal | compact | island | full |
| --- | --- | --- | --- | --- |
| ![mac](screenshots/dock/mac.png) | ![minimal](screenshots/dock/minimal.png) | ![compact](screenshots/dock/compact.png) | ![island](screenshots/dock/island.png) | ![full](screenshots/dock/full.png) |

**Export, Import, Reset all**: auf der Seite oder mit `shell-dock export <datei>`,
`shell-dock import <datei>`, `shell-dock reset`. Exportiert werden alle dock.*-Werte mit
`dock.items`, sonst nichts. Eine kaputte Datei (kein JSON, unbekannte Werte, Werte ausserhalb des
Bereichs) wird abgelehnt – dann wird nichts übernommen. Die Dock-Werte gehören auch zu den Profilen
von `shell-set profile`.

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
| `dock.icon_style` | `original` | original, mono, theme | Darstellung der Symbole |
| `dock.labels` | `hover` | never, hover, always | Namen anzeigen |
| `dock.indicator` | `dot` | dot, line, none | Anzeige „läuft“ |
| `dock.indicator_color` | `auto` | auto, Farbe | Farbe der Anzeige |
| `dock.show_running` | `true` | bool | Nicht angeheftete laufende Apps zeigen |
| `dock.trash` | `true` | bool | Papierkorb rechts |
| `dock.launcher_button` | `false` | bool | Startknopf links (öffnet den Starter) |
| `dock.badges` | `true` | bool | Zähler für Benachrichtigungen |
| `dock.previews` | `true` | bool | Fenstervorschau in der Fensterliste |
| `dock.magnify` | `true` | bool | Vergrösserung beim Darüberfahren |
| `dock.magnify_factor` | `1.6` | 1.0–2.5 | Stärke |
| `dock.magnify_range` | `2` | 1–5 Symbole | Reichweite der Welle |
| `dock.anim_ms` | `180` | 0–1000 ms | Animationsdauer (0 = aus) |
| `dock.bounce_on_launch` | `true` | bool | Hüpfen beim Start |
| `dock.autohide` | `smart` | never, always, smart | Verstecken |
| `dock.show_delay_ms` | `150` | 0–2000 ms | Verzögerung beim Einblenden |
| `dock.hide_delay_ms` | `400` | 0–5000 ms | Verzögerung beim Ausblenden |
| `dock.hide_on_fullscreen` | `true` | bool | Bei Vollbild und Gaming-Modus weg |
| `dock.when_panel_open` | `hide` | hide, behind, stay | Wegfahren, darunter legen oder oben bleiben, solange ein Panel das Dock überdeckt |
| `dock.avoid_bar` | `true` | bool | Abstand zur Leiste auf derselben Kante |
| `dock.items` | Standardliste | Liste | Reihenfolge und Art der Einträge |
| `dock.preset` | `mac` | mac, minimal, compact, island, full | Zuletzt gewählte Voreinstellung |

Zahlen ausserhalb des Bereichs werden auf die Grenze gesetzt (mit Hinweis), statt verworfen.
