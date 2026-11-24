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

**Bildschirm drehen:** `shell-set monitor eDP-1 rotate 90` (0, 90, 180, 270; die Spiegelung bleibt),
`shell-set monitor eDP-1 mirror on|off`, oder direkt das Feld `transform` in `monitors.outputs`:
`normal`, `90`, `180`, `270`, `flipped`, `flipped-90`, `flipped-180`, `flipped-270`. Einträge ohne
`transform` gelten als `normal`. Ein Touchscreen oder Stift dreht mit (nur, wenn es einen gibt).

## bar – Leiste

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `bar.position` | `top` | `top`, `bottom` | Edge of the screen the bar sits on | `shell-set bar.position bottom` |
| `bar.height` | `30` | ganze Zahl 20 … 60 px | Height of the bar in pixels | `shell-set bar.height 31` |
| `bar.opacity` | `-1` | Zahl -1 … 1, Schritt 0.05 | Opacity of the bar background; -1 = same as all glass (Theme → Glass opacity) | `shell-set bar.opacity -0.95` |
| `bar.floating` | `true` | `true`, `false` | Rounded glass bar with a small gap to the screen edge; off = full width along the edge | `shell-set bar.floating false` |
| `bar.modules.left` | `["distro","workspaces","media"]` | Liste aus `distro`, `workspaces`, `window`, `media`, `volume`, `battery`, `clock`, `bluetooth`, `network`, `tray`, `recording`, `notifications`, `missa`, `power` | Modules on the left, in this order | `shell-set bar.modules.left distro,workspaces` |
| `bar.modules.center` | `[]` | Liste aus `distro`, `workspaces`, `window`, `media`, `volume`, `battery`, `clock`, `bluetooth`, `network`, `tray`, `recording`, `notifications`, `missa`, `power` | Modules in the middle, in this order | `shell-set bar.modules.center distro,workspaces` |
| `bar.modules.right` | `["volume","battery","clock","bluetooth","network","recording","notifications","missa","power"]` | Liste aus `distro`, `workspaces`, `window`, `media`, `volume`, `battery`, `clock`, `bluetooth`, `network`, `tray`, `recording`, `notifications`, `missa`, `power` | Modules on the right, in this order | `shell-set bar.modules.right distro,workspaces` |
| `bar.workspaces` | `4` | ganze Zahl 0 … 10 | Workspaces that are always shown (0 = only used ones) | `shell-set bar.workspaces 5` |
| `bar.clock` | `24h` | `24h`, `12h` | 24-hour or 12-hour clock in the bar | `shell-set bar.clock 12h` |
| `bar.battery` | `true` | `true`, `false` | Show the battery (only on devices with a battery) | `shell-set bar.battery false` |

