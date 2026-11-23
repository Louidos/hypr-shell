-- hypr-shell: Hyprland-Konfiguration (Lua, Hyprland ab 0.55)
-- Wird von install.sh nach ~/.config/hypr/hyprland.lua kopiert.
-- Eigene Änderungen gehören nach ~/.config/hypr/user.lua (wird nie überschrieben).
-- Doku: https://wiki.hypr.land/configuring/

local home = os.getenv("HOME")
local bin  = home .. "/.local/bin/"

-- optionale Teildateien: fehlt eine, wird sie übersprungen statt die Konfiguration zu brechen
local function optional(name)
    package.loaded[name] = nil
    local ok, err = pcall(require, name)
    if not ok and not tostring(err):find("not found", 1, true) then
        print("hypr-shell: " .. name .. ": " .. tostring(err))
    end
end

-- Teildatei frisch laden (auch nach "hyprctl reload" den neuen Stand, nicht den zwischengespeicherten)
local function frisch(name)
    package.loaded[name] = nil
    return pcall(require, name)
end

-- Farben aus dem Hintergrundbild (matugen schreibt hypr-shell-colors.lua)
local colors = { accent = "rgba(d4d4d4ee)", inactive = "rgba(59595966)" }
do
    local ok, c = frisch("hypr-shell-colors")
    if ok and type(c) == "table" then colors = c end
end

-- Einstellungen: Standardwerte (gleich wie settings/schema.json), darunter die alte
-- hypr-shell-local.lua (v1.1), darüber hypr-shell-settings.lua (von shell-apply aus
-- ~/.config/hypr-shell/settings.json erzeugt). Fehlt eine Datei, gelten die Werte darunter.
local S = {
    look = {
        gaps = { inner = 6, outer = 12 },
        border = 1,
        rounding = 14,
        blur = { enabled = true, size = 10, passes = 3 },
        shadow = true,
        opacity = { active = 0.95, inactive = 0.88,
            exceptions = { "steam_app_[0-9]+", "gamescope", "steam", "battle.net.exe", "heroic", "lutris", "mpv", "vlc",
                "celluloid", "org.gnome.Totem", "gimp", "krita", "inkscape", "darktable", "org.kde.kdenlive", "blender" } },
        border_color = "white",
        animations = { enabled = true, speed = "normal" },
    },
    theme = { cursor = { name = "Bibata-Modern-Ice", size = 24 }, apps = { gtk = true, qt = true },
        border = { color = "#ffffff", opacity = 0.35, opacity_inactive = 0.15, width = 1 } },
    input = {
        layout = "us", variant = "", sensitivity = 0,
        touchpad = { natural_scroll = false, tap_to_click = true },
    },
    monitors = { scale = "auto", outputs = {} },
    fenster = { titelleiste = "an", knoepfe = { stil = "windows", seite = "auto" },
        titelleiste_ausnahmen = { "org.gnome.*", "firefox", "chromium", "google-chrome", "code", "code-oss", "vesktop",
            "discord", "steam", "steam_app_[0-9]+", "gamescope", "mpv", "vlc", "celluloid" } },
    apps = { terminal = "kitty", files = "nautilus", browser = "firefox", launcher = "builtin" },
    keybinds = {
        terminal = "SUPER + Return", files = "SUPER + E", browser = "", launcher = "SUPER + R",
        launcher_alt = "ALT + Space", launcher_space = "SUPER + Space", launcher_search = "CTRL + SUPER + Return",
        close = "SUPER + Q", close_alt = "SUPER + C", float = "SUPER + V", fullscreen = "SUPER + F",
        minimize = "SUPER + M", restore = "SUPER + SHIFT + M", switcher = "ALT + Tab", switcher_back = "ALT + SHIFT + Tab",
        focus_left = "SUPER + left", focus_right = "SUPER + right", focus_up = "SUPER + up", focus_down = "SUPER + down",
        workspace_mod = "SUPER", move_mod = "SUPER + SHIFT", mouse_mod = "SUPER",
        dashboard = "SUPER + ALT + D", dashboard_alt = "SUPER + D", wallpaper = "SUPER + W", panel = "SUPER + A", notifications = "SUPER + N", edit_desktop = "SUPER + ALT + W",
        settings = "SUPER + U", power = "SUPER + Escape", clipboard = "SUPER + SHIFT + V", overview = "SUPER + Tab", cheatsheet = "SUPER + F1", missa_chat = "SUPER + I", missa_voice = "SUPER + SHIFT + I", dock_focus = "SUPER + B", emergency = "CTRL + SUPER + Escape",
        lock = "SUPER + L", exit = "CTRL + SUPER + M", screenshot_region = "Print", screenshot_screen = "SHIFT + Print",
        custom = {},
    },
}
local function merge(a, b)
    for k, v in pairs(b) do
        if type(v) == "table" and type(a[k]) == "table" and #v == 0 and next(v) ~= nil then merge(a[k], v)
        else a[k] = v end
    end
    return a
