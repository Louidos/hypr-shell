# Einstellungen

<!-- erzeugt von tests/doku-erzeugen.sh aus settings/schema.json – nicht von Hand ändern.
     Neu erzeugen: tests/doku-erzeugen.sh --write -->

Alle Werte stehen in `~/.config/hypr-shell/settings.json`. Es gibt drei Wege, sie zu ändern – alle
schreiben in dieselbe Datei und wirken sofort:

1. **Einstellungs-App**: `SUPER + U` (oder das Zahnrad im Panel).
2. **Befehl**: `shell-set <schlüssel> <wert>`, z. B. `shell-set look.rounding 20`; `shell-set undo`
   nimmt die letzte Änderung zurück, `shell-set list` zeigt alles.
3. **Datei**: `~/.config/hypr-shell/settings.json` mit einem Editor öffnen. Fehlende Werte haben ihren
   Standard; ein falscher Wert wird gemeldet und durch den Standard ersetzt.

Ein Schlüssel wie `look.gaps.inner` steht in der Datei verschachtelt:
`{ "look": { "gaps": { "inner": 10 } } }`. Die Erklärungen sind dieselben wie in der App (Englisch).

## bar – Leiste

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `bar.position` | `top` | `top`, `bottom` | Edge of the screen the bar sits on | `shell-set bar.position bottom` |
| `bar.height` | `30` | ganze Zahl 20 … 60 px | Height of the bar in pixels | `shell-set bar.height 31` |
| `bar.opacity` | `0.25` | Zahl 0 … 1, Schritt 0.05 | Opacity of the bar background | `shell-set bar.opacity 0.3` |
| `bar.modules.left` | `["distro","workspaces","media"]` | Liste aus `distro`, `workspaces`, `window`, `media`, `volume`, `battery`, `clock`, `bluetooth`, `network`, `tray`, `recording`, `notifications`, `missa`, `power` | Modules on the left, in this order | `shell-set bar.modules.left distro,workspaces` |
| `bar.modules.center` | `[]` | Liste aus `distro`, `workspaces`, `window`, `media`, `volume`, `battery`, `clock`, `bluetooth`, `network`, `tray`, `recording`, `notifications`, `missa`, `power` | Modules in the middle, in this order | `shell-set bar.modules.center distro,workspaces` |
| `bar.modules.right` | `["volume","battery","clock","bluetooth","network","recording","notifications","missa","power"]` | Liste aus `distro`, `workspaces`, `window`, `media`, `volume`, `battery`, `clock`, `bluetooth`, `network`, `tray`, `recording`, `notifications`, `missa`, `power` | Modules on the right, in this order | `shell-set bar.modules.right distro,workspaces` |
| `bar.workspaces` | `4` | ganze Zahl 0 … 10 | Workspaces that are always shown (0 = only used ones) | `shell-set bar.workspaces 5` |
| `bar.clock` | `24h` | `24h`, `12h` | 24-hour or 12-hour clock in the bar | `shell-set bar.clock 12h` |
| `bar.battery` | `true` | `true`, `false` | Show the battery (only on devices with a battery) | `shell-set bar.battery false` |