## look – Fenster: Abstände, Rundung, Blur, Animationen

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `look.preset` | `glass` | `glass`, `minimal`, `gaming` | Last chosen look (choose with the buttons above): glass, minimal or gaming; changes only look and glass values | `shell-set look.preset minimal` |
| `look.gaps.inner` | `6` | ganze Zahl 0 … 40 px | Space between windows | `shell-set look.gaps.inner 7` |
| `look.gaps.outer` | `12` | ganze Zahl 0 … 60 px | Space between windows and the screen edge | `shell-set look.gaps.outer 13` |
| `look.border` | `1` | ganze Zahl 0 … 8 px | Width of the window border | `shell-set look.border 2` |
| `look.rounding` | `14` | ganze Zahl 0 … 30 px | Corner radius of windows | `shell-set look.rounding 15` |
| `look.blur.enabled` | `true` | `true`, `false` | Blur behind transparent windows, the bar and the glass panels | `shell-set look.blur.enabled false` |
| `look.blur.size` | `10` | ganze Zahl 1 … 20 | Radius of the blur | `shell-set look.blur.size 11` |
| `look.blur.passes` | `3` | ganze Zahl 1 … 6 | More passes give a softer blur but cost more | `shell-set look.blur.passes 4` |
| `look.shadow` | `true` | `true`, `false` | Soft shadow under windows | `shell-set look.shadow false` |
| `look.opacity.inactive` | `0.88` | Zahl 0.5 … 1, Schritt 0.05 | Opacity of windows without focus (games, videos, image editors and fullscreen stay opaque) | `shell-set look.opacity.inactive 0.93` |
| `look.opacity.active` | `0.95` | Zahl 0.5 … 1, Schritt 0.01 | Opacity of the window with focus (games, videos, image editors and fullscreen stay opaque) | `shell-set look.opacity.active 0.96` |
| `look.opacity.exceptions` | `["steam_app_[0-9]+","gamescope","steam","battle.net.exe","heroic","lutris","mpv","vlc","celluloid","org.gnome.Totem","gimp","krita","inkscape","darktable","org.kde.kdenlive","blender"]` | Liste von Texten | Window classes (regular expressions) that never become transparent: games, video players, image editors | `shell-set look.opacity.exceptions steam_app_[0-9]+,gamescope,steam,battle.net.exe,heroic,lutris,mpv,vlc,celluloid,org.gnome.Totem,gimp,krita,inkscape,darktable,org.kde.kdenlive,blender,code` |
| `look.border_color` | `white` | `white`, `accent` | white = fine white glass edge (Theme → Border), accent = color of the wallpaper | `shell-set look.border_color accent` |
| `look.animations.enabled` | `true` | `true`, `false` | Animate windows, workspaces and layers | `shell-set look.animations.enabled false` |
| `look.animations.speed` | `normal` | `slow`, `normal`, `fast` | How fast animations play | `shell-set look.animations.speed slow` |

## fenster – fenster

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `fenster.titelleiste` | `an` | `an`, `aus`, `nur-schwebend` | Slim glass title bar with window buttons: an = on every normal window, aus = off, nur-schwebend = only floating windows (needs the hyprbars plugin) | `shell-set fenster.titelleiste aus` |
| `fenster.knoepfe.stil` | `windows` | `windows`, `mac` | windows = minimize, maximize, close as quiet symbols; mac = red, yellow and green dots | `shell-set fenster.knoepfe.stil mac` |
| `fenster.knoepfe.seite` | `auto` | `auto`, `rechts`, `links` | auto = right for windows style, left for mac style | `shell-set fenster.knoepfe.seite rechts` |
| `fenster.titelleiste_ausnahmen` | `["org.gnome.*","firefox","chromium","google-chrome","code","code-oss","vesktop","discord","steam","steam_app_[0-9]+","gamescope","mpv","vlc","celluloid"]` | Liste von Texten | Window classes (regular expressions) that draw their own title bar (GNOME apps, browsers) or need all the space (games, videos) | `shell-set fenster.titelleiste_ausnahmen org.gnome.*,firefox,chromium,google-chrome,code,code-oss,vesktop,discord,steam,steam_app_[0-9]+,gamescope,mpv,vlc,celluloid,code` |