end
do
    local ok, c = frisch("hypr-shell-local")
    if ok and type(c) == "table" then
        merge(S, {
            input = {
                layout = c.kb_layout, variant = c.kb_variant,
                touchpad = { natural_scroll = c.natural_scroll, tap_to_click = c.tap_to_click },
            },
            monitors = { scale = c.scale ~= nil and tostring(c.scale) or nil },
        })
    end
    local ok2, s = frisch("hypr-shell-settings")
    if ok2 and type(s) == "table" then merge(S, s) end
end
optional("hypr-shell-env")

------------------
---- MONITORE ----
------------------

-- jeder Bildschirm mit seiner bevorzugten Auflösung, automatisch angeordnet (monitors.scale);
-- Einträge in monitors.outputs gelten für einzelne Bildschirme. Gibt es einen Bildschirm nicht,
-- bleibt sein Eintrag ohne Wirkung.
local function leer(v) return v == nil or v == "" or v == "auto" end
-- Drehung (monitors.outputs[].transform) → Zahl für Hyprland (wl_output_transform 0–7):
-- normal 0, 90 1, 180 2, 270 3, flipped 4, flipped-90 5, flipped-180 6, flipped-270 7.
-- Ein Eintrag ohne Drehung (vor 1.9) gilt als normal.
local DREHUNG = { normal = 0, ["90"] = 1, ["180"] = 2, ["270"] = 3,
    flipped = 4, ["flipped-90"] = 5, ["flipped-180"] = 6, ["flipped-270"] = 7 }
local function drehung(v)
    if type(v) == "number" and v >= 0 and v <= 7 and v == math.floor(v) then return math.floor(v) end
    return DREHUNG[tostring(v or "normal")] or 0
end
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = tostring(S.monitors.scale or "auto"),
})
for _, m in ipairs(S.monitors.outputs or {}) do
    if type(m) == "table" and type(m.name) == "string" and m.name ~= "" then
        local mode = "preferred"
        if not leer(m.resolution) then
            mode = m.resolution
            if tonumber(m.refresh) and tonumber(m.refresh) > 0 then mode = mode .. "@" .. tostring(m.refresh) end
        end
        hl.monitor({
            output   = m.name,
            mode     = mode,
            position = leer(m.position) and "auto" or m.position,
            scale    = (m.scale == nil or m.scale == "") and tostring(S.monitors.scale or "auto") or tostring(m.scale),
            transform = drehung(m.transform),
        })
    end
end

-- Touchscreen und Stift drehen mit dem gedrehten Bildschirm mit (der eingebaute zuerst). Nur, wenn
-- es ein solches Gerät gibt: direkt auf dem Bildschirm bediente Geräte (INPUT_PROP_DIRECT) in
-- /proc/bus/input/devices; Namen mit Pen, Stylus oder Wacom gelten als Stift. Sonst nichts.
local function direkte_geraete()
    local f = io.open(os.getenv("HYPR_SHELL_INPUT_DEVICES") or "/proc/bus/input/devices", "r")
    if not f then return false, false end
    local touch, stift, name = false, false, ""
    for zeile in f:lines() do
        local n = zeile:match('^N: Name="(.*)"')
        if n then name = n:lower() end
        local p = zeile:match("^B: PROP=(%x+)")
        if p and ((tonumber(p, 16) or 0) & 2) ~= 0 then
            if name:find("pen", 1, true) or name:find("stylus", 1, true) or name:find("wacom", 1, true) then stift = true
            else touch = true end
        end
    end
    f:close()
    return touch, stift
end
do
    local gedreht
    for _, m in ipairs(S.monitors.outputs or {}) do
        if type(m) == "table" and type(m.name) == "string" and m.name ~= "" and drehung(m.transform) ~= 0 then
            local eingebaut = m.name:match("^eDP") or m.name:match("^LVDS") or m.name:match("^DSI")
            if not gedreht or (eingebaut and not gedreht.eingebaut) then gedreht = { name = m.name, t = drehung(m.transform), eingebaut = eingebaut } end
        end
    end
    if gedreht then
        local touch, stift = direkte_geraete()
        local input = {}
        if touch then input.touchdevice = { transform = gedreht.t, output = gedreht.name } end
        if stift then input.tablet = { transform = gedreht.t, output = gedreht.name } end
        if next(input) then hl.config({ input = input }) end
    end