## look – Fenster: Abstände, Rundung, Blur, Animationen

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `look.gaps.inner` | `6` | ganze Zahl 0 … 40 px | Space between windows | `shell-set look.gaps.inner 7` |
| `look.gaps.outer` | `12` | ganze Zahl 0 … 60 px | Space between windows and the screen edge | `shell-set look.gaps.outer 13` |
| `look.border` | `1` | ganze Zahl 0 … 8 px | Width of the window border | `shell-set look.border 2` |
| `look.rounding` | `12` | ganze Zahl 0 … 30 px | Corner radius of windows | `shell-set look.rounding 13` |
| `look.blur.enabled` | `true` | `true`, `false` | Blur behind transparent windows, the bar and the glass panels | `shell-set look.blur.enabled false` |
| `look.blur.size` | `10` | ganze Zahl 1 … 20 | Radius of the blur | `shell-set look.blur.size 11` |
| `look.blur.passes` | `3` | ganze Zahl 1 … 6 | More passes give a softer blur but cost more | `shell-set look.blur.passes 4` |
| `look.shadow` | `true` | `true`, `false` | Soft shadow under windows | `shell-set look.shadow false` |
| `look.opacity.inactive` | `1.0` | Zahl 0.5 … 1, Schritt 0.05 | Opacity of windows without focus | `shell-set look.opacity.inactive 0.95` |
| `look.animations.enabled` | `true` | `true`, `false` | Animate windows, workspaces and layers | `shell-set look.animations.enabled false` |
| `look.animations.speed` | `normal` | `slow`, `normal`, `fast` | How fast animations play | `shell-set look.animations.speed slow` |

## theme – Farben, Glas, Schriften, Mauszeiger

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `theme.colors` | `auto` | `auto`, `grey`, `custom` | auto = colors from the wallpaper, grey = grey and white, custom = your accent color | `shell-set theme.colors grey` |
| `theme.accent` | `#8ab4f8` | Farbe `#rrggbb` | Accent color for the custom color mode | `shell-set theme.accent "#a6e3a1"` |
| `theme.glass` | `0.44` | Zahl 0.1 … 0.95, Schritt 0.01 | Opacity of the desktop tiles and the settings window | `shell-set theme.glass 0.45` |
| `theme.radius.panel` | `26` | ganze Zahl 0 … 40 px | Corner radius of glass panels | `shell-set theme.radius.panel 27` |
| `theme.radius.card` | `18` | ganze Zahl 0 … 30 px | Corner radius of cards inside panels | `shell-set theme.radius.card 19` |
| `theme.font.ui` | `Inter` | Text | Font for text in the bar, dashboard, panel and lock screen | `shell-set theme.font.ui "Noto Sans"` |
| `theme.font.mono` | `JetBrainsMono Nerd Font` | Text | Font for symbols and numbers (needs Nerd Font symbols) | `shell-set theme.font.mono "Noto Sans"` |
| `theme.font.clock` | `JetBrainsMono Nerd Font` | Text | Font of the big clock on the desktop | `shell-set theme.font.clock "Noto Sans"` |
| `theme.font.display` | `Bebas Neue` | Text | Font of the clocks in the dashboard and on the lock screen | `shell-set theme.font.display "Noto Sans"` |
| `theme.font.scale` | `1.0` | Zahl 0.8 … 1.5, Schritt 0.05 | Factor for all font sizes | `shell-set theme.font.scale 1.05` |
| `theme.cursor.name` | `Bibata-Modern-Ice` | Text | Name of the mouse cursor theme | `shell-set theme.cursor.name Adwaita` |
| `theme.cursor.size` | `24` | ganze Zahl 16 … 64 px | Size of the mouse cursor | `shell-set theme.cursor.size 26` |
| `theme.icons` | `Papirus-Dark` | Text | Icon theme for apps in the panel and the launcher | `shell-set theme.icons Adwaita` |

## input – Eingabe

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `input.layout` | `us` | Text (Format geprüft) | Layout code like us, de or ch | `shell-set input.layout de` |
| `input.variant` | `""` | Text (Format geprüft) | Variant like de or fr for ch (empty = standard) | `shell-set input.variant nodeadkeys` |
| `input.sensitivity` | `0` | Zahl -1 … 1, Schritt 0.1 | -1 = slow, 0 = normal, 1 = fast | `shell-set input.sensitivity 0.1` |
| `input.touchpad.natural_scroll` | `false` | `true`, `false` | Touchpad content follows your fingers | `shell-set input.touchpad.natural_scroll true` |
| `input.touchpad.tap_to_click` | `true` | `true`, `false` | Tapping the touchpad clicks | `shell-set input.touchpad.tap_to_click false` |