## theme – Farben, Glas, Schriften, Mauszeiger

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `theme.colors` | `auto` | `auto`, `grey`, `custom` | auto = colors from the wallpaper, grey = grey and white, custom = your accent color | `shell-set theme.colors grey` |
| `theme.accent` | `#8ab4f8` | Farbe `#rrggbb` | Accent color for the custom color mode | `shell-set theme.accent "#a6e3a1"` |
| `theme.glass` | `0.55` | Zahl 0.1 … 0.95, Schritt 0.01 | Opacity of all glass surfaces: bar, dock, panels, menus, notifications, launcher and settings (darker automatically when text would be hard to read) | `shell-set theme.glass 0.56` |
| `theme.glass_color` | `#2a2a2f` | Farbe `#rrggbb` | Tint of all glass surfaces (neutral gray) | `shell-set theme.glass_color "#a6e3a1"` |
| `theme.border.color` | `#ffffff` | Farbe `#rrggbb` | Fine edge of glass surfaces and windows | `shell-set theme.border.color "#a6e3a1"` |
| `theme.border.opacity` | `0.35` | Zahl 0 … 1, Schritt 0.01 | Edge of the active window and of glass surfaces | `shell-set theme.border.opacity 0.36` |
| `theme.border.opacity_inactive` | `0.15` | Zahl 0 … 1, Schritt 0.01 | Edge of windows without focus | `shell-set theme.border.opacity_inactive 0.16` |
| `theme.border.width` | `1` | ganze Zahl 0 … 4 px | Width of the edge of glass surfaces | `shell-set theme.border.width 2` |
| `theme.radius.panel` | `14` | ganze Zahl 0 … 40 px | Corner radius of glass panels | `shell-set theme.radius.panel 15` |
| `theme.radius.card` | `10` | ganze Zahl 0 … 30 px | Corner radius of cards inside panels | `shell-set theme.radius.card 11` |
| `theme.font.ui` | `Inter` | Text (Format geprüft) | Font for text in the bar, dashboard, panel and lock screen | `shell-set theme.font.ui "Noto Sans"` |
| `theme.font.mono` | `JetBrainsMono Nerd Font` | Text (Format geprüft) | Font for symbols and numbers (needs Nerd Font symbols) | `shell-set theme.font.mono "Noto Sans"` |
| `theme.font.clock` | `JetBrainsMono Nerd Font` | Text (Format geprüft) | Font of the big clock on the desktop | `shell-set theme.font.clock "Noto Sans"` |
| `theme.font.display` | `Bebas Neue` | Text (Format geprüft) | Font of the clocks in the dashboard and on the lock screen | `shell-set theme.font.display "Noto Sans"` |
| `theme.font.scale` | `1.0` | Zahl 0.8 … 1.5, Schritt 0.05 | Factor for all font sizes | `shell-set theme.font.scale 1.05` |
| `theme.cursor.name` | `Bibata-Modern-Ice` | Text (Format geprüft) | Name of the mouse cursor theme | `shell-set theme.cursor.name Adwaita` |
| `theme.cursor.size` | `24` | ganze Zahl 16 … 64 px | Size of the mouse cursor | `shell-set theme.cursor.size 26` |
| `theme.icons` | `Papirus-Dark` | Text (Format geprüft) | Icon theme for apps in the panel and the launcher | `shell-set theme.icons Adwaita` |
| `theme.apps.gtk` | `true` | `true`, `false` | Files (Nautilus), dialogs and other GTK 3/4 apps take the wallpaper colors; off restores your own gtk.css. Open windows change after reopening | `shell-set theme.apps.gtk false` |
| `theme.apps.qt` | `true` | `true`, `false` | Qt apps take the wallpaper colors through qt5ct/qt6ct; off restores your qt5ct/qt6ct settings | `shell-set theme.apps.qt false` |
| `theme.apps.firefox` | `false` | `true`, `false` | Toolbar and tabs in the wallpaper colors (userChrome.css, backed up first); takes effect after restarting Firefox | `shell-set theme.apps.firefox true` |
| `theme.apps.vesktop` | `false` | `true`, `false` | Vesktop theme in the wallpaper colors (settings backed up first) | `shell-set theme.apps.vesktop true` |
| `theme.apps.spotify` | `false` | `true`, `false` | Spotify colors through spicetify (config backed up first, off restores it and runs spicetify apply) | `shell-set theme.apps.spotify true` |

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
| `monitors.outputs` | `[]` | Liste von Einträgen mit `name`, `resolution`, `refresh`, `scale`, `position`, `transform` | Settings for single screens; empty values mean automatic, rotation normal | `shell-set monitors.outputs '[{"name":"eDP-1","scale":"1.5"}]'` |

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
| `dashboard.opacity` | `-1` | Zahl -1 … 0.95, Schritt 0.01 | Opacity of the glass; -1 = same as all glass (Theme → Glass opacity) | `shell-set dashboard.opacity -0.99` |
| `dashboard.edge` | `true` | `true`, `false` | Open when the mouse touches the middle of the bottom edge | `shell-set dashboard.edge false` |
| `dashboard.close_on_leave` | `true` | `true`, `false` | Close when the mouse leaves the dashboard | `shell-set dashboard.close_on_leave false` |
| `dashboard.tabs` | `["dashboard","wallpaper","performance","games","lab","about"]` | Liste aus `dashboard`, `wallpaper`, `performance`, `games`, `lab`, `about` | Tabs in this order (Games only with Steam games or own entries, Lab only with lab.enabled) | `shell-set dashboard.tabs dashboard,wallpaper` |
| `dashboard.start` | `dashboard` | `dashboard`, `wallpaper`, `performance`, `games`, `lab`, `about` | Tab shown when the dashboard opens | `shell-set dashboard.start wallpaper` |
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
| `panel.radius` | `14` | ganze Zahl 0 … 40 px | Corner radius of the panel | `shell-set panel.radius 15` |
| `panel.opacity` | `-1` | Zahl -1 … 0.95, Schritt 0.01 | Opacity of the glass; -1 = same as all glass (Theme → Glass opacity) | `shell-set panel.opacity -0.99` |
| `panel.sections` | `["awake","apps","media","shot","toggles"]` | Liste aus `awake`, `apps`, `media`, `shot`, `toggles` | Cards and their order | `shell-set panel.sections awake,apps` |
| `panel.apps` | `["kitty","org.gnome.Nautilus","firefox","spotify","discord","steam"]` | Liste von Texten | Apps in the grid (name of the .desktop file); missing ones are skipped | `shell-set panel.apps kitty,org.gnome.Nautilus,firefox,spotify,discord,steam,code` |
| `panel.toggles` | `["wifi","bluetooth","audio","dnd","gaming","profile","nightlight","settings"]` | Liste aus `wifi`, `bluetooth`, `audio`, `dnd`, `gaming`, `awake`, `profile`, `nightlight`, `settings` | Quick toggles in the panel, in this order (toggles the computer cannot use are hidden) | `shell-set panel.toggles wifi,bluetooth` |

