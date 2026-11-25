# hypr-shell

Eigenes Hyprland-Setup im Glas-Look, angelehnt an „DarkShadow's Shell“:
halbtransparente Flächen über unscharfem Hintergrund, stark gerundete Ecken und
Farben, die automatisch aus dem Hintergrundbild entstehen. Gedacht für Arch-basierte
Systeme (CachyOS) mit Hyprland ab 0.55 (Lua-Konfiguration) und Quickshell.

![Dashboard](docs/screenshots/dashboard-dashboard.png)

## Installation

```bash
gh repo clone Louidos/hypr-shell && cd hypr-shell && ./install.sh
```

Danach **abmelden und im Login-Manager „Hyprland“ wählen**. Das ist alles.

Der Installer

- prüft zuerst die Hyprland-Version: Ist ein Hyprland älter als 0.55 installiert, bricht er
  ab, bevor er etwas verändert, mit dem Hinweis `sudo pacman -Syu hyprland`,
- bietet an, vorher das System zu aktualisieren (`sudo pacman -Syu`; mit `--yes` ohne Frage),
- installiert die nötigen Pakete (pacman, den Rest mit paru) und prüft die Namen vorher,
- kopiert die Dateien nach `~/.config`, `~/.local/bin`, `~/.local/share` und `~/Pictures/Wallpapers`,
- sichert **jede** ersetzte Datei vorher nach `~/.config/hypr-shell-backup-<Zeit>/`,
- legt `~/.config/hypr-shell/settings.json` an (nur wenn sie fehlt) und trägt dort das
  Tastaturlayout aus `localectl` ein, übernimmt Umgebungsvariablen der alten
  Hyprland-Konfiguration (z. B. für NVIDIA), damit Spiele wie vorher starten,
- läuft nie als root; sudo wird nur für pacman verwendet,
- listet am Ende auf, falls noch ein Programm fehlt, und sagt, was als Nächstes zu tun ist
  (abmelden, Hyprland wählen, Wetter-Ort eintragen) und wie man alles zurücknimmt.

| Option | Wirkung |
| --- | --- |
| `--yes` | keine Rückfrage |
| `--dry-run` | nur anzeigen, was passieren würde – nichts wird verändert |
| `--no-packages` | keine Pakete installieren, nur Dateien kopieren |
| `--update` | neuen Stand holen (`git pull --ff-only`) und neu installieren; `settings.json`, `user.lua` und `hypr-shell-local.lua` bleiben unberührt |
| `--restore [ORDNER]` | Stand vor der letzten Installation zurückholen |
| `--uninstall` | alles von hypr-shell entfernen, Zustand vor der ersten Installation zurück |
| `--login-theme` | Anmeldebildschirm (SDDM) im Stil des Sperrbildschirms – nur auf Wunsch, siehe unten |
| `--login-theme-remove` | vorherigen Anmeldebildschirm zurückholen |

### Anmeldebildschirm (nur auf Wunsch)

```bash
./install.sh --login-theme
```

installiert ein SDDM-Thema im Stil des Sperrbildschirms: unscharfes, abgedunkeltes
Hintergrundbild, Profilbild, grosse gestapelte Uhr, Datum, Begrüssung, Passwort als schlichte
Linie, Benutzer- und Sitzungswahl (Klick schaltet weiter) und Standby, Neustart,
Herunterfahren. Farben und Bild kommen vom aktuellen Hintergrundbild; nach einem Bildwechsel
übernimmt ein erneuter Aufruf die neuen Farben.

- Die normale Installation fasst den Anmeldemanager **nie** an.
- Ist nicht SDDM der aktive Anmeldemanager (z. B. GDM), bricht der Befehl mit einer klaren
  Meldung ab und ändert nichts.
- Das Thema wird vorher im Testmodus des Greeters gestartet (`sddm-greeter-qt6 --test-mode`);
  meldet er Fehler, bleibt alles, wie es war.
- Die bisherige Einstellung (`/etc/sddm.conf`, vorhandene Dateien) wird nach
  `~/.local/share/hypr-shell/login-theme/` gesichert; geschrieben wird mit sudo nach
  `/usr/share/sddm/themes/hypr-shell` und `/etc/sddm.conf.d/99-hypr-shell.conf`.

```bash
./install.sh --login-theme-remove
```

legt die Sicherung zurück; ab der nächsten Anmeldung gilt wieder der vorherige Bildschirm.

## Aktualisieren

```bash
./install.sh --update
```

holt den neuen Stand aus GitHub und installiert ihn. Eigene Einstellungen
(`~/.config/hypr-shell/settings.json`, `~/.config/hypr/user.lua`,
`~/.config/hypr/hypr-shell-local.lua`) bleiben, wie sie sind. Hat man im Ordner selbst etwas
geändert, bricht `--update` ab, ohne etwas zu installieren.

## Rückgängig machen

```bash
./install.sh --restore
```

holt die Dateien zurück, die die letzte Installation ersetzt hat, und entfernt die neu
hinzugekommenen. Mit `./install.sh --restore ~/.config/hypr-shell-backup-<Zeit>` lässt sich
eine bestimmte Sicherung wählen.

```bash
./install.sh --uninstall
```

entfernt alle Dateien von hypr-shell und stellt den Zustand vor der ersten Installation
her. Die Sicherungsordner bleiben liegen. Danach abmelden und wieder anmelden.

## Tastenkürzel

`SUPER + F1` zeigt alle Kürzel als Spickzettel – in Gruppen, mit Suche, gelesen aus den echten
Belegungen (`hyprctl binds -j`), also immer auf dem aktuellen Stand. Eigene Kürzel stehen dort unter
„Custom“.

**Die wichtigsten Kürzel**

| Kürzel | Wirkung |
| --- | --- |
| `SUPER + Enter` | Terminal öffnen |
| `CTRL + SUPER + Enter` | App-Suche (Starter) |
| `SUPER + Q` | aktives Fenster schliessen |

**Alle Kürzel**