## monitors – Bildschirme

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `monitors.scale` | `auto` | Text (Format geprüft) | Scale for screens without their own entry: auto or a number like 1.25, 1.5, 2 | `shell-set monitors.scale 1.5` |
| `monitors.outputs` | `[]` | Liste von Einträgen mit `name`, `resolution`, `refresh`, `scale`, `position` | Settings for single screens; empty values mean automatic | `shell-set monitors.outputs '[{"name":"eDP-1","scale":"1.5"}]'` |

## desktop – Desktop: Uhr und Kacheln

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `desktop.screen` | `""` | Text | Screen for widgets, dashboard and panel (name from hyprctl monitors, empty = first) | `shell-set desktop.screen eDP-1` |
| `desktop.clock.enabled` | `true` | `true`, `false` | Big stacked clock on the desktop | `shell-set desktop.clock.enabled false` |
| `desktop.clock.format` | `24h` | `24h`, `12h` | 24-hour or 12-hour clock | `shell-set desktop.clock.format 12h` |
| `desktop.clock.x` | `0.02` | Zahl 0 … 1, Schritt 0.005 | Distance from the left as a share of the screen width | `shell-set desktop.clock.x 0.025` |
| `desktop.clock.y` | `0.045` | Zahl 0 … 1, Schritt 0.005 | Distance from the top as a share of the screen height | `shell-set desktop.clock.y 0.05` |
| `desktop.clock.scale` | `1.0` | Zahl 0.3 … 3, Schritt 0.05 | Size factor of the clock | `shell-set desktop.clock.scale 1.05` |
| `desktop.resources.enabled` | `true` | `true`, `false` | Usage tiles on the desktop | `shell-set desktop.resources.enabled false` |
| `desktop.resources.tiles` | `["cpu","ram","gpu"]` | Liste aus `cpu`, `ram`, `gpu`, `disk` | Tiles and their order | `shell-set desktop.resources.tiles cpu,ram` |
| `desktop.resources.x` | `0.015` | Zahl 0 … 1, Schritt 0.005 | Distance from the left as a share of the screen width | `shell-set desktop.resources.x 0.02` |
| `desktop.resources.y` | `0.56` | Zahl 0 … 1, Schritt 0.005 | Distance from the top as a share of the screen height | `shell-set desktop.resources.y 0.565` |
| `desktop.resources.scale` | `1.0` | Zahl 0.3 … 3, Schritt 0.05 | Size factor of the tiles | `shell-set desktop.resources.scale 1.05` |

## dashboard – Dashboard

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `dashboard.width` | `1000` | ganze Zahl 600 … 2400 px | Width of the dashboard in pixels | `shell-set dashboard.width 1010` |
| `dashboard.opacity` | `0.42` | Zahl 0.1 … 0.95, Schritt 0.01 | Opacity of the glass | `shell-set dashboard.opacity 0.43` |
| `dashboard.edge` | `true` | `true`, `false` | Open when the mouse touches the middle of the bottom edge | `shell-set dashboard.edge false` |
| `dashboard.close_on_leave` | `true` | `true`, `false` | Close when the mouse leaves the dashboard | `shell-set dashboard.close_on_leave false` |
| `dashboard.tabs` | `["dashboard","wallpaper","performance","games","about"]` | Liste aus `dashboard`, `wallpaper`, `performance`, `games`, `about` | Tabs and their order (Games only appears when Steam games or own entries exist) | `shell-set dashboard.tabs dashboard,wallpaper` |
| `dashboard.start` | `dashboard` | `dashboard`, `wallpaper`, `performance`, `games`, `about` | Tab shown when the dashboard opens | `shell-set dashboard.start wallpaper` |
| `dashboard.cards` | `["weather","profile","media","clock","calendar","rings"]` | Liste aus `weather`, `profile`, `media`, `clock`, `calendar`, `rings` | Cards on the Dashboard tab | `shell-set dashboard.cards weather,profile` |

