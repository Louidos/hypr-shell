# Anbindungen

Persönliche Anbindungen von hypr-shell – **alle sind nach der Installation aus**. Solange eine aus ist,
läuft kein Dienst, es gibt keinen Netzverkehr, keinen Ordner, kein Lesezeichen, keinen Schalter im Panel,
keinen Tab oder keine Kachel im Dashboard und keine Zeile im Kürzel-Spickzettel; das zugehörige Kürzel
tut still nichts.

Einschalten: Einstellungs-App → **Integrations** (oder `shell-set nextcloud.enabled true`). Wer alles
will, lädt das Beispielprofil: `shell-set import settings/anbindungen.example.json` und trägt danach
Adressen und Benutzer ein.

| Schalter | Standard | Wirkung, wenn an | Was man selbst eintragen muss |
| --- | --- | --- | --- |
| `nextcloud.enabled` | aus | `~/Nextcloud` (WebDAV über rclone) mit Lesezeichen im Dateimanager | `nextcloud.url`, `nextcloud.user`, App-Passwort |
| `missa.enabled` | aus | Missa-Chat (SUPER+I), Missa-Karte im Dashboard, Ordner `~/Missa` mit `Eingang/` und `Ausgabe/` | `missa.url`, API-Schlüssel |
| `missa.agent_enabled` | aus | Missa darf diesen Rechner bedienen (braucht `missa.enabled`) | Geräte-Token |
| `missa.voice_enabled` | aus | mit Missa sprechen (SUPER+SHIFT+I, braucht `missa.enabled`) | – (whisper.cpp und piper) |
| `lab.enabled` | aus | Dashboard-Tab Lab (über Missa-Core, braucht `missa.enabled`) | – |
| `calendar.enabled` | aus | Termine im Kalender des Dashboards (CalDAV) | `calendar.url`, `calendar.user`, Passwort |
| `sensor.enabled` | aus | Sensor-Kachel im Dashboard | `sensor.url` |
| `games.custom_enabled` | aus | eigene Einträge im Tab Games | `games.custom` |

## Zugangsdaten

Passwörter, Schlüssel und Tokens stehen **nur** in `~/.config/hypr-shell/secrets.env` (Rechte 600, nur
für den Benutzer lesbar) – nie in `settings.json`, Profilen, Export, Logs oder im Repo. Eintragen über
die Seite Integrations (Feld neben der Anbindung) oder auf der Befehlszeile, der Wert kommt über stdin:

```bash
shell-secrets set NEXTCLOUD_APP_PASSWORD
```

Namen: `NEXTCLOUD_APP_PASSWORD`, `MISSA_API_KEY`, `MISSA_DEVICE_TOKEN`, `CALDAV_PASSWORD`, `SENSOR_TOKEN`.
Ausschalten lässt die Zugangsdaten stehen; entfernen nur ausdrücklich (Knopf **Remove**, zweimal
drücken) oder mit `shell-secrets unset <NAME>`.

## Nextcloud als Ordner

`shell-mount nextcloud up` bindet `<Adresse>/remote.php/dav/files/<Benutzer>/` mit rclone als normalen
Ordner ein (Standard `~/Nextcloud`, `nextcloud.mount_path`), über den Benutzerdienst
`shell-mount-nextcloud.service`. Das App-Passwort bekommt rclone nur über die Umgebung (verschleiert) –
nie in einer rclone-Konfiguration, einem Log oder der Prozessliste. Der Cache für geöffnete Dateien ist
begrenzt (`nextcloud.cache_mb`, Standard 1024 MB), `nextcloud.read_only` hängt nur lesend ein. Server
mit selbst signiertem Zertifikat: eigene CA-Datei in `integrations.ca_file` – die Prüfung wird nie
abgeschaltet. Ist der Server nicht erreichbar, bleibt der Ordner leer, der Dateimanager hängt nicht.

Ausschalten stoppt den Dienst, hängt den Ordner aus, entfernt das Lesezeichen und löscht den Ordner,
wenn er leer ist und von hypr-shell angelegt wurde. Fehlt rclone oder FUSE, steht in der Zeile ein
Hinweis mit dem Paketnamen (`rclone`, `fuse3`); installiert wird nichts ungefragt.

## Lesezeichen im Dateimanager

hypr-shell legt nur eigene Lesezeichen an („Nextcloud“, „Missa“) – in `~/.config/gtk-3.0/bookmarks` und
`~/.config/gtk-4.0/bookmarks` (Nautilus, Thunar, GTK-Dialoge) und, wenn Dolphin installiert ist, in
dessen Orteliste. Welche es angelegt hat, merkt es sich in `~/.local/share/hypr-shell/bookmarks.txt`;
nur diese werden wieder entfernt, fremde Lesezeichen bleiben unberührt.

## Missa-Chat

`SUPER + I` (nur mit `missa.enabled`) öffnet den Chat. hypr-shell schickt jede Nachricht an
`<missa.url>/v1/chat/completions` (Modell `missa`, Streaming) mit dem Header
`X-Missa-Session: hypr-shell-<Rechnername>` und nur die neue Nachricht – den Verlauf führt Missa-Core.
Der Statuspunkt kommt aus `GET /health`. Fehler stehen verständlich im Chat: falscher Schlüssel (401),
gesperrt nach zu vielen Fehlversuchen (429, mit Wartezeit), Sprachmodell nicht erreichbar (502/503), kein
Netz. **New conversation** leert die Anzeige; danach schickt hypr-shell seinen eigenen Verlauf mit
(einen System-Hinweis „Neues Gespräch“ und die Nachrichten seither), damit Missa-Core die ältere
Unterhaltung dieser Sitzung nicht wieder einfügt.

## Homelab, Kalender, Sensor

`shell-fetch` holt die Daten für das Dashboard – nur, wenn der Schalter an ist und das Dashboard offen
ist, mit 3 Sekunden Zeitlimit und 60 Sekunden Zwischenspeicher (`~/.cache/hypr-shell/fetch`, ohne
Zugangsdaten). Ist ein Server nicht erreichbar, bleibt der letzte Stand mit dem Zeitpunkt stehen.

- **Lab** (`lab.enabled`, braucht `missa.enabled`): liest über Missa-Core `GET /api/homelab`,
  `/api/server`, `/api/container` und `/api/alarme` (Proxmox ist vom Laptop aus nicht direkt erreichbar).
- **Kalender** (`calendar.enabled`): CalDAV-Abfrage (`REPORT`, heute bis +30 Tage) an `calendar.url`
  mit `calendar.user` und `CALDAV_PASSWORD`.
- **Sensor** (`sensor.enabled`): `GET sensor.url` (optional mit `SENSOR_TOKEN`), Wert aus dem Feld
  `sensor.field` (z. B. `luft.co2`), Titel `sensor.title`, Einheit `sensor.unit`, Warnfarbe ab
  `sensor.warn`.

## Missa-Ordner

Mit `missa.enabled` entsteht `~/Missa` (`missa.folder`) als gewöhnlicher lokaler Ordner: in `Eingang/`
abgelegte Dateien kann Missa über den Chat und ihre Rechner-Werkzeuge lesen, in `Ausgabe/` legt sie
Dateien an. Der Ordner wird nicht von Missa-Core verwaltet. Ausschalten entfernt nur das Lesezeichen
(und leere Ordner); Inhalte bleiben.