## dock – dock

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `dock.enabled` | `true` | `true`, `false` | Floating dock with pinned and running apps at the edge of the screen; off = no dock window at all | `shell-set dock.enabled false` |
| `dock.preset` | `mac` | `mac`, `minimal`, `compact`, `island`, `full` | Last chosen preset (choose one with the buttons above; it changes only dock values, never the items) | `shell-set dock.preset minimal` |
| `dock.position` | `bottom` | `bottom`, `left`, `right`, `top` | Screen edge of the dock | `shell-set dock.position left` |
| `dock.monitor` | `all` | Text (Format geprüft) | all = every screen, primary = the first screen, or the name of a screen (e.g. eDP-1) | `shell-set dock.monitor all` |
| `dock.running_per_monitor` | `false` | `true`, `false` | Each dock shows only the running apps with a window on its own screen | `shell-set dock.running_per_monitor true` |
| `dock.mode` | `floating` | `floating`, `reserve` | floating = windows can go below the dock, reserve = windows keep clear of it | `shell-set dock.mode reserve` |
| `dock.layer` | `top` | `top`, `bottom` | top = above windows, bottom = below windows | `shell-set dock.layer bottom` |
| `dock.margin` | `10` | ganze Zahl 0 … 100 px | Gap between the dock and the screen edge | `shell-set dock.margin 11` |
| `dock.icon_size` | `48` | ganze Zahl 16 … 128 px | Size of the app icons | `shell-set dock.icon_size 49` |
| `dock.icon_min_size` | `24` | ganze Zahl 16 … 64 px | Icons shrink down to this size when the dock gets full; after that it scrolls | `shell-set dock.icon_min_size 25` |
| `dock.padding` | `8` | ganze Zahl 0 … 40 px | Space between the glass edge and the icons | `shell-set dock.padding 9` |
| `dock.spacing` | `6` | ganze Zahl 0 … 40 px | Space between two icons | `shell-set dock.spacing 7` |
| `dock.radius` | `22` | ganze Zahl 0 … 100 px | Rounding of the glass; at most half the dock height (larger values give a pill) | `shell-set dock.radius 23` |
| `dock.max_length` | `90` | ganze Zahl 20 … 100 % | Longest the dock may get, relative to the screen edge | `shell-set dock.max_length 91` |
| `dock.glass_opacity` | `-1` | Zahl -1 … 1, Schritt 0.01 | Opacity of the glass; -1 = same as the panels (Theme → Glass opacity) | `shell-set dock.glass_opacity -0.99` |
| `dock.blur` | `true` | `true`, `false` | Blur behind the dock glass | `shell-set dock.blur false` |
| `dock.border_width` | `1` | ganze Zahl 0 … 6 px | Width of the glass border | `shell-set dock.border_width 2` |
| `dock.border_color` | `auto` | Farbe `#rrggbb` | auto = like the panels, or a color like #8ab4f8 | `shell-set dock.border_color "#a6e3a1"` |
| `dock.shadow` | `medium` | `none`, `soft`, `medium`, `strong` | Shadow below the dock | `shell-set dock.shadow none` |
| `dock.color_mode` | `glass` | `glass`, `wallpaper`, `dark`, `light`, `custom` | glass = like all glass surfaces (Theme → Glass), wallpaper = tinted like the wallpaper colors, dark, light, or custom (your own color) | `shell-set dock.color_mode wallpaper` |
| `dock.custom_color` | `#1e1e2e` | Farbe `#rrggbb` | Glass color for the color mode custom | `shell-set dock.custom_color "#a6e3a1"` |
| `dock.labels` | `hover` | `never`, `hover`, `always` | never, when the mouse is on an icon (hover), or always | `shell-set dock.labels never` |
| `dock.indicator` | `dot` | `dot`, `line`, `none` | Dot or line below running apps (two for several windows), or none | `shell-set dock.indicator line` |
| `dock.indicator_color` | `auto` | Farbe `#rrggbb` | auto = accent color of the wallpaper, or a color like #8ab4f8 | `shell-set dock.indicator_color "#a6e3a1"` |
| `dock.icon_style` | `original` | `original`, `mono`, `theme` | original colors, mono (grey) or theme (tinted in the wallpaper color) | `shell-set dock.icon_style mono` |
| `dock.show_running` | `true` | `true`, `false` | Also show running apps that are not pinned | `shell-set dock.show_running false` |
| `dock.trash` | `true` | `true`, `false` | Show the trash entry from the item list | `shell-set dock.trash false` |
| `dock.launcher_button` | `false` | `true`, `false` | Button at the start of the dock that opens the launcher | `shell-set dock.launcher_button true` |
| `dock.badges` | `true` | `true`, `false` | Small number on an icon for notifications of that app (needs the notification service of hypr-shell) | `shell-set dock.badges false` |
| `dock.previews` | `true` | `true`, `false` | Preview pictures in the window list when the mouse rests on an app with several windows | `shell-set dock.previews false` |
| `dock.magnify` | `true` | `true`, `false` | Icons grow like a wave when the mouse moves over them | `shell-set dock.magnify false` |
| `dock.magnify_factor` | `1.6` | Zahl 1.0 … 2.5, Schritt 0.05 | Size of the icon under the mouse relative to the normal size | `shell-set dock.magnify_factor 1.65` |
| `dock.magnify_range` | `2` | ganze Zahl 1 … 5 | How many neighbouring icons grow with it | `shell-set dock.magnify_range 3` |
| `dock.anim_ms` | `180` | ganze Zahl 0 … 1000 ms | Duration of the dock animations; 0 = no animations (also off in gaming mode or when animations are off) | `shell-set dock.anim_ms 190` |
| `dock.bounce_on_launch` | `true` | `true`, `false` | The icon bounces until the first window of the app appears (at most 5 seconds) | `shell-set dock.bounce_on_launch false` |
| `dock.autohide` | `smart` | `never`, `always`, `smart` | never, always (hide when the mouse leaves) or smart (hide only when a window covers the dock); touch the screen edge to show it again | `shell-set dock.autohide never` |
| `dock.show_delay_ms` | `150` | ganze Zahl 0 … 2000 ms | Time the mouse must touch the edge before a hidden dock comes back | `shell-set dock.show_delay_ms 160` |
| `dock.hide_delay_ms` | `400` | ganze Zahl 0 … 5000 ms | Time before the dock hides after the mouse left it | `shell-set dock.hide_delay_ms 450` |
| `dock.keyboard_timeout_s` | `10` | ganze Zahl 0 … 120 s | SUPER + B: back to the app after this many seconds without a key (0 = never); any other key or a click outside also leaves | `shell-set dock.keyboard_timeout_s 11` |
| `dock.hide_on_fullscreen` | `true` | `true`, `false` | No dock while a fullscreen window or the gaming mode is on; the edge does not show it either | `shell-set dock.hide_on_fullscreen false` |
| `dock.avoid_bar` | `true` | `true`, `false` | When the bar is on the same edge, the dock keeps its distance from it (also with reserve) | `shell-set dock.avoid_bar false` |
| `dock.items` | `[{"type":"app","desktop_id":"org.gnome.Nautilus","path":""},{"type":"app","desktop_id":"kitty","path":""},{"type":"app","desktop_id":"firefox","path":""},{"type":"separator","desktop_id":"","path":""},{"type":"folder","desktop_id":"","path":"~/Downloads"},{"type":"separator","desktop_id":"","path":""},{"type":"trash","desktop_id":"","path":""}]` | Liste von Einträgen mit `type`, `desktop_id`, `path` | Pinned apps, folders, separators, trash and launcher button in this order | `shell-set dock.items '[]'` |

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