## weather – Wetter

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `weather.location` | `""` | Text | Place for the weather, e.g. Zürich | `shell-set weather.location "Zürich"` |
| `weather.units` | `metric` | `metric`, `imperial` | metric = °C, imperial = °F | `shell-set weather.units imperial` |

## games – games

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `games.auto_gaming` | `true` | `true`, `false` | Switch the gaming mode on while a game runs in fullscreen, and off again afterwards | `shell-set games.auto_gaming false` |
| `games.auto_classes` | `["steam_app_[0-9]+","gamescope"]` | Liste von Texten | Window classes (regular expressions) that count as games for the automatic gaming mode | `shell-set games.auto_classes steam_app_[0-9]+,gamescope,code` |
| `games.custom_enabled` | `false` | `true`, `false` | Show your own entries (GOG, Battle.net …) in the Games tab | `shell-set games.custom_enabled true` |
| `games.custom` | `[]` | Liste von Einträgen mit `name`, `command`, `image` | Name, command and picture of own games, e.g. for GOG or Battle.net | `shell-set games.custom '[]'` |

## panel – Hot-Corner-Panel

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `panel.enabled` | `true` | `true`, `false` | Open the panel when the mouse touches the corner | `shell-set panel.enabled false` |
| `panel.corner` | `bottom-right` | `bottom-right`, `bottom-left`, `top-right`, `top-left` | Screen corner of the panel | `shell-set panel.corner bottom-left` |
| `panel.trigger` | `6` | ganze Zahl 1 … 40 px | Size of the corner area in pixels | `shell-set panel.trigger 7` |
| `panel.close_on_leave` | `true` | `true`, `false` | Close when the mouse leaves the panel | `shell-set panel.close_on_leave false` |
| `panel.close_delay` | `400` | ganze Zahl 100 … 10000 ms | Wait time before closing after the mouse left | `shell-set panel.close_delay 450` |
| `panel.width` | `420` | ganze Zahl 320 … 800 px | Width of the panel | `shell-set panel.width 430` |
| `panel.radius` | `26` | ganze Zahl 0 … 40 px | Corner radius of the panel | `shell-set panel.radius 27` |
| `panel.opacity` | `0.44` | Zahl 0.1 … 0.95, Schritt 0.01 | Opacity of the glass | `shell-set panel.opacity 0.45` |
| `panel.sections` | `["awake","apps","media","shot","toggles"]` | Liste aus `awake`, `apps`, `media`, `shot`, `toggles` | Cards and their order | `shell-set panel.sections awake,apps` |
| `panel.apps` | `["kitty","org.gnome.Nautilus","firefox","spotify","discord","steam"]` | Liste von Texten | Apps in the grid (name of the .desktop file); missing ones are skipped | `shell-set panel.apps kitty,org.gnome.Nautilus,firefox,spotify,discord,steam,code` |
| `panel.toggles` | `["wifi","bluetooth","audio","dnd","gaming","profile","nightlight","settings"]` | Liste aus `wifi`, `bluetooth`, `audio`, `dnd`, `gaming`, `awake`, `profile`, `nightlight`, `settings` | Quick toggles in the panel, in this order (toggles the computer cannot use are hidden) | `shell-set panel.toggles wifi,bluetooth` |

## lock – Sperren und Standby

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `lock.after` | `5` | ganze Zahl 0 … 120 min | Lock the screen after this many idle minutes (0 = never) | `shell-set lock.after 6` |
| `lock.screen_off` | `0` | ganze Zahl 0 … 120 min | Turn the screen off after this many idle minutes (0 = never) | `shell-set lock.screen_off 1` |
| `lock.suspend` | `15` | ganze Zahl 0 … 240 min | Go to standby after this many idle minutes (0 = never) | `shell-set lock.suspend 16` |
| `lock.blur` | `3` | ganze Zahl 0 … 6 | Blur passes of the lock screen background (0 = none) | `shell-set lock.blur 4` |
| `lock.dim` | `0.5` | Zahl 0 … 0.9, Schritt 0.05 | How much darker the background gets | `shell-set lock.dim 0.55` |
| `lock.avatar` | `true` | `true`, `false` | Show ~/.face (or your initial) above the clock | `shell-set lock.avatar false` |
| `lock.clock` | `24h` | `24h`, `12h` | 24-hour or 12-hour clock | `shell-set lock.clock 12h` |