end

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(bin .. "shell-wallpaper --restore")
    -- Leiste über den Wächter: stürzt sie ab, startet sie von selbst neu (höchstens 5-mal in 2 Minuten)
    hl.exec_cmd(bin .. "shell-waechter waybar -- waybar")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(bin .. "shell-quickshell")
    -- Titelleiste mit Fenster-Knöpfen: hyprbars über hyprpm laden (fehlt es: Hinweis, sonst nichts)
    hl.exec_cmd(bin .. "shell-window titlebar")
    -- Verlauf der Zwischenablage (nur mit clipboard.enabled, prüft shell-clipboard selbst)
    hl.exec_cmd(bin .. "shell-clipboard daemon")
    -- Laptop: eingestellte Ladegrenze und Tastaturlicht anwenden (Standard: nichts ändern)
    hl.exec_cmd(bin .. "shell-laptop apply")
    -- Ordner der Anbindungen (Nextcloud, Missa) nach den Einstellungen; alles aus = nichts passiert
    hl.exec_cmd(bin .. "shell-mount sync")
    -- Missa-Agent nur, wenn eingeschaltet (startet sonst nichts)
    hl.exec_cmd(bin .. "shell-missa-agent sync")
end)

------------------------------
---- UMGEBUNGSVARIABLEN ----
------------------------------

hl.env("XCURSOR_THEME", S.theme.cursor.name)
hl.env("XCURSOR_SIZE", tostring(S.theme.cursor.size))
hl.env("HYPRCURSOR_THEME", S.theme.cursor.name)
hl.env("HYPRCURSOR_SIZE", tostring(S.theme.cursor.size))
-- Standard-Browser für Programme, die $BROWSER lesen (apps.browser)
hl.env("BROWSER", S.apps.browser)

------------------
---- AUSSEHEN ----
------------------

-- Fensterrand: fein weiss wie Glas (theme.border.*) oder in der Farbe des Hintergrundbilds
-- (look.border_color = accent)
local function rgba(hex, alpha)
    local h = tostring(hex or "#ffffff"):gsub("^#", "")
    if not h:match("^%x%x%x%x%x%x$") then h = "ffffff" end
    local a = math.floor(math.max(0, math.min(1, tonumber(alpha) or 1)) * 255 + 0.5)
    return string.format("rgba(%s%02x)", h:lower(), a)
end
local B = (S.theme and S.theme.border) or {}
local rand_aktiv, rand_inaktiv = colors.accent, colors.inactive
if S.look.border_color ~= "accent" then
    rand_aktiv   = rgba(B.color, B.opacity or 0.35)
    rand_inaktiv = rgba(B.color, B.opacity_inactive or 0.15)
end