## switcher – switcher

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `switcher.enabled` | `true` | `true`, `false` | ALT + Tab shows all windows with previews, last used first; release ALT to switch | `shell-set switcher.enabled false` |
| `switcher.scope` | `all` | `all`, `workspace` | all = every workspace and screen (and minimized windows), workspace = only the current workspace | `shell-set switcher.scope workspace` |
| `switcher.previews` | `true` | `true`, `false` | Live picture of each window; off = icons only (faster on slow graphics) | `shell-set switcher.previews false` |
| `switcher.size` | `medium` | `small`, `medium`, `large` | Size of the tiles | `shell-set switcher.size small` |

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
| `sensor.field` | `value` | Text (Format geprüft) | Which value of the JSON to show, as a path like luft.co2 | `shell-set sensor.field value` |
| `sensor.title` | `Air quality` | Text (Format geprüft) | Title of the tile | `shell-set sensor.title Air quality` |
| `sensor.unit` | `ppm` | Text (Format geprüft) | Unit shown after the value | `shell-set sensor.unit ppm` |
| `sensor.warn` | `1000` | Zahl 0 … 100000, Schritt 1 | From this value on, the tile shows the warning color | `shell-set sensor.warn 1001` |

## integrations – integrations

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `integrations.ca_file` | `""` | Text (Format geprüft) | Certificate of your own certificate authority for self-signed servers (checking is never switched off) | `shell-set integrations.ca_file ` |