## apps – Standard-Programme

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `apps.terminal` | `kitty` | Text (Format geprüft) | Command for the terminal | `shell-set apps.terminal foot` |
| `apps.files` | `nautilus` | Text (Format geprüft) | Command for the file manager | `shell-set apps.files thunar` |
| `apps.browser` | `firefox` | Text (Format geprüft) | Command for the web browser | `shell-set apps.browser chromium` |
| `apps.launcher` | `builtin` | Text (Format geprüft) | builtin = the glass launcher of hypr-shell (with calculator), or an own command such as rofi -show drun | `shell-set apps.launcher "fuzzel"` |

## notifications – notifications

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `notifications.enabled` | `true` | `true`, `false` | Show notifications as glass cards and keep a history (SUPER+N). Off: hypr-shell does not run a notification service | `shell-set notifications.enabled false` |
| `notifications.timeout` | `6` | ganze Zahl 1 … 60 s | Seconds a card stays on screen (urgent ones stay until closed) | `shell-set notifications.timeout 7` |
| `notifications.history` | `100` | ganze Zahl 10 … 500 | How many notifications the history keeps | `shell-set notifications.history 110` |

## osd – osd

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `osd.enabled` | `true` | `true`, `false` | Show a small glass display at the bottom when volume or brightness changes | `shell-set osd.enabled false` |

## clipboard – clipboard

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `clipboard.enabled` | `true` | `true`, `false` | Remember copied text and images (SUPER+SHIFT+V). Off: nothing is recorded | `shell-set clipboard.enabled false` |
| `clipboard.max` | `50` | ganze Zahl 5 … 500 | How many copies the history keeps | `shell-set clipboard.max 55` |

## nightlight – nightlight

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `nightlight.temperature` | `4000` | ganze Zahl 2500 … 6500 K | Color temperature of the night light (lower = warmer) | `shell-set nightlight.temperature 4100` |
| `nightlight.schedule` | `false` | `true`, `false` | Switch the night light on and off at the times below (the panel toggle still works in between) | `shell-set nightlight.schedule true` |
| `nightlight.from` | `20:00` | Text (Format geprüft) | Time the night light switches on, like 20:00 | `shell-set nightlight.from 20:00` |
| `nightlight.to` | `07:00` | Text (Format geprüft) | Time the night light switches off, like 07:00 | `shell-set nightlight.to 07:00` |

## laptop – laptop

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `laptop.charge_limit` | `100` | ganze Zahl 20 … 100 % | Stop charging the battery at this level (100 = always full). Kept by asusd across restarts | `shell-set laptop.charge_limit 95` |
| `laptop.kbd_light` | `unchanged` | `unchanged`, `off`, `low`, `med`, `high` | Brightness of the keyboard backlight (unchanged = leave it as it is) | `shell-set laptop.kbd_light off` |
| `laptop.kbd_follow_wallpaper` | `false` | `true`, `false` | Keyboard color follows the accent color of the wallpaper | `shell-set laptop.kbd_follow_wallpaper true` |