hl.config({
    general = {
        gaps_in     = S.look.gaps.inner,
        gaps_out    = S.look.gaps.outer,
        border_size = S.look.border,
        col = {
            active_border   = rand_aktiv,
            inactive_border = rand_inaktiv,
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = S.look.rounding,
        rounding_power = 2,
        active_opacity   = S.look.opacity.active or 1.0,
        inactive_opacity = S.look.opacity.inactive,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = S.look.shadow,
            range        = 14,
            render_power = 3,
            color        = 0x661a1a1a,
        },

        blur = {
            enabled  = S.look.blur.enabled,
            size     = S.look.blur.size,
            passes   = S.look.blur.passes,
            noise    = 0.02,
            vibrancy = 0.17,
            popups   = true,
        },
    },

    animations = {
        enabled = S.look.animations.enabled,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    input = {
        kb_layout    = S.input.layout,
        kb_variant   = S.input.variant,
        follow_mouse = 1,
        sensitivity  = S.input.sensitivity,
        touchpad = {
            natural_scroll = S.input.touchpad.natural_scroll == true,
            tap_to_click   = S.input.touchpad.tap_to_click ~= false,
        },
    },

    -- XWayland-Programme (Steam, Battle.net, GOG-Spiele) nicht hochskalieren: bei Skalierung über 1
    -- bleiben sie scharf statt verwaschen (Wiki: Configuring > Xwayland > HiDPI Xwayland)
    xwayland = {
        force_zero_scaling = true,
    },
})

-- weiche Animationen (Kurven nach Augenmass an die Vorlage angelehnt)
hl.curve("smooth", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("quick",  { type = "bezier", points = { { 0.15, 0.85 }, { 0.25, 1.0 } } })
hl.curve("linear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })

-- Tempo aus look.animations.speed: slow / normal / fast (Hyprland: grössere Zahl = langsamer)
local tempo = ({ slow = 1.6, normal = 1.0, fast = 0.6 })[S.look.animations.speed] or 1.0
local function anim(leaf, speed, bezier, style)
    local v = math.floor(speed * tempo * 10 + 0.5) / 10
    v = (math.tointeger and math.tointeger(v)) or v   -- ganze Zahlen als Ganzzahl übergeben
    hl.animation({ leaf = leaf, enabled = true, speed = v, bezier = bezier, style = style })
end
anim("windows",     4, "smooth", "popin 90%")
anim("windowsOut",  3, "quick",  "popin 90%")
anim("windowsMove", 3, "smooth")
anim("border",      6, "linear")
anim("fade",        4, "smooth")
anim("layers",      3, "quick",  "fade")
anim("workspaces",  5, "smooth", "slidefade 15%")

-- Wischen mit drei Fingern wechselt die Arbeitsfläche
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-------------------------------------------
---- BLUR HINTER LEISTE UND OBERFLÄCHE ----
-------------------------------------------

local function blur_layer(name, namespace, alpha)
    hl.layer_rule({
        name         = name,
        match        = { namespace = namespace },
        blur         = true,
        ignore_alpha = alpha or 0.1,
    })
end

blur_layer("hypr-shell-waybar",      "^waybar$")
-- Quickshell-Flächen mit Glas; die grosse Uhr (hypr-shell-clock) bleibt ohne Blur
blur_layer("hypr-shell-quickshell",  "^hypr-shell-(desktop|dashboard|panel|settings|launcher|notifications|osd|power|clipboard|overview|cheatsheet)$")
blur_layer("hypr-shell-rofi",        "^rofi$")
-- Dock: eigene Regel; Schatten und durchsichtige Ränder (unter 30 % Deckkraft) bleiben ohne Blur.
-- Mit dock.blur = false gibt es die Regel nicht (kein Blur hinter dem Dock).
if not (S.dock ~= nil and S.dock.blur == false) then
    blur_layer("hypr-shell-dock",    "^hypr-shell-dock$", 0.3)
end

hl.layer_rule({ name = "hypr-shell-slurp", match = { namespace = "^selection$" }, no_anim = true })

-- immer undurchsichtig: Spiele, Videos, Bildbearbeitung (look.opacity.exceptions); Vollbild ohnehin
-- (fullscreen_opacity = 1)
do
    local l = {}
    for _, c in ipairs(S.look.opacity.exceptions or {}) do
        if type(c) == "string" and c ~= "" then l[#l + 1] = c end
    end
    if #l > 0 then
        hl.window_rule({
            name    = "hypr-shell-opaque",
            match   = { class = "^(" .. table.concat(l, "|") .. ")$" },
            opacity = "1.0 override 1.0 override",
        })
    end
end

------------------------------
---- TITELLEISTE (hyprbars) ----
------------------------------

-- Schmale Glas-Titelleiste mit drei Knöpfen (offizielles Plugin hyprbars aus hyprland-plugins).
-- Ein Paket legt das Plugin unter einem festen Pfad ab, sonst lädt hyprpm es beim Start
-- (shell-window titlebar). Fehlt es, läuft alles ohne Knöpfe weiter: es gibt hl.plugin.hyprbars
-- dann nicht und nichts hier wird ausgeführt (keine Fehlermeldung von Hyprland).
local F = S.fenster or {}
if F.titelleiste ~= "aus" and hl.plugin and hl.plugin.load then
    for _, pfad in ipairs({ "/usr/lib/hyprland-plugins/hyprbars.so", "/usr/lib/hyprland-plugins/libhyprbars.so",
                            "/usr/lib/hyprland/plugins/hyprbars.so", "/usr/lib/hyprbars.so" }) do
        local f = io.open(pfad, "r")
        if f then f:close(); pcall(hl.plugin.load, pfad); break end
    end
end
if F.titelleiste ~= "aus" and hl.plugin and hl.plugin.hyprbars then
    local stil = (F.knoepfe or {}).stil == "mac" and "mac" or "windows"
    local seite = (F.knoepfe or {}).seite
    if seite ~= "rechts" and seite ~= "links" then seite = stil == "mac" and "links" or "rechts" end
    local T = S.theme or {}
    local glas_farbe = (T.glass_color or "#2a2a2f"):gsub("^#", "")
    local hyprctl = "hyprctl dispatch "
    local maximieren = hyprctl .. [['hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']]
    hl.config({
        plugin = {
            hyprbars = {
                enabled = true,
                bar_height = 28,
                bar_color = rgba(glas_farbe, math.max(0.55, tonumber(T.glass) or 0.55)),
                col = { text = "rgba(e6e6e6ff)" },
                bar_text_font = (T.font and T.font.ui) or "Inter",
                bar_text_size = 11,
                bar_text_weight = "medium",
                bar_text_align = stil == "mac" and "center" or "left",
                bar_buttons_alignment = seite == "links" and "left" or "right",
                bar_padding = 12,
                bar_button_padding = 8,
                bar_blur = true,
                bar_part_of_window = true,
                bar_precedence_over_border = true,
                icon_on_hover = stil == "mac",
                on_double_click = maximieren,
            },
        },
    })
    -- Knöpfe (das Plugin legt sie von aussen nach innen an): Schliessen, Maximieren, Minimieren
    local knoepfe = {
        { farbe = stil == "mac" and "rgb(ff5f57)" or "rgba(e8112366)", symbol = stil == "mac" and "×" or "󰖭",
          aktion = hyprctl .. "'hl.dsp.window.close()'" },
        { farbe = stil == "mac" and "rgb(28c840)" or "rgba(ffffff1f)", symbol = stil == "mac" and "+" or "󰖯", aktion = maximieren },
        { farbe = stil == "mac" and "rgb(febc2e)" or "rgba(ffffff1f)", symbol = stil == "mac" and "−" or "󰖰",
          aktion = bin .. "shell-window minimize" },
    }
    for _, k in ipairs(knoepfe) do
        hl.plugin.hyprbars.add_button({ bg_color = k.farbe, fg_color = stil == "mac" and "rgb(3a3a3a)" or "rgb(e6e6e6)",
                                        size = stil == "mac" and 12 or 16, icon = k.symbol, action = k.aktion })
    end
    -- keine Titelleiste: Programme mit eigener (CSD) und Spiele/Videos (Liste), Vollbild, Dialoge,
    -- Spiele und Videos laut Inhaltstyp; bei "nur-schwebend" auch keine bei gekachelten Fenstern
    local l = {}
    for _, c in ipairs(S.fenster.titelleiste_ausnahmen or {}) do if type(c) == "string" and c ~= "" then l[#l + 1] = c end end
    local function ohne(name, match) hl.window_rule({ name = name, match = match, ["hyprbars:no_bar"] = true }) end
    if #l > 0 then ohne("hypr-shell-bar-ausnahmen", { class = "^(" .. table.concat(l, "|") .. ")$" }) end
    ohne("hypr-shell-bar-vollbild", { fullscreen = true })
    ohne("hypr-shell-bar-dialog", { modal = true })
    ohne("hypr-shell-bar-spiel", { content = "game" })
    ohne("hypr-shell-bar-video", { content = "video" })
    if F.titelleiste == "nur-schwebend" then ohne("hypr-shell-bar-gekachelt", { float = false }) end
end

-- schwebende Hilfsfenster mittig
hl.window_rule({
    name  = "hypr-shell-float-tools",
    match = { class = "^(org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk)$" },
    float  = true,
    center = true,
    size   = "900 620",
})

------------------------
---- TASTENKÜRZEL ----
------------------------

-- Alle Kürzel aus settings.json (keybinds.*); Standard = die bisherigen Kürzel. Ein leerer Wert
-- heisst: diese Aktion hat keine Taste. Doppelte Belegungen lässt shell-apply gar nicht erst durch.
local K = S.keybinds
local terminal    = S.apps.terminal
local fileManager = S.apps.files
local browser     = S.apps.browser
-- apps.launcher = "builtin": der Starter von hypr-shell (Quickshell), sonst der eigene Befehl (z. B. rofi)
local launcher    = (S.apps.launcher == "builtin" or S.apps.launcher == nil or S.apps.launcher == "")
    and (bin .. "shell-quickshell ipc launcher toggle") or S.apps.launcher
-- desc = "Gruppe: Aktion" (Gruppen Windows, Workspaces, Apps, Panels, Missa, Screenshots, System,
-- Custom): steht in "hyprctl binds -j" und im Kürzel-Spickzettel (SUPER + F1)
local function bind(keys, action, desc, flags)
    if type(keys) == "string" and keys ~= "" then
        local f = { description = desc }
        for k, v in pairs(flags or {}) do f[k] = v end
        hl.bind(keys, action, f)
    end
end
local function mit(m, key) return (m ~= nil and m ~= "") and (m .. " + " .. key) or "" end

bind(K.terminal,     hl.dsp.exec_cmd(terminal), "Apps: Terminal")
bind(K.close,        hl.dsp.window.close(), "Windows: Close window")
bind(K.close_alt,    hl.dsp.window.close(), "Windows: Close window")
bind(K.files,        hl.dsp.exec_cmd(fileManager), "Apps: File manager")
bind(K.browser,      hl.dsp.exec_cmd(browser), "Apps: Browser")
bind(K.launcher,     hl.dsp.exec_cmd(launcher), "Panels: Launcher")
bind(K.launcher_alt, hl.dsp.exec_cmd(launcher), "Panels: Launcher")
bind(K.launcher_space, hl.dsp.exec_cmd(launcher), "Panels: Launcher")
bind(K.launcher_search, hl.dsp.exec_cmd(launcher), "Panels: App search")
bind(K.float,        hl.dsp.window.float({ action = "toggle" }), "Windows: Floating / tiled")
bind(K.fullscreen,   hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "Windows: Fullscreen")
bind(K.minimize,     hl.dsp.exec_cmd(bin .. "shell-window minimize"), "Windows: Minimize")
bind(K.restore,      hl.dsp.exec_cmd(bin .. "shell-window restore"), "Windows: Restore last minimized")
bind(K.exit,         hl.dsp.exit(), "System: Log out (quit Hyprland)")
bind(K.lock,         hl.dsp.exec_cmd("pidof hyprlock || hyprlock"), "System: Lock screen")

-- Fokus mit SUPER + Pfeiltasten
bind(K.focus_left,  hl.dsp.focus({ direction = "left" }), "Windows: Focus left")
bind(K.focus_right, hl.dsp.focus({ direction = "right" }), "Windows: Focus right")
bind(K.focus_up,    hl.dsp.focus({ direction = "up" }), "Windows: Focus up")
bind(K.focus_down,  hl.dsp.focus({ direction = "down" }), "Windows: Focus down")

-- Arbeitsflächen: SUPER + 1…0 wechseln, SUPER + SHIFT + 1…0 Fenster verschieben
for i = 1, 10 do
    local key = i % 10
    bind(mit(K.workspace_mod, key), hl.dsp.focus({ workspace = i }), "Workspaces: Go to workspace " .. i)
    bind(mit(K.move_mod, key),      hl.dsp.window.move({ workspace = i }), "Workspaces: Move window to workspace " .. i)
end
bind(mit(K.workspace_mod, "mouse_down"), hl.dsp.focus({ workspace = "e+1" }), "Workspaces: Next workspace")
bind(mit(K.workspace_mod, "mouse_up"),   hl.dsp.focus({ workspace = "e-1" }), "Workspaces: Previous workspace")

-- SUPER + linke Maustaste ziehen, SUPER + rechte Maustaste Grösse ändern
bind(mit(K.mouse_mod, "mouse:272"), hl.dsp.window.drag(),   "Windows: Move window (drag)", { mouse = true })
bind(mit(K.mouse_mod, "mouse:273"), hl.dsp.window.resize(), "Windows: Resize window (drag)", { mouse = true })

-- Oberfläche (Quickshell): Dashboard, Panel, Einstellungs-App; SUPER + W öffnet den Tab Wallpaper.
-- Es ist immer nur ein Panel offen: öffnet man eines, schliesst das andere.
local ui = bin .. "shell-quickshell ipc "
bind(K.dashboard, hl.dsp.exec_cmd(ui .. "dashboard toggle"), "Panels: Dashboard")
bind(K.dashboard_alt, hl.dsp.exec_cmd(ui .. "dashboard toggle"), "Panels: Dashboard")
bind(K.wallpaper, hl.dsp.exec_cmd(ui .. "dashboard open wallpaper"), "Panels: Wallpapers")
bind(K.panel,     hl.dsp.exec_cmd(ui .. "panel toggle"), "Panels: Quick panel")
bind(K.notifications, hl.dsp.exec_cmd(ui .. "notifications toggle"), "Panels: Notifications")
-- Desktop-Widgets mit der Maus verschieben und skalieren
bind(K.edit_desktop, hl.dsp.exec_cmd(ui .. "desktop edit"), "System: Move desktop widgets")
-- die App bleibt immer erreichbar: ohne gültige Taste gilt SUPER + U
bind((K.settings ~= nil and K.settings ~= "") and K.settings or "SUPER + U", hl.dsp.exec_cmd(ui .. "settings toggle"), "Panels: Settings")

-- Missa: nur mit missa.enabled belegt – ausgeschaltet tut das Kürzel still nichts (und steht nicht im
-- Spickzettel)
local missa_an = S.missa ~= nil and S.missa.enabled == true
local function programm(name)
    for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
        local f = io.open(dir .. "/" .. name, "r")
        if f then f:close(); return true end
    end
    return false
end
if missa_an then
    bind(K.missa_chat, hl.dsp.exec_cmd(ui .. "missa toggle"), "Missa: Chat with Missa")
    -- mit Missa sprechen: nur mit missa.voice_enabled und whisper.cpp (sonst fehlt die Taste)
    if S.missa.voice_enabled == true and programm("whisper-cli") then
        bind(K.missa_voice, hl.dsp.exec_cmd(ui .. "missa voice"), "Missa: Talk to Missa")
    end
end

-- Qt-Programme mit den Farben des Hintergrundbilds (theme.apps.qt, über qt6ct); wer selbst schon ein
-- Plattform-Thema gesetzt hat, behält es
if S.theme.apps ~= nil and S.theme.apps.qt == true and os.getenv("QT_QPA_PLATFORMTHEME") == nil and programm("qt6ct") then
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
end

-- Kürzel-Spickzettel
bind(K.cheatsheet, hl.dsp.exec_cmd(ui .. "cheatsheet toggle"), "Panels: Keyboard shortcuts")

-- Dock mit der Tastatur bedienen (nur wenn das Dock an ist)
if S.dock == nil or S.dock.enabled ~= false then
    bind(K.dock_focus, hl.dsp.exec_cmd(ui .. "dock focus"), "Panels: Focus the dock")
end

-- Notfall: Tastatur zurück (alle Panels zu, Dock-Tastatur-Modus und Submap aus, Fokus auf das
-- Fenster unter der Maus). Als Hyprland-Kürzel wirkt es auch, wenn eine Fläche die Tastatur hält,
-- und in jeder Submap (submap_universal).
bind(K.emergency, hl.dsp.exec_cmd(bin .. "shell-diag freigeben"), "System: Give back the keyboard (emergency)", { submap_universal = true })

-- ALT+Tab: Umschalter mit Vorschau (quickshell/switcher). Das Kürzel öffnet die Leiste und betritt die
-- Submap hypr-shell-switcher; dort wählt Tab weiter, Loslassen des Modifikators wechselt, Escape bricht
-- ab, Q/Entf schliesst. Escape und das Notfall-Kürzel führen immer hinaus; die Leiste selbst schliesst
-- nach 5 s ohne Taste und verlässt die Submap (nie hängen bleiben).
if (S.switcher == nil or S.switcher.enabled ~= false) and type(K.switcher) == "string" and K.switcher ~= "" then
    local sw = bin .. "shell-switcher "
    local mods = K.switcher:match("^(.*) %+ [^+]+$") or ""
    local loslassen = {}
    for m in mods:gmatch("[^ +]+") do
        local u = m:upper()
        local keys = ({ ALT = { "Alt_L", "Alt_R" }, SUPER = { "Super_L", "Super_R" }, CTRL = { "Control_L", "Control_R" },
                        CONTROL = { "Control_L", "Control_R" }, SHIFT = { "Shift_L", "Shift_R" } })[u] or {}
        for _, k in ipairs(keys) do loslassen[#loslassen + 1] = { mod = u, key = k } end
    end
    bind(K.switcher, hl.dsp.exec_cmd(sw .. "next"), "Windows: Switch windows")
    bind(K.switcher_back, hl.dsp.exec_cmd(sw .. "prev"), "Windows: Switch windows backwards")
    hl.define_submap("hypr-shell-switcher", function()
        bind(K.switcher, hl.dsp.exec_cmd(sw .. "next"), "Windows: Next window")
        bind(K.switcher_back, hl.dsp.exec_cmd(sw .. "prev"), "Windows: Previous window")
        for _, l in ipairs(loslassen) do
            bind(l.mod .. " + " .. l.key, hl.dsp.exec_cmd(sw .. "commit"), "Windows: Switch to the chosen window", { release = true })
            bind(l.key, hl.dsp.exec_cmd(sw .. "commit"), "Windows: Switch to the chosen window", { release = true })
        end
        local m = mods ~= "" and (mods .. " + ") or ""
        bind(m .. "right", hl.dsp.exec_cmd(sw .. "next"), "Windows: Next window")
        bind(m .. "left", hl.dsp.exec_cmd(sw .. "prev"), "Windows: Previous window")
        bind(m .. "Return", hl.dsp.exec_cmd(sw .. "commit"), "Windows: Switch to the chosen window")
        bind(m .. "Q", hl.dsp.exec_cmd(sw .. "close"), "Windows: Close the chosen window")
        bind(m .. "Delete", hl.dsp.exec_cmd(sw .. "close"), "Windows: Close the chosen window")
        bind(m .. "Escape", hl.dsp.exec_cmd(sw .. "cancel"), "Windows: Cancel switching")
        bind("Escape", hl.dsp.exec_cmd(sw .. "cancel"), "Windows: Cancel switching")
    end)
end

-- Fenster-Übersicht aller Arbeitsflächen
bind(K.overview, hl.dsp.exec_cmd(ui .. "overview toggle"), "Panels: Window overview")

-- Verlauf der Zwischenablage (SUPER + V bleibt "schwebend")
bind(K.clipboard, hl.dsp.exec_cmd(ui .. "clipboard toggle"), "Panels: Clipboard history")

-- Power-Menü (Lock, Sleep, Logout, Restart, Shutdown)
bind(K.power, hl.dsp.exec_cmd(ui .. "power toggle"), "System: Power menu")

-- Screenshots: speichern und in die Zwischenablage
bind(K.screenshot_region, hl.dsp.exec_cmd(bin .. "shell-screenshot region"), "Screenshots: Region")
bind(K.screenshot_screen, hl.dsp.exec_cmd(bin .. "shell-screenshot screen"), "Screenshots: Whole screen")

-- eigene Kürzel (keybinds.custom)
for _, c in ipairs(K.custom or {}) do
    if type(c) == "table" and type(c.command) == "string" and c.command ~= "" then
        bind(c.keys, hl.dsp.exec_cmd(c.command), "Custom: " .. c.command)
    end
end

-- Feste Tasten (nicht einstellbar): stehen auch als fixed_binds in settings/schema.json, damit shell-apply
-- eigene Kürzel darauf ablehnt; tests/tastenkuerzel.sh prüft, dass beide Listen gleich sind.
-- Lautstärke und Helligkeit mit der Glas-Anzeige von hypr-shell (shell-osd), auch im Sperrbildschirm
local osd = bin .. "shell-osd "
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(osd .. "volume up"),   { description = "System: Volume up", locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(osd .. "volume down"), { description = "System: Volume down", locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(osd .. "volume mute"), { description = "System: Mute", locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(osd .. "mic mute"),    { description = "System: Mute microphone", locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(osd .. "brightness up"),   { description = "System: Brightness up", locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osd .. "brightness down"), { description = "System: Brightness down", locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd(osd .. "kbd up"),   { description = "System: Keyboard light up", locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(osd .. "kbd down"), { description = "System: Keyboard light down", locked = true, repeating = true })

-- Medientasten
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { description = "System: Play / pause", locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { description = "System: Play / pause", locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { description = "System: Next track", locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { description = "System: Previous track", locked = true })

-------------------------------
---- WEITERE TEILE, ZULETZT ----
-------------------------------

-- Teile späterer Ausbaustufen (Dashboard, Panel, …) legen hier ihre Datei ab
optional("hypr-shell-extra")

-- Automatischer Gaming-Modus: geht ein Spiel in den Vollbildmodus, schaltet shell-games den
-- Gaming-Modus an und danach wieder aus (games.auto_gaming; ob es ein Spiel ist, entscheidet
-- games.auto_classes, Standard steam_app_… und gamescope)
local function sicher(s) return (tostring(s or ""):gsub("[^%w%._%-]", "_")) end
if not (S.games and S.games.auto_gaming == false) then
    hl.on("window.fullscreen", function(w)
        if not w then return end
        hl.exec_cmd(bin .. "shell-games auto fullscreen " .. sicher(w.fullscreen) .. " "
            .. sicher(w.class) .. " " .. sicher(w.address))
    end)
    hl.on("window.close", function(w)
        if not w then return end
        hl.exec_cmd(bin .. "shell-games auto close " .. sicher(w.address))
    end)
end

-- eigene Anpassungen des Benutzers
optional("user")

-- Gaming-Modus bleibt auch nach "hyprctl reload" aktiv
do
    local ok, f = pcall(io.open, home .. "/.local/share/hypr-shell/gaming", "r")
    if ok and f then
        f:close()
        hl.config({
            decoration = { blur = { enabled = false }, shadow = { enabled = false } },
            animations = { enabled = false },
        })
    end
end