## keybinds – Tastenkürzel

| Schlüssel | Standard | Erlaubt | Erklärung | Beispiel |
| --- | --- | --- | --- | --- |
| `keybinds.terminal` | `SUPER + Return` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the terminal (apps.terminal) | `shell-set keybinds.terminal "SUPER + B"` |
| `keybinds.files` | `SUPER + E` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the file manager (apps.files) | `shell-set keybinds.files "SUPER + B"` |
| `keybinds.browser` | `""` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the browser (apps.browser); empty = no key | `shell-set keybinds.browser "SUPER + B"` |
| `keybinds.launcher` | `SUPER + R` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the app launcher (apps.launcher) | `shell-set keybinds.launcher "SUPER + B"` |
| `keybinds.launcher_alt` | `ALT + Space` | Tasten wie `SUPER + Q`, leer = keine Taste | Another key for the app launcher | `shell-set keybinds.launcher_alt "SUPER + B"` |
| `keybinds.launcher_space` | `SUPER + Space` | Tasten wie `SUPER + Q`, leer = keine Taste | Third shortcut for the launcher | `shell-set keybinds.launcher_space "SUPER + B"` |
| `keybinds.launcher_search` | `CTRL + SUPER + Return` | Tasten wie `SUPER + Q`, leer = keine Taste | Open the app launcher to search apps | `shell-set keybinds.launcher_search "SUPER + B"` |
| `keybinds.close` | `SUPER + Q` | Tasten wie `SUPER + Q`, leer = keine Taste | Close the focused window (like clicking its X) | `shell-set keybinds.close "SUPER + B"` |
| `keybinds.close_alt` | `SUPER + C` | Tasten wie `SUPER + Q`, leer = keine Taste | Second key to close the focused window | `shell-set keybinds.close_alt "SUPER + B"` |
| `keybinds.float` | `SUPER + V` | Tasten wie `SUPER + Q`, leer = keine Taste | Switch the focused window between floating and tiled | `shell-set keybinds.float "SUPER + B"` |
| `keybinds.fullscreen` | `SUPER + F` | Tasten wie `SUPER + Q`, leer = keine Taste | Fullscreen on/off for the focused window | `shell-set keybinds.fullscreen "SUPER + B"` |
| `keybinds.minimize` | `SUPER + M` | Tasten wie `SUPER + Q`, leer = keine Taste | Hide the window (it stays in the dock and in ALT + Tab) | `shell-set keybinds.minimize "SUPER + B"` |
| `keybinds.restore` | `SUPER + SHIFT + M` | Tasten wie `SUPER + Q`, leer = keine Taste | Bring back the window minimized last | `shell-set keybinds.restore "SUPER + B"` |
| `keybinds.switcher` | `ALT + Tab` | Tasten wie `SUPER + Q`, leer = keine Taste | Hold the modifier and press Tab: next window, release to switch; Esc cancels, Q or Delete closes the chosen window | `shell-set keybinds.switcher "SUPER + B"` |
| `keybinds.switcher_back` | `ALT + SHIFT + Tab` | Tasten wie `SUPER + Q`, leer = keine Taste | Like Switch windows, in the other direction | `shell-set keybinds.switcher_back "SUPER + B"` |
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
| `keybinds.dock_focus` | `SUPER + B` | Tasten wie `SUPER + Q`, leer = keine Taste | Use the dock with the keyboard: arrows choose, Enter starts, Menu or SHIFT+F10 opens the menu, Esc leaves | `shell-set keybinds.dock_focus "SUPER + B"` |
| `keybinds.missa_chat` | `SUPER + I` | Tasten wie `SUPER + Q`, leer = keine Taste | Chat with Missa (only when Missa is switched on) | `shell-set keybinds.missa_chat "SUPER + B"` |
| `keybinds.missa_voice` | `SUPER + SHIFT + I` | Tasten wie `SUPER + Q`, leer = keine Taste | Speak with Missa; press again to stop (only when Missa and talking are switched on) | `shell-set keybinds.missa_voice "SUPER + B"` |
| `keybinds.emergency` | `CTRL + SUPER + Escape` | Tasten wie `SUPER + Q` (nicht leer) | Emergency: closes all shell panels, leaves the dock keyboard mode and any submap, focuses the window under the mouse | `shell-set keybinds.emergency "SUPER + B"` |
| `keybinds.lock` | `SUPER + L` | Tasten wie `SUPER + Q`, leer = keine Taste | Lock the screen | `shell-set keybinds.lock "SUPER + B"` |
| `keybinds.exit` | `CTRL + SUPER + M` | Tasten wie `SUPER + Q`, leer = keine Taste | Leave Hyprland | `shell-set keybinds.exit "SUPER + B"` |
| `keybinds.screenshot_region` | `Print` | Tasten wie `SUPER + Q`, leer = keine Taste | Select a region; saved and copied | `shell-set keybinds.screenshot_region "SUPER + B"` |
| `keybinds.screenshot_screen` | `SHIFT + Print` | Tasten wie `SUPER + Q`, leer = keine Taste | Whole screen; saved and copied | `shell-set keybinds.screenshot_screen "SUPER + B"` |
| `keybinds.custom` | `[]` | Liste von Einträgen mit `keys`, `command` | Own key combinations that run a command | `shell-set keybinds.custom '[{"keys":"SUPER + B","command":"firefox"}]'` |