## nextcloud – nextcloud

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `nextcloud.enabled` | `false` | `true`, `false` | Mount your Nextcloud as a normal folder (WebDAV, rclone) with a bookmark in the file manager | `shell-set nextcloud.enabled true` |
| `nextcloud.url` | `""` | Text (Format geprüft) | Address of the Nextcloud, like https://cloud.example.org | `shell-set nextcloud.url ` |
| `nextcloud.user` | `""` | Text (Format geprüft) | Nextcloud user name (the app password is stored separately in secrets.env) | `shell-set nextcloud.user ` |
| `nextcloud.mount_path` | `~/Nextcloud` | Text (Format geprüft) | Where the Nextcloud appears | `shell-set nextcloud.mount_path ~/Nextcloud` |
| `nextcloud.cache_mb` | `1024` | ganze Zahl 128 … 20480 MB | Space for the local copy of opened files | `shell-set nextcloud.cache_mb 1152` |
| `nextcloud.read_only` | `false` | `true`, `false` | Only read files from the Nextcloud, never change them | `shell-set nextcloud.read_only true` |

## missa – missa

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `missa.enabled` | `false` | `true`, `false` | Your assistant Missa: chat (SUPER+I), dashboard card and the folder ~/Missa | `shell-set missa.enabled true` |
| `missa.url` | `""` | Text (Format geprüft) | Base address of Missa-Core, like https://missa.example.org (the key is stored in secrets.env) | `shell-set missa.url ` |
| `missa.folder` | `~/Missa` | Text (Format geprüft) | Local folder with Eingang (files for Missa) and Ausgabe (files from Missa) | `shell-set missa.folder ~/Missa` |
| `missa.agent_enabled` | `false` | `true`, `false` | Missa can find and open files, control apps and windows and, after confirmation, run commands | `shell-set missa.agent_enabled true` |
| `missa.access` | `ask` | `off`, `read`, `ask`, `full` | off: nothing · read: only reading · ask: writing is free, destructive actions need your click · full: no local question | `shell-set missa.access off` |
| `missa.blocked_paths` | `["~/.ssh","~/.gnupg","~/.local/share/keyrings","~/.password-store","~/.mozilla","~/.config/google-chrome","~/.config/chromium","~/.config/BraveSoftware","~/.var/app","~/.config/hypr-shell/secrets.env"]` | Liste von Texten | Missa never reads, searches or changes these (in every access level) | `shell-set missa.blocked_paths ~/.ssh,~/.gnupg,~/.local/share/keyrings,~/.password-store,~/.mozilla,~/.config/google-chrome,~/.config/chromium,~/.config/BraveSoftware,~/.var/app,~/.config/hypr-shell/secrets.env,code` |
| `missa.device` | `""` | Text (Format geprüft) | Name of this computer in Missa-Core (the token belongs to it); empty = host name | `shell-set missa.device ` |
| `missa.voice_enabled` | `false` | `true`, `false` | Speak with Missa (SUPER+SHIFT+I) and hear her answers, locally with whisper.cpp and piper | `shell-set missa.voice_enabled true` |
| `missa.voice_language` | `de` | Text (Format geprüft) | Language for recognition (whisper.cpp), e.g. de, en or auto | `shell-set missa.voice_language de` |
| `missa.voice_model` | `~/.local/share/hypr-shell/whisper/ggml-base.bin` | Text (Format geprüft) | whisper.cpp model file (bigger = better, slower: tiny, base, small …) | `shell-set missa.voice_model ~/.local/share/hypr-shell/whisper/ggml-base.bin` |
| `missa.voice_voice` | `~/.local/share/hypr-shell/piper/de_DE-thorsten-medium.onnx` | Text (Format geprüft) | piper voice file (.onnx, with its .onnx.json next to it) | `shell-set missa.voice_voice ~/.local/share/hypr-shell/piper/de_DE-thorsten-medium.onnx` |
| `missa.voice_speed` | `1.0` | Zahl 0.5 … 2.0, Schritt 0.05 | How fast Missa reads her answers | `shell-set missa.voice_speed 1.05` |

## lab – lab

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `lab.enabled` | `false` | `true`, `false` | Dashboard tab Lab with VMs, servers, containers and alarms (read through Missa-Core) | `shell-set lab.enabled true` |