| Kürzel | Wirkung |
| --- | --- |
| `SUPER + Return` (Enter) | Terminal (kitty) |
| `SUPER + Q` / `SUPER + C` | Fenster schliessen (wie ein Klick aufs X) |
| `SUPER + F` | Vollbild an / aus |
| `SUPER + E` | Dateien (Nautilus) |
| `CTRL + SUPER + Return` / `SUPER + R` / `SUPER + Space` / `ALT + Space` | Starter (Suche nach Apps, `=` rechnet) |
| `SUPER` allein antippen (`SUPER + Super_L` / `SUPER + Super_R`, beim Loslassen) | App-Raster (alle Apps, wie Start-Menü) |
| `SUPER + V` | Fenster schwebend / gekachelt |
| `SUPER + SHIFT + V` | Verlauf der Zwischenablage |
| `SUPER + Tab` | Fenster-Übersicht aller Arbeitsflächen |
| `SUPER + F1` | Kürzel-Spickzettel |
| `SUPER + B` | Dock mit der Tastatur bedienen (Pfeile, Enter, Menütaste oder `SHIFT + F10`, Esc; jede andere Taste, ein Klick daneben oder 10 s ohne Taste geben die Tastatur zurück) |
| `CTRL + SUPER + Escape` | Notfall: Tastatur zurück (siehe [Tastatur geht nicht](docs/tastenkuerzel.md#tastatur-geht-nicht)) |
| `SUPER + I` | Chat mit Missa (nur mit `missa.enabled`, sonst tut das Kürzel nichts) |
| `SUPER + SHIFT + I` | mit Missa sprechen; nochmal drücken beendet (nur mit `missa.voice_enabled` und whisper.cpp) |
| `ALT + Tab` | zwischen Fenstern wechseln (ALT halten, Tab wählt weiter, loslassen wechselt; Esc bricht ab, Q/Entf schliesst) |
| `ALT + SHIFT + Tab` | dasselbe rückwärts |
| `SUPER + M` | Fenster minimieren (liegt dann abgedunkelt im Dock) |
| `SUPER + SHIFT + M` | zuletzt minimiertes Fenster zurückholen |
| `CTRL + SUPER + M` | abmelden (Hyprland beenden; bis 1.9 `SUPER + M`) |
| `SUPER + L` | sperren |
| `SUPER + Escape` | Power-Menü (Lock, Sleep, Logout, Restart, Shutdown) |
| `SUPER + left` / `SUPER + right` | Fenster an die linke/rechte Hälfte andocken (danach `SUPER + up`/`down`: Viertel) |
| `SUPER + up` / `SUPER + down` | maximieren zwischen Leiste und Dock / wiederherstellen (nicht angedockt: minimieren) |
| `SUPER + ALT + left` / `SUPER + ALT + right` / `SUPER + ALT + up` / `SUPER + ALT + down` | Fokus in diese Richtung (bis 1.9 `SUPER + Pfeile`) |
| `SUPER + SHIFT + T` | Fenster-Modus: schwebend ↔ kacheln |
| `SUPER + 1` … `SUPER + 0` | zu Arbeitsfläche 1–10 |
| `SUPER + SHIFT + 1` … `SUPER + SHIFT + 0` | Fenster auf Arbeitsfläche 1–10 verschieben |
| `SUPER + mouse_down` / `SUPER + mouse_up` (Mausrad) | nächste / vorige Arbeitsfläche |
| `SUPER + mouse:272` (linke Maustaste ziehen) | Fenster verschieben |
| `SUPER + mouse:273` (rechte Maustaste ziehen) | Fenstergrösse ändern |
| `SUPER + ALT + D` / `SUPER + D` | Dashboard öffnen / schliessen |
| `SUPER + W` | Dashboard im Tab Wallpaper |
| `SUPER + A` | Hot-Corner-Panel öffnen / schliessen |
| `SUPER + N` | Benachrichtigungen (Verlauf) öffnen / schliessen |
| `SUPER + U` | Einstellungs-App öffnen / schliessen |
| `SUPER + ALT + W` | Uhr und Kacheln auf dem Desktop verschieben und skalieren |
| `Print` | Screenshot eines Bereichs (speichern + Zwischenablage) |
| `SHIFT + Print` | Screenshot des ganzen Bildschirms (speichern + Zwischenablage) |
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` | Lautstärke + / − |
| `XF86AudioMute` / `XF86AudioMicMute` | Ton / Mikrofon stumm |
| `XF86MonBrightnessUp` / `XF86MonBrightnessDown` | Helligkeit + / − |
| `XF86KbdBrightnessUp` / `XF86KbdBrightnessDown` | Tastaturbeleuchtung + / − |
| `XF86AudioPlay` / `XF86AudioPause` / `XF86AudioNext` / `XF86AudioPrev` | Medien: Play/Pause, weiter, zurück |
| `Esc` | Dashboard, Panel oder Einstellungs-App schliessen (auch ein Klick daneben schliesst) |
| Wischen mit drei Fingern | Arbeitsfläche wechseln |

Alle Kürzel lassen sich in der Einstellungs-App auf der Seite **Keybinds** ändern (Klick, dann die
neue Kombination drücken) oder mit `shell-set keybinds.<aktion> "SUPER + T"`; ein leeres Kürzel heisst
„keine Taste“. Eigene Kürzel stehen in `keybinds.custom`. Eine Kombination, die schon belegt ist, wird
abgelehnt und die belegende Aktion genannt (`shell-set` und die Einstellungs-App schon bei der Eingabe).
Steht in einer von Hand bearbeiteten settings.json eine Taste doppelt, verliert das im Schema spätere
Kürzel seine Taste – ist das eine Gruppe wie die Arbeitsflächen-Kürzel, die ganze Gruppe –, und eine
Benachrichtigung nennt beide. `SUPER + U` (Einstellungs-App) lässt sich nicht leeren.
Die Medien-, Lautstärke- und Helligkeitstasten bleiben fest.

Maus: Ecke **unten rechts** öffnet das Panel, die **Mitte der unteren Kante** das Dashboard.
Es ist immer nur ein Panel offen: Öffnet man eines, schliesst das andere. Jedes Panel lässt sich
auch per `shell-quickshell ipc <name> toggle` öffnen und schliessen (`dashboard`, `panel`, `settings`).

## Was ist dabei?

### Leiste

Oben eine flache, halbtransparente Waybar: links Distro-Symbol (öffnet den Starter),
Arbeitsflächen 1–4 und das aktuelle Lied; rechts Lautstärke, Akku (nur mit Akku), Uhr, Bluetooth, WLAN, ein
roter Punkt während einer Bildschirmaufnahme, die Glocke mit der Zahl der Benachrichtigungen und der Ausschalt-Knopf (sperren, abmelden,
neu starten, herunterfahren).

### Desktop

Hinter den Fenstern eine grosse gestapelte Uhr (JetBrainsMono, Stunden kräftig, Minuten
blasser) und drei Glas-Kacheln mit Ringen für CPU, Arbeitsspeicher und Grafikkarte. Schläft
die NVIDIA-Karte (Hybrid-Grafik), zeigt die GPU-Kachel „–“ – sie wird dafür nicht geweckt.

**Verschieben:** `SUPER + ALT + W` (oder „Edit on desktop“ auf der Seite Desktop der
Einstellungs-App) schaltet in den Bearbeiten-Modus: Uhr und Kacheln bekommen einen Rahmen, lassen sich
mit der Maus ziehen und mit dem Mausrad grösser oder kleiner machen; an den Rändern und der Mitte
rasten sie an Hilfslinien ein. Oben stehen **Done** (speichern), **Cancel** und **Reset positions**;
`Esc` bricht ab. Gespeichert wird die Lage als Anteil der Bildschirmgrösse (`desktop.clock.x` …), die
Grösse als Faktor (`desktop.clock.scale`). Ausserhalb des Modus nehmen die Widgets keine Klicks an.

![Desktop](docs/screenshots/desktop.png)

### Dashboard

Gleitet unten in der Mitte hoch. Oben gleich breite Tabs (Symbol über dem Text, der
aktive als weisse Pille):

| Tab | Inhalt |
| --- | --- |
| Dashboard | Wetter, Profil mit Begrüssung, Musik, Uhr, Kalender, drei Ringe für CPU/RAM/Disk |
| Wallpaper | alle Bilder aus `~/Pictures/Wallpapers` mit Suche; Klick setzt Bild und Farben |
| Performance | CPU und GPU mit Modell, Temperatur und Auslastung („Usage“; eine schlafende NVIDIA-Karte wird nicht geweckt), Datenträger, Netzwerk mit Verlauf, Arbeitsspeicher |
| Lab | nur mit `lab.enabled`: VMs und IPs, Messwerte und Erreichbarkeit, Container und Alarme des Homelabs, gelesen über Missa-Core |
| Games | zuletzt gespielte Steam-Spiele mit Cover, Klick startet; eigene Einträge (GOG, Battle.net …) mit `games.custom_enabled` und `games.custom`. Ohne Spiele fehlt der Tab |
| About | System, Distribution, Version von hypr-shell, Hyprland und Quickshell |

Systemwerte werden nur abgefragt, solange das Dashboard offen ist.

**Gaming-Modus automatisch:** Läuft ein Spiel im Vollbild (Steam-Spiele, gamescope; weitere über
`games.auto_classes`), schaltet hypr-shell Blur, Animationen und Schatten aus und danach wieder an. Ein
von Hand eingeschalteter Gaming-Modus bleibt, wie er ist; abschalten mit `shell-set games.auto_gaming false`.
Wird das Spiel geschlossen, geht der automatische Modus aus, auch wenn Hyprland das Fenster beim
Schliessen anders meldet – solange kein anderes Spiel im Vollbild läuft.

### Starter

`SUPER + R` (oder `SUPER + Space`, `ALT + Space`, Rechtsklick auf das Distro-Symbol links in der Leiste) öffnet in der
Mitte ein Suchfeld im Glas-Look: Tippen sucht Apps nach Name, Beschreibung und Stichworten, zuletzt
benutzte stehen oben; Pfeiltasten wählen, Enter startet, Esc schliesst. Beginnt die Eingabe mit `=`,
wird gerechnet (`=12*8` zeigt 96, auch `^`, `%`, Klammern, `sqrt()`, `pi`); Enter kopiert das Ergebnis.
Wer lieber rofi oder einen anderen Starter will: `shell-set apps.launcher "rofi -show drun"`
(zurück mit `shell-set apps.launcher builtin`).

### App-Raster

Alle Apps auf einen Blick, wie ein Start-Menü oder Launchpad: **`SUPER` allein antippen** (drücken und
loslassen), der **Knopf links im Dock** oder ein **Klick auf das Distro-Symbol** in der Leiste öffnet in
der Mitte ein Glas-Raster mit allen Apps. Oben stehen ein Suchfeld (einfach lostippen), die Kategorien
(Internet, Office, Media, Games, …), darunter die **Favoriten** und die **zuletzt benutzten** Apps, dann
alle Apps nach Namen. Pfeiltasten wählen, Enter startet, Esc schliesst; nach dem Start ist das Raster zu
und die Tastatur wieder frei. **Rechtsklick** (oder Menü-Taste) auf eine App: im Dock anheften/lösen,
Favorit an/aus, neues Fenster; Mittelklick öffnet ein neues Fenster.

`SUPER` mit einer anderen Taste (`SUPER + E`, `SUPER + Q`, …) wirkt wie bisher, das Raster geht dabei
nicht auf. Einstellungen unter System → App grid: `appraster.enabled`, `appraster.super_tippen`
(SUPER antippen an/aus), `appraster.dock_knopf`, `appraster.kategorien`, `appraster.zuletzt` (wie viele
zuletzt benutzte, 0 = keine) und `appraster.favoriten` (Liste der `.desktop`-Namen). Zuletzt benutzt
teilt sich das Raster mit dem Starter. Als eigenes Leisten-Modul gibt es zusätzlich `apps`
(z. B. `shell-set bar.modules.left '["apps","workspaces","media"]'`).

### Benachrichtigungen

Benachrichtigungen erscheinen oben rechts als Glas-Karten mit Symbol, Titel, Text und Knöpfen. Nach
`notifications.timeout` Sekunden (Standard 6) verschwinden sie, dringende bleiben, bis man sie schliesst.
Alle landen im Verlauf: `SUPER + N` oder ein Klick auf die Glocke in der Leiste (mit Zähler) öffnet ihn –
nach App gruppiert, einzeln, je App oder mit **Clear all** löschbar, oben der Schalter **Do not
disturb** (auch Rechtsklick auf die Glocke oder `shell-toggle dnd`). Mit Nicht stören erscheinen keine
Karten, der Verlauf füllt sich trotzdem. hypr-shell ist dabei selbst der Benachrichtigungsdienst
(swaync wird nicht mehr gestartet); mit `shell-set notifications.enabled false` lässt sich ein anderer
Dienst verwenden.

### Lautstärke-Anzeige und Power-Menü

Lautstärke-, Stumm-, Mikrofon- und Helligkeitstasten (auch die Tastaturbeleuchtung) zeigen unten in der
Mitte eine kleine Glas-Pille mit Symbol und Balken, die nach 1,5 Sekunden verschwindet (`shell-osd`;
abschalten mit `shell-set osd.enabled false`). Das Power-Menü (`SUPER + Escape` oder ⏻ in der Leiste)
zeigt in der Mitte fünf grosse Knöpfe: **Lock**, **Sleep**, **Logout**, **Restart**, **Shutdown**.
Pfeiltasten wählen, Enter löst aus, Esc schliesst; Restart und Shutdown verlangen einen zweiten Druck.

### Fenster-Übersicht

`SUPER + Tab` zeigt alle Arbeitsflächen als Raster mit ihren Fenstern an der richtigen Stelle – mit
Vorschaubild, sonst App-Symbol und Titel. Klick wechselt zum Fenster, Ziehen auf eine andere
Arbeitsfläche verschiebt es dorthin, Tippen filtert nach Titel (Enter springt zum ersten Treffer).

### Zwischenablage

`SUPER + SHIFT + V` zeigt die letzten Kopien (Text und Bilder, aufgezeichnet mit cliphist ab der
Anmeldung): Suchfeld oben, Bilder mit Vorschau. Pfeiltasten wählen, **Enter** fügt den Eintrag im
vorigen Fenster ein, **Entf** löscht ihn, **Clear all** leert den Verlauf. Wie viele Einträge bleiben,
steht in `clipboard.max` (Standard 50); `shell-set clipboard.enabled false` schaltet die Aufzeichnung ab.

### Hot-Corner-Panel

Wächst aus der Ecke unten rechts: Begrüssung mit Uhrzeit, **Keep Awake** (kein Sperren,
kein Standby), **Apps** mit Suche, **Now playing**, **Screenshot** (Screen, Region,
Ordner; gespeichert und in der Zwischenablage) und **Quick Toggles**: WLAN, Bluetooth, Ton (stumm),
Nicht stören, Gaming-Modus (Blur, Animationen und Schatten aus), **Leistungsprofil** (ein Klick
schaltet weiter: Power saver → Balanced → Performance), **Nachtlicht** (hyprsunset, Wärme in
`nightlight.temperature`, Zeitplan mit `nightlight.schedule`, `nightlight.from`, `nightlight.to`) und
Einstellungen (öffnet die Einstellungs-App). Schalter, die der Rechner nicht hat (kein WLAN, kein
Bluetooth-Adapter, kein hyprsunset …), fehlen einfach.

WLAN, Bluetooth und Ton haben einen kleinen Pfeil (oder Rechtsklick): er öffnet im Panel eine
**Unterseite** mit Zurück-Pfeil – WLAN: Netze mit Stärke, verbinden (mit Passwortfeld), trennen;
Bluetooth: gekoppelte und neue Geräte mit Akkustand, suchen, koppeln, verbinden; Ton: Ausgabe- und
Eingabegerät wählen (wirkt sofort) und Lautstärke je App. Ein Klick auf das WLAN-, Bluetooth- oder
Ton-Symbol in der Leiste öffnet direkt die passende Unterseite (Rechtsklick auf den Ton: stumm).

![Panel](docs/screenshots/panel.png)

### Dock

![Dock](docs/screenshots/dock.png)

Ein schwebendes Glas-Dock mittig unten mit angehefteten und laufenden Programmen: Klick startet
oder holt das Fenster nach vorn, Punkte zeigen laufende Programme. Rechtsklick öffnet ein Menü,
Ziehen sortiert um, Herausziehen löst an, `SUPER + B` bedient das Dock mit der Tastatur. Abschaltbar mit
`shell-set dock.enabled false`. Jeder Wert ist in der Einstellungs-App (Seite **Dock**, mit
fünf Voreinstellungen, Export und Import) einstellbar. Es weicht der Leiste aus, verschwindet bei
Vollbild und Spielen und färbt sich mit dem Hintergrundbild. Alle Werte stehen in
[docs/dock.md](docs/dock.md).

### Sperrbildschirm

Bildschirm unscharf und abgedunkelt, links Profilbild über der grossen Uhr, Datum,
Begrüssung, Passwort als Linie und Knöpfe für Standby, Neustart und Herunterfahren; unten
links CPU- und RAM-Auslastung. hypridle sperrt
nach 5 Minuten und geht nach 15 Minuten in den Standby (vorher wird gesperrt); die Zeiten stehen
in `lock.after`, `lock.screen_off` und `lock.suspend`.

![Sperrbildschirm](docs/screenshots/lockscreen.png)

### Fenster andocken und Fenster-Modus

Fenster sind jetzt standardmässig **frei verschiebbar** wie bei Windows und macOS: neue Fenster
öffnen schwebend und mittig (`fenster.modus = schwebend`; `kacheln` = automatisch gekachelt wie
bisher, umschalten mit `SUPER + SHIFT + T` – wirkt sofort, auch auf offene Fenster). Ein Fenster mit
`SUPER` + linker Maustaste an den **oberen Rand** ziehen: maximiert zwischen Leiste und Dock; an den
**linken oder rechten Rand**: halbe Breite; in eine **Ecke**: ein Viertel. Beim Ziehen zeigt eine
Glas-Fläche vorher, wo es landet; Wegziehen bringt die alte Grösse zurück. Zwischen zwei
Bildschirmen wird nicht angedockt (das Fenster wechselt den Bildschirm). Per Tastatur:
`SUPER + Pfeile` (siehe Tastenkürzel). Einstellungen → Look → Snapping (`andocken.*`: an/aus,
Randabstand 8 px, Ecken 60 px, Vorschau, Animation). Im Kacheln-Modus wird ein Fenster beim
Andocken schwebend. Hinweis: Ziehen an der Titelleiste (hyprbars) startet das Plugin selbst und dockt
noch nicht an – dafür `SUPER` + Ziehen oder die Tastatur.

### Fenster wechseln (ALT + Tab)

ALT gedrückt halten und Tab drücken: In der Mitte des Bildschirms mit dem Mauszeiger erscheint eine
Glas-Leiste mit Vorschaubildern aller offenen Fenster – zuletzt benutzte zuerst, ein kurzes
ALT + Tab springt also zum vorherigen Fenster. Weiter Tab (oder Pfeile, Maus) wählt, ALT loslassen
wechselt, Escape bricht ab, Q oder Entf schliesst das gewählte Fenster. Fenster anderer
Arbeitsflächen und Bildschirme tragen eine kleine Nummer, minimierte den Hinweis „minimized“ –
Wechseln holt die Arbeitsfläche bzw. das Fenster zurück. Die Tasten laufen über eine Submap von
Hyprland; die Leiste nimmt nie die Tastatur und schliesst sich nach 5 s ohne Taste von selbst.
Einstellungen → System → Window switcher (`switcher.*`: an/aus, alle Fenster oder nur die
Arbeitsfläche, Vorschau an/aus, Grösse); `SUPER + Tab` (Übersicht) bleibt.

### Fenster-Knöpfe

Jedes normale Fenster hat oben eine schmale Glas-Titelleiste mit Titel und drei Knöpfen:
**Minimieren**, **Maximieren/Wiederherstellen** und **Schliessen** – im Windows-Stil rechts
(Standard) oder als rote, gelbe und grüne Punkte links im macOS-Stil (`fenster.knoepfe.stil`,
`fenster.knoepfe.seite`; wirkt sofort). Doppelklick auf die Leiste maximiert, Ziehen verschiebt.
Maximieren füllt die Fläche zwischen Leiste und Dock (kein echtes Vollbild; `SUPER + F` bleibt
Vollbild). Minimierte Fenster verschwinden, liegen abgedunkelt im Dock und kommen per Klick an ihre
alte Stelle auf der aktuellen Arbeitsfläche zurück (`SUPER + M` / `SUPER + SHIFT + M`,
`shell-window minimize|restore`). Programme mit eigener Titelleiste (GNOME-Programme wie der
Dateimanager, Browser) bekommen keine zweite – ihre eigenen Knöpfe zeigen dieselben drei Knöpfe auf
derselben Seite, ihr Minimieren geht ebenfalls ins Dock. Keine Titelleiste bei Vollbild, Dialogen,
Spielen und Videos (`fenster.titelleiste_ausnahmen`; `fenster.titelleiste` = an | aus |
nur-schwebend). Die Titelleiste kommt vom offiziellen Plugin **hyprbars**; der Installer richtet es
ein (Paket, sonst `hyprpm`), beim Start lädt `shell-window titlebar` es. Fehlt es (z. B. nach einem
Hyprland-Update), läuft alles ohne Knöpfe weiter und eine Meldung nennt die Lösung
(`hyprpm update && hyprpm enable hyprbars`).

### Glas-Look

Alles sieht aus wie mattes Glas, ohne Einstellen wie in der Vorlage: Leiste, Dock, alle Panels,
Menüs, Benachrichtigungen, Starter und Einstellungs-App sind grau und durchsichtig mit starkem
Blur dahinter, mit einem hellen, leicht leuchtenden Rand (2 px) und stark gerundeten Ecken
(26 px, Karten 16 px); Karten sind spürbar heller als das Glas, es gibt viel Abstand innen und
fette Überschriften. Die Programmfenster haben denselben hellen, leuchtenden Rand, 18 px Rundung
und sind leicht durchsichtig (aktiv 0.95, inaktiv 0.88). Spiele, Videos, Bildbearbeitung und Vollbild
bleiben undurchsichtig (`look.opacity.exceptions`). Ist das Hintergrundbild hell, wird das Glas von
selbst so weit dunkler, dass Text lesbar bleibt. Alle Werte stehen unter Einstellungen → Theme
(Glas, Rand) und Look (Fenster) mit Live-Vorschau; drei Voreinstellungen: **glass** (Standard),
**minimal** (ruhig, fast undurchsichtig) und **gaming** (kein Blur, keine Schatten, keine
Animationen) – auch mit `shell-look preset gaming`. Die Leiste schwebt mit Abstand zum Rand
(`bar.floating`), das Dock nimmt standardmässig dasselbe Glas (`dock.color_mode = glass`).

> **Von 1.10 auf 1.11:** Der neue Standard-Look gilt sofort für alle Werte, die nicht selbst
> gesetzt sind. Wer früher die Voreinstellung **glass** angeklickt hat, hat die alten Zahlen in
> settings.json stehen; sie werden nie automatisch überschrieben. Für den neuen Look
> Einstellungen → Look → Preset → **Glass** neu anklicken oder:
>
> ```bash
> shell-set reset theme
> ```
>
> ```bash
> shell-set reset look
> ```

Auch die Feinheiten sind Einstellungen (Theme → Cards, Spacing, Fonts, Glass), mit Live-Vorschau
auf den Seiten Look und Theme und „Reset“ je Wert:
- **Karten** (`theme.card.*`): Farbe, Helligkeit, Helligkeit beim Überfahren und Kontur der Karten
  in Panels, Dashboard und Einstellungen; auch Text auf Karten bleibt lesbar (Kontrast 4.5:1).
- **Leuchtender Rand** (`theme.border.glow`, `glow_size`, `glow_opacity`): weicher Schein in
  Randfarbe um Panels, Karten, Dock und Fenster; Spiele, Videos, Bildbearbeitung und Vollbild
  leuchten nie.
- **Abstände** (`theme.spacing.*`): ein Faktor für alle Abstände, dazu Innenabstand der Glasflächen
  und Karten und die Lücke zwischen Karten.
- **Schrift** (`theme.font.title_weight`, `text_weight`, `title_scale`): Dicke von Titeln und Text,
  Grösse der Überschriften; **aktive Pille** (`theme.pill.opacity`).

```bash
shell-set theme.card.opacity 0.15
```

```bash
shell-set theme.border.glow true
```

### Farben und Hintergrundbild

Eigene Bilder nach `~/Pictures/Wallpapers` legen und im Dashboard (SUPER + W) anklicken
oder `shell-wallpaper <bild>` aufrufen. matugen erzeugt daraus die Farben für Hyprland,
Waybar, kitty, rofi, hyprlock und Quickshell; bei einem grauen Bild bleibt alles
grau/weiss. Mitgeliefert sind ein dunkles Blütenfoto (Standard, damit das Glas wie in der Vorlage
wirkt; CC0, siehe NOTICE) und ein schlichtes graues Verlaufsbild. Beide geben grau-weisse Farben.
Ohne eigene Auswahl entscheidet `theme.wallpaper_default` (`bluete` oder `grau`); eine eigene
Auswahl bleibt, `shell-wallpaper --standard` vergisst sie wieder.

![Farben aus einem bunten Bild](docs/screenshots/farben-aus-bild.png)

**Programme mitfärben** (Einstellungs-App → Theme → Apps, `theme.apps.*`): GTK-Programme
wie Nautilus und Dialoge sowie Qt-Programme (über qt6ct/qt5ct) übernehmen die Farben
standardmässig mit; Firefox, Discord (Vesktop) und Spotify (spicetify) lassen sich einzeln
einschalten und erscheinen nur, wenn sie installiert sind. Jede Datei, die dafür geändert
wird (`gtk.css`, `qt6ct.conf`, `userChrome.css`, `user.js`, Vesktop-Einstellungen,
`config-xpui.ini`), wird vorher gesichert; Ausschalten legt die Sicherung genau so zurück.
Offene GTK-4-Fenster und Firefox zeigen die neuen Farben nach dem nächsten Öffnen.

Ein Profilbild wird aus `~/.face` gelesen (quadratisches Bild, z. B. PNG). Fehlt es, steht
im Dashboard, im Panel und auf dem Sperrbildschirm der Anfangsbuchstabe des Benutzers in
einem Kreis (für den Sperrbildschirm erzeugt der Installer dafür ein Ersatzbild).
App-Symbole kommen aus Papirus-Dark, dann aus hicolor, dann aus dem Pfad in der
`.desktop`-Datei; erst wenn nichts davon passt, erscheint ein Platzhalter.

## Anpassen

Alles Einstellbare steht in **einer** Datei: `~/.config/hypr-shell/settings.json`. Drei Wege führen
dorthin – alle schreiben in dieselbe Datei, und jede Änderung wirkt sofort, ohne Abmelden:

1. **Einstellungs-App** – `SUPER + U` (oder das Zahnrad im Panel): Schalter, Regler, Listen, Suche,
   Reset und Undo, dazu Profile und Export/Import.
2. **Befehl** – `shell-set look.rounding 20` ändert einen Wert, `shell-set undo` nimmt ihn zurück,
   `shell-set list` zeigt alle Werte mit Standard und Erklärung.
3. **Datei** – `settings.json` im Editor öffnen; fehlende Werte haben ihren Standard. Ein falscher
   Wert wird gemeldet und durch den Standard ersetzt, bei kaputtem JSON bleibt der letzte gültige
   Stand aktiv.

![Einstellungs-App](docs/screenshots/settings-look.png)

**Jeder Wert** mit Standard, erlaubten Werten, Erklärung und `shell-set`-Beispiel steht in
[docs/einstellungen.md](docs/einstellungen.md) (aus [`settings/schema.json`](settings/schema.json)
erzeugt). Eigene Hyprland-Zeilen (Fensterregeln usw.) gehören nach `~/.config/hypr/user.lua` – diese
Datei überschreibt der Installer nie, und sie gilt zuletzt.

### Mit der Einstellungs-App

Links stehen die Seiten Home, Bar, Look, Theme, Desktop, Dashboard, Panel, System, Integrations, Laptop (nur auf Laptops mit asusctl, supergfxctl oder power-profiles-daemon), Lock & Idle, Input,
Monitors, Apps, Keybinds und About; rechts jeder Wert mit Erklärung und dem passenden Bedienelement.
Ein Regler wirkt schon beim Ziehen. Neben einem geänderten Wert steht **Reset**, oben auf jeder Seite
**Reset page**, ganz oben **Undo** und **Redo**; die Suche findet Werte über Titel, Erklärung und
Schlüssel (z. B. „blur“, „clock“, „battery“) und springt zur Zeile. Auf **Monitors** stehen die echten
Bildschirme aus Hyprland; eine neue Auflösung oder Drehung muss innerhalb von 15 Sekunden bestätigt
werden, sonst gilt wieder die alte. **About** öffnet `settings.json` und diese Übersicht.

Die Startseite **Home** ist luftig wie die Vorlage: grosses Profilbild, „Good evening, <name>“,
Datum und Uhrzeit, Pillen mit Farbmodus, Laufzeit und Distro, ein Tipp, der bei jedem Öffnen
wechselt (das × schaltet die Tipps ab, `settings.home.tips`), und Kacheln unter „Make it yours“
zu Theme, Wallpaper (Tab im Dashboard), Notifications, Lock screen, Bar und Launcher. **Profile,
Export und Import** stehen jetzt unter **System → Backup**. In der Seitenleiste ist die offene
Seite eine hellere graue Pille mit fetter Schrift (`theme.pill.nav = white` gibt die weisse Pille
zurück). Weitere Seiten:
[Home](docs/screenshots/settings-home.png), [Bar](docs/screenshots/settings-bar.png),
[Theme](docs/screenshots/settings-theme.png), [Monitors](docs/screenshots/settings-monitors.png),
[Keybinds](docs/screenshots/settings-keybinds.png), [Suche](docs/screenshots/settings-suche.png).

### Mit dem Befehl `shell-set`

| Befehl | Wirkung |
| --- | --- |
| `shell-set list [bereich]` | alle Werte (oder z. B. nur `look`) mit aktuellem Wert, Standard und Erklärung; `*` = geändert |
| `shell-set get <schlüssel>` | aktueller Wert |
| `shell-set <schlüssel> <wert>` | setzen; Listen als `a,b,c` oder JSON, Schalter als `true`/`false` oder `on`/`off`; ein falscher Wert nennt den erlaubten Bereich und ändert nichts |
| `shell-set set <s1> <w1> <s2> <w2> …` | mehrere Werte in einem Schritt |
| `shell-set reset <schlüssel\|bereich\|all>` | auf den Standard zurück |
| `shell-set undo` / `shell-set redo` | letzte Änderung zurücknehmen / wiederholen (die letzten 20 Schritte) |
| `shell-set profile save\|load\|list\|delete <name>` | Profile in `~/.config/hypr-shell/profiles/` |
| `shell-set export <datei>` / `shell-set import <datei>` | sichern / laden (ein Import wird vorher geprüft) |

Die Tab-Taste vervollständigt in bash und fish Befehle, Schlüssel und erlaubte Werte. Werte aus der
alten `~/.config/hypr/hypr-shell-local.lua` (Version 1.1) wandern beim ersten Start einmalig in
`settings.json`; eine `settings.json` aus Version 1.0 oder 1.1 funktioniert unverändert.

## Anbindungen (Nextcloud, Missa, Homelab, Kalender, Sensor)

Alle persönlichen Anbindungen sind nach der Installation **aus** – wer hypr-shell ohne Nextcloud, Missa
oder Homelab benutzt, sieht nichts davon. Einschalten in der Einstellungs-App auf der Seite
**Integrations** (Schalter, Statuspunkt, Felder; Passwörter landen nur in
`~/.config/hypr-shell/secrets.env`). Nextcloud erscheint dann als Ordner `~/Nextcloud`, Missa als
`~/Missa` mit `Eingang/` und `Ausgabe/`, beide mit Lesezeichen in der Seitenleiste des Dateimanagers.
Alles Weitere steht in [docs/anbindungen.md](docs/anbindungen.md).

Mit `calendar.enabled` (CalDAV, z. B. Nextcloud) bekommt der Kalender im Dashboard Punkte an Tagen
mit Terminen und darunter die nächsten drei Termine; mit `sensor.enabled` zeigt die Wetter-Kachel
rechts einen Messwert aus einer JSON-Adresse (Feld, Titel, Einheit, ab `sensor.warn` in Warnfarbe).
Alles wird nur bei offenem Dashboard geholt (3 s Zeitlimit, Zwischenspeicher); ist ein Server nicht
erreichbar, steht ruhig „not reachable“ mit dem letzten Stand.

**Missa-Chat** (mit `missa.enabled`): `SUPER + I` öffnet von der rechten Kante ein Chatfenster. Enter
sendet, SHIFT+Enter macht eine neue Zeile; Missas Antwort läuft Wort für Wort ein („Missa is working …“,
während sie ein Werkzeug benutzt), der Knopf unten rechts bricht ab. Stellt Missa eine Rückfrage,
erscheinen **Yes** und **No**. Dateien lassen sich ins Eingabefeld ziehen (der Pfad geht mit), Dateien
aus `~/Missa/Eingang` stehen als Knöpfe darüber. Die Sitzung heisst `hypr-shell-<Rechnername>` und läuft
nach einem Neustart weiter. Im Dashboard zeigt die Karte **Missa** die Kurzfassung des Lagebilds und die
nächsten Erinnerungen; ein Klick öffnet den Chat.

**Mit Missa sprechen** (zusätzlich `missa.voice_enabled`): `SUPER + SHIFT + I` nimmt auf, bis man
nochmal drückt oder zwei Sekunden still ist; unten zeigt eine Glas-Pille den Pegel und „Listening“,
„Thinking“, „Speaking“, in der Leiste steht ein Mikrofon. whisper.cpp erkennt den Satz lokal (Sprache
`missa.voice_language`, Standard Deutsch), er erscheint im Chat und geht an Missa; ihre Antwort liest
piper Satz für Satz vor (Stimme `missa.voice_voice`, Tempo `missa.voice_speed`). Esc, ein Klick auf die
Pille oder die Taste stoppt. Aufgenommen wird nur nach Tastendruck, nichts wird gespeichert. Der
Installer fragt, ob whisper.cpp, piper und die Modelle (etwa 250 MB) geholt werden sollen; ohne sie
fehlen Taste und Mikrofon-Knopf.

**Missa bedient den Rechner** (zusätzlich `missa.agent_enabled` und ein Geräte-Token): Der Missa-Agent
(`shell-missa-agent`, Benutzerdienst) verbindet sich ausgehend mit Missa-Core – am Rechner wird kein
Port geöffnet – und bietet Missa 16 Werkzeuge: Dateien suchen, lesen und öffnen, Fenster und Medien
steuern, Benachrichtigungen, Panels und Einstellungen, Dateien anlegen (nie überschreiben), und nach
Rückfrage Befehle, Dateien ändern (Papierkorb statt löschen), Programme beenden, Energie. Die
**Zugriffsstufe** `missa.access`: `read` (nur lesen), `ask` (Standard: Schreiben frei, Zerstörerisches
erst nach Klick auf einer Glas-Karte, die den Befehl wörtlich zeigt – Enter erlaubt, Esc lehnt ab, nach
60 s abgelehnt), `full` (ohne lokale Rückfrage). In jeder Stufe gilt: gesperrte Ordner
(`missa.blocked_paths`, z. B. `~/.ssh`, Schlüsselbund, Browser-Profile, `secrets.env`), nie als root,
bei gesperrtem Bildschirm nur Lesendes, Ausgaben höchstens 20 000 Zeichen. Solange der Agent verbunden
ist, steht ein Symbol in der Leiste (es pulsiert während einer Aktion); der Schalter **Missa access** im
Panel trennt sofort. Jede Aktion steht im Chat (Knopf 󰋚) und in
`~/.local/share/hypr-shell/missa-actions.log`; Erinnerungen und Alarme von Missa erscheinen als
Benachrichtigung (Notfälle bleiben stehen).

## Laptop

Auf ASUS-ROG-Laptops (z. B. Zephyrus M16) steuert hypr-shell über `asusctl` und `supergfxctl`
(installiert der Installer nicht selbst, er schlägt sie nur vor):

- **Leistungsprofil** – Schalter im Panel (Quiet → Balanced → Performance, über asusctl; ohne
  asusctl über power-profiles-daemon) und auf der Seite **Laptop** der Einstellungs-App.
- **Grafik-Modus** – Seite Laptop: Integrated, Hybrid, AsusMuxDgpu … mit Bestätigung, danach ab- oder
  neu anmelden.
- **Ladegrenze** – `laptop.charge_limit` (z. B. 80 %); asusd behält sie über Neustarts, hypr-shell setzt
  sie beim Anmelden noch einmal. Zurück auf 100 (oder Reset) stellt auch asusd wieder auf 100; eine nur mit
  asusctl gesetzte Grenze bleibt unberührt.
- **Tastaturlicht** – `laptop.kbd_light` (off/low/med/high) und `laptop.kbd_follow_wallpaper` (Farbe folgt
  dem Hintergrundbild).

Die Seite Laptop und jede Zeile darauf erscheinen nur, wenn der Rechner die Funktion hat; ohne
asusctl taucht nichts davon auf. Befehl: `shell-laptop status`.

Für Laptops sind vor allem diese Werte gedacht: `monitors.scale` (Skalierung, `"auto"` oder eine
Zahl wie `"1.5"`), `input.touchpad.natural_scroll` und `input.touchpad.tap_to_click`. Ein Bildschirm
lässt sich auch einzeln einstellen:

```json
{
  "monitors": {
    "scale": "auto",
    "outputs": [ { "name": "eDP-1", "resolution": "2560x1600", "refresh": 165, "scale": "1.6" } ]
  },
  "input": { "touchpad": { "natural_scroll": true } }
}
```

XWayland-Programme wie Steam, Battle.net oder GOG-Spiele werden bei einer Skalierung über 1
nicht hochgerechnet (`xwayland.force_zero_scaling`): Sie bleiben scharf, erscheinen dafür in
ihrer eigenen Grösse. Ein Akku erscheint in der Leiste rechts vor der Uhr (Symbol und Prozent,
unter 15 % in Warnfarbe, beim Laden mit Blitz) – nur, wenn der Rechner einen Akku hat
(abschalten mit `bar.battery`).

## Bildschirme

Leiste, Dock, Desktop-Widgets und alle Panels richten sich nach dem Bildschirm, auf dem sie
erscheinen – bei mehreren Bildschirmen jedes nach seinem eigenen. Gerechnet wird in der Grösse nach
der Skalierung von Hyprland (2560×1600 mit Skalierung 1.6 sind also 1600×1000):

- **Grösse:** Zwischen 1080 und 1440 Pixeln kürzerer Seite sieht alles aus wie entworfen. Darunter
  (bis 1280×720) wird die Oberfläche etwas kleiner (höchstens auf 85 %), darüber grösser (4K mit
  Skalierung 1: anderthalbmal, höchstens doppelt) – nichts wird winzig.
- **Platz:** Kein Panel ragt über den Bildschirm, über die Leiste oder über ein Dock mit
  `dock.mode = reserve`. Was nicht in die Höhe passt, lässt sich rollen statt abgeschnitten zu werden.
- **Hochformat:** Das Dashboard ordnet seine Karten in 6 statt 12 Spalten, die Einstellungs-App
  zeigt die Seiten oben statt links, der Spickzettel und die Fenster-Übersicht nehmen weniger Spalten,
  das Power-Menü bricht in Reihen um.
- **Widgets:** Die Lage bleibt ein Anteil des Bildschirms; nach einem Wechsel von Auflösung oder
  Ausrichtung ragt ein Widget nie über den Rand (es wird begrenzt, die gespeicherte Lage bleibt).
- **Ohne Neustart:** Ändern sich Auflösung, Skalierung oder Ausrichtung, ordnet sich alles sofort neu.
  Ist der unter Desktop → Screen eingestellte Bildschirm abgesteckt, erscheint alles auf dem ersten.

Die Schrift der Leiste wird nie grösser, als die Leiste hoch ist (`bar.height`); Sperr- und
Login-Bildschirm passen ab 1280×720.

### Bildschirm drehen

Einstellungen → **Monitors** → Zeile **Rotation**: 0°, 90°, 180° oder 270°, dazu der Schalter
**Mirrored**; die kleine Kachel zeigt, wie der Bildschirm steht. Wie bei der Auflösung muss die
Drehung innerhalb von 15 Sekunden mit **Keep** bestätigt werden, sonst springt sie zurück. Auf der
Befehlszeile:

```bash
shell-set monitor eDP-1 rotate 90
```

```bash
shell-set monitor eDP-1 mirror on
```

Ungültige Werte (z. B. `rotate 45`) werden mit einer Meldung abgelehnt. Ein Touchscreen oder Stift
dreht mit dem eingebauten Bildschirm mit (gibt es keinen, ändert sich nichts). Ist die Lage eines
Bildschirms von Hand eingetragen und überlappen sich danach zwei, weist die Seite darauf hin;
automatische Lagen ordnet Hyprland selbst neu. Alte Einträge ohne Drehung gelten als `normal`.

## Hilfsprogramme

| Befehl | Wirkung |
| --- | --- |
| `shell-set …` | Einstellungen lesen, ändern, zurücksetzen, rückgängig machen, Profile (siehe „Anpassen“) |
| `shell-apply` | Einstellungen prüfen und anwenden (`--check` nur prüfen) |
| `shell-wallpaper <bild>` | Hintergrundbild setzen und Farben erzeugen (Farbmodus aus `theme.colors`) |
| `shell-appcolors sync\|apply\|restore\|status` | Programme mitfärben (GTK, Qt, Firefox, Vesktop, Spotify) bzw. Sicherungen zurücklegen |
| `shell-screenshot region\|screen\|folder` | Screenshot bzw. Ordner öffnen |
| `shell-toggle <wifi\|bluetooth\|audio\|dnd\|gaming\|awake\|nightlight> [on\|off]` | Schnellschalter, `shell-toggle profile` schaltet das Leistungsprofil weiter, `shell-toggle status` zeigt alle |
| `shell-games list\|launch <id>` | Spiele für den Tab Games |
| `shell-laptop status\|profile\|gfx\|charge\|kbd …` | Laptop-Funktionen (asusctl, supergfxctl, power-profiles-daemon) |
| `shell-fetch lab\|calendar\|sensor` | Abruf für Lab, Kalender und Sensor (nur eingeschaltet) |
| `shell-missa-agent sync\|pause\|resume\|status` | Missa-Agent (Geräte-Anschluss v1) |
| `shell-voice available\|listen\|speak\|stop` | mit Missa sprechen (Aufnahme, whisper.cpp, piper) |
| `shell-missa health\|chat\|get …` | Verbindung zu Missa-Core (Chat, Status, Lagebild) |
| `shell-mount nextcloud\|missa up\|down\|status` | Ordner der Anbindungen einhängen / aufräumen |
| `shell-secrets set\|has\|unset <NAME>` | Zugangsdaten in `secrets.env` (Wert über stdin) |
| `shell-net wifi\|bt …` | WLAN und Bluetooth für die Unterseiten im Panel |
| `shell-quickshell restart` | Oberfläche neu starten |
| `shell-snap key <richtung>\|modus [schwebend\|kacheln\|toggle]` | Andocken per Tastatur, Fenster-Modus |
| `shell-switcher next\|prev\|commit\|cancel\|close` | ALT + Tab (von den Kürzeln aufgerufen) |
| `shell-window minimize\|restore\|list` | Fenster minimieren, zurückholen, minimierte zeigen |
| `shell-look presets\|preset <name>` | Voreinstellungen für das Aussehen: glass, minimal, gaming |
| `shell-diag tastatur\|dock\|freigeben` | wer hat die Tastatur? · warum ist das Dock (auf welchem Bildschirm) weg – Vollbild, Gaming-Modus, veraltete Meldung von Hyprland? · Tastatur zurück (wie `CTRL + SUPER + Escape`) |
| `shell-waechter <name> -- <befehl>` | hält Leiste und Oberfläche am Laufen: nach einem Absturz Neustart (höchstens 5-mal in 2 Minuten, dann Benachrichtigung); `shell-waechter stop <name>` beendet ohne Neustart |
| `shell-powermenu [aktion]` | Power-Menü bzw. direkt `lock`, `suspend`, `logout`, `reboot`, `shutdown` |
| `shell-clipboard list\|paste\|delete\|clear …` | Verlauf der Zwischenablage |
| `shell-osd volume\|mic\|brightness\|kbd …` | Lautstärke/Helligkeit ändern und anzeigen |

## Aufbau

| Ordner | Inhalt |
| --- | --- |
| `config/` | Dotfiles, die nach `~/.config` kopiert werden |
| `quickshell/` | QML-Oberfläche: `desktop/`, `dashboard/`, `panel/`, `settings/` (Einstellungs-App), `common/` |
| `bin/` | Hilfsskripte für `~/.local/bin` |
| `wallpapers/` | mitgelieferte Hintergrundbilder |
| `sddm/` | Anmeldebildschirm (SDDM-Thema), nur mit `./install.sh --login-theme` |
| `settings/` | `schema.json` (Beschreibung aller Werte) und `settings.example.json` (Standardwerte) |
| `tests/` | Prüfskripte (`tests/lint.sh`, `tests/probeinstallation.sh`, …) |
| `docs/` | Doku: [einstellungen.md](docs/einstellungen.md) (alle Werte, aus dem Schema erzeugt), [anbindungen.md](docs/anbindungen.md), [dock.md](docs/dock.md), [tastenkuerzel.md](docs/tastenkuerzel.md), [abnahme.md](docs/abnahme.md), Screenshots |

Die Screenshots stammen aus dem Oberflächentest der CI (unsichtbarer Compositor,
Software-Rendering): Sie zeigen Aufbau und Masse, aber **ohne Blur**. Ohne Grafikkarte
haben Profilbild, Cover und Vorschaubilder dort eckige statt runde Ecken.

## Projektstand

Version: **1.12.1** (siehe [`VERSION`](VERSION)). Änderungen stehen in [CHANGELOG.md](CHANGELOG.md).
Was nur auf dem echten Rechner geprüft werden kann, steht in [docs/abnahme.md](docs/abnahme.md).
Optik und Aufbau sind an „DarkShadow's Shell“ (MIT) angelehnt; der Code ist neu geschrieben,
übernommene Masse und Formen sind in [NOTICE](NOTICE) vermerkt.
Die mitgelieferte Schrift Bebas Neue steht unter der SIL Open Font License
(`quickshell/common/fonts/OFL.txt`).