## calendar – calendar

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `calendar.enabled` | `false` | `true`, `false` | Appointments from a CalDAV calendar (e.g. Nextcloud) in the dashboard calendar | `shell-set calendar.enabled true` |
| `calendar.url` | `""` | Text (Format geprüft) | Address of the calendar, like https://cloud.example.org/remote.php/dav/calendars/user/personal/ | `shell-set calendar.url ` |
| `calendar.user` | `""` | Text (Format geprüft) | CalDAV user name (the password is stored in secrets.env) | `shell-set calendar.user ` |

## sensor – sensor

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `sensor.enabled` | `false` | `true`, `false` | Dashboard tile with a value from a JSON address, e.g. air quality | `shell-set sensor.enabled true` |
| `sensor.url` | `""` | Text (Format geprüft) | Address that returns JSON | `shell-set sensor.url ` |

## integrations – integrations

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `integrations.ca_file` | `""` | Text (Format geprüft) | Certificate of your own certificate authority for self-signed servers (checking is never switched off) | `shell-set integrations.ca_file ` |

## keybinds – Tastenkürzel

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `keybinds.terminal` | `SUPER + Q` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the terminal (apps.terminal) | `shell-set keybinds.terminal "SUPER + B"` |
| `keybinds.files` | `SUPER + E` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the file manager (apps.files) | `shell-set keybinds.files "SUPER + B"` |
| `keybinds.browser` | `""` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the browser (apps.browser); empty = no key | `shell-set keybinds.browser "SUPER + B"` |
| `keybinds.launcher` | `SUPER + R` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the app launcher (apps.launcher) | `shell-set keybinds.launcher "SUPER + B"` |
| `keybinds.launcher_alt` | `ALT + Space` | Tasten wie `SUPER + Q`, leer = keine Taste | Another key for the app launcher | `shell-set keybinds.launcher_alt "SUPER + B"` |
| `keybinds.launcher_space` | `SUPER + Space` | Tasten wie `SUPER + Q`, leer = keine Taste | Third shortcut for the launcher | `shell-set keybinds.launcher_space "SUPER + B"` |
| `keybinds.close` | `SUPER + C` | Tasten wie `SUPER + Q`, leer = keine Taste | Close the focused window | `shell-set keybinds.close "SUPER + B"` |
| `keybinds.float` | `SUPER + V` | Tasten wie `SUPER + Q`, leer = keine Taste | Switch the focused window between floating and tiled | `shell-set keybinds.float "SUPER + B"` |
| `keybinds.focus_left` | `SUPER + left` | Tasten wie `SUPER + Q`, leer = keine Taste | Move the focus to the window on the left | `shell-set keybinds.focus_left "SUPER + B"` |
| `keybinds.focus_right` | `SUPER + right` | Tasten wie `SUPER + Q`, leer = keine Taste | Move the focus to the window on the right | `shell-set keybinds.focus_right "SUPER + B"` |
| `keybinds.focus_up` | `SUPER + up` | Tasten wie `SUPER + Q`, leer = keine Taste | Move the focus to the window above | `shell-set keybinds.focus_up "SUPER + B"` |
| `keybinds.focus_down` | `SUPER + down` | Tasten wie `SUPER + Q`, leer = keine Taste | Move the focus to the window below | `shell-set keybinds.focus_down "SUPER + B"` |
| `keybinds.workspace_mod` | `SUPER` | Tasten wie `SUPER + Q`, leer = keine Taste | Modifier for 1 … 0 (go to workspace) and the mouse wheel; empty = off | `shell-set keybinds.workspace_mod "ALT"` |
| `keybinds.move_mod` | `SUPER + SHIFT` | Tasten wie `SUPER + Q`, leer = keine Taste | Modifier for 1 … 0 (move the window there); empty = off | `shell-set keybinds.move_mod "ALT"` |
| `keybinds.mouse_mod` | `SUPER` | Tasten wie `SUPER + Q`, leer = keine Taste | Modifier for dragging (left button) and resizing (right button) windows; empty = off | `shell-set keybinds.mouse_mod "ALT"` |
| `keybinds.dashboard` | `SUPER + ALT + D` | Tasten wie `SUPER + Q`, leer = keine Taste | Open or close the dashboard | `shell-set keybinds.dashboard "SUPER + B"` |
| `keybinds.dashboard_alt` | `SUPER + D` | Tasten wie `SUPER + Q`, leer = keine Taste | Second shortcut that opens or closes the dashboard | `shell-set keybinds.dashboard_alt "SUPER + B"` |
| `keybinds.wallpaper` | `SUPER + W` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the dashboard on the Wallpaper tab | `shell-set keybinds.wallpaper "SUPER + B"` |
| `keybinds.panel` | `SUPER + A` | Tasten wie `SUPER + Q`, leer = keine Taste | Open or close the hot corner panel | `shell-set keybinds.panel "SUPER + B"` |
| `keybinds.notifications` | `SUPER + N` | Tasten wie `SUPER + Q`, leer = keine Taste | Open or close the notification history | `shell-set keybinds.notifications "SUPER + B"` |
| `keybinds.edit_desktop` | `SUPER + ALT + W` | Tasten wie `SUPER + Q`, leer = keine Taste | Move and resize the clock and tiles with the mouse | `shell-set keybinds.edit_desktop "SUPER + B"` |
| `keybinds.settings` | `SUPER + U` | Tasten wie `SUPER + Q` (nicht leer) | Open or close this settings app (cannot be empty) | `shell-set keybinds.settings "SUPER + B"` |
| `keybinds.power` | `SUPER + Escape` | Tasten wie `SUPER + Q`, leer = keine Taste | Lock, sleep, log out, restart or shut down | `shell-set keybinds.power "SUPER + B"` |
| `keybinds.clipboard` | `SUPER + SHIFT + V` | Tasten wie `SUPER + Q`, leer = keine Taste | Show the last copies to paste them again | `shell-set keybinds.clipboard "SUPER + B"` |
| `keybinds.overview` | `SUPER + Tab` | Tasten wie `SUPER + Q`, leer = keine Taste | Show all workspaces with their windows | `shell-set keybinds.overview "SUPER + B"` |
| `keybinds.cheatsheet` | `SUPER + F1` | Tasten wie `SUPER + Q`, leer = keine Taste | Show all keyboard shortcuts | `shell-set keybinds.cheatsheet "SUPER + B"` |
| `keybinds.missa_chat` | `SUPER + I` | Tasten wie `SUPER + Q`, leer = keine Taste | Chat with Missa (only when Missa is switched on) | `shell-set keybinds.missa_chat "SUPER + B"` |
| `keybinds.missa_voice` | `SUPER + SHIFT + I` | Tasten wie `SUPER + Q`, leer = keine Taste | Speak with Missa; press again to stop (only when Missa and talking are switched on) | `shell-set keybinds.missa_voice "SUPER + B"` |
| `keybinds.lock` | `SUPER + L` | Tasten wie `SUPER + Q`, leer = keine Taste | Lock the screen | `shell-set keybinds.lock "SUPER + B"` |
| `keybinds.exit` | `SUPER + M` | Tasten wie `SUPER + Q`, leer = keine Taste | Leave Hyprland | `shell-set keybinds.exit "SUPER + B"` |
| `keybinds.screenshot_region` | `Print` | Tasten wie `SUPER + Q`, leer = keine Taste | Select a region; saved and copied | `shell-set keybinds.screenshot_region "SUPER + B"` |
| `keybinds.screenshot_screen` | `SHIFT + Print` | Tasten wie `SUPER + Q`, leer = keine Taste | Whole screen; saved and copied | `shell-set keybinds.screenshot_screen "SUPER + B"` |
| `keybinds.custom` | `[]` | Liste von Einträgen mit `keys`, `command` | Own key combinations that run a command | `shell-set keybinds.custom '[{"keys":"SUPER + B","command":"firefox"}]'` |

