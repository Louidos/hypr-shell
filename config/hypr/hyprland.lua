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
        rounding = 12,
        blur = { enabled = true, size = 10, passes = 3 },
        shadow = true,
        opacity = { inactive = 1.0 },
        animations = { enabled = true, speed = "normal" },
    },
    theme = { cursor = { name = "Bibata-Modern-Ice", size = 24 } },
    input = {
        layout = "us", variant = "", sensitivity = 0,
        touchpad = { natural_scroll = false, tap_to_click = true },
    },
    monitors = { scale = "auto", outputs = {} },
    apps = { terminal = "kitty", files = "nautilus", browser = "firefox", launcher = "rofi -show drun" },
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
-- Einträge in monitors.outputs gelten für einzelne Bildschirme
local function leer(v) return v == nil or v == "" or v == "auto" end
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
        })
    end
end

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(bin .. "shell-wallpaper --restore")
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd(bin .. "shell-quickshell")
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

hl.config({
    general = {
        gaps_in     = S.look.gaps.inner,
        gaps_out    = S.look.gaps.outer,
        border_size = S.look.border,
        col = {
            active_border   = colors.accent,
            inactive_border = colors.inactive,
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = S.look.rounding,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = S.look.opacity.inactive,

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
blur_layer("hypr-shell-quickshell",  "^hypr-shell-(desktop|dashboard|panel)$")
blur_layer("hypr-shell-rofi",        "^rofi$")
blur_layer("hypr-shell-swaync-cc",   "^swaync-control-center$")
blur_layer("hypr-shell-swaync-note", "^swaync-notification-window$")
blur_layer("hypr-shell-swayosd",     "^swayosd$")

hl.layer_rule({ name = "hypr-shell-slurp", match = { namespace = "^selection$" }, no_anim = true })

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

local mod = "SUPER"
local terminal    = S.apps.terminal
local fileManager = S.apps.files
local launcher    = S.apps.launcher

hl.bind(mod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + R", hl.dsp.exec_cmd(launcher))
hl.bind("ALT + Space", hl.dsp.exec_cmd(launcher))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))

-- Fokus mit SUPER + Pfeiltasten
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Arbeitsflächen: SUPER + 1…0 wechseln, SUPER + SHIFT + 1…0 Fenster verschieben
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- SUPER + linke Maustaste ziehen, SUPER + rechte Maustaste Grösse ändern
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Oberfläche (Quickshell): Dashboard und Panel; SUPER + W öffnet direkt den Tab Wallpaper
local ui = bin .. "shell-quickshell ipc "
hl.bind(mod .. " + ALT + D", hl.dsp.exec_cmd(ui .. "dashboard toggle"))
hl.bind(mod .. " + W",       hl.dsp.exec_cmd(ui .. "dashboard open wallpaper"))
-- Hot-Corner-Panel (auch: Maus in die Ecke unten rechts)
hl.bind(mod .. " + A",       hl.dsp.exec_cmd(ui .. "panel toggle"))

-- Screenshots: speichern und in die Zwischenablage
hl.bind("Print",         hl.dsp.exec_cmd(bin .. "shell-screenshot region"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(bin .. "shell-screenshot screen"))

-- Lautstärke und Helligkeit (mit Anzeige von swayosd), auch im Sperrbildschirm
local osd = "swayosd-client "
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(osd .. "--output-volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(osd .. "--output-volume lower"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(osd .. "--output-volume mute-toggle"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(osd .. "--input-volume mute-toggle"),  { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(osd .. "--brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osd .. "--brightness lower"), { locked = true, repeating = true })

-- Medientasten
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-------------------------------
---- WEITERE TEILE, ZULETZT ----
-------------------------------

-- Teile späterer Ausbaustufen (Dashboard, Panel, …) legen hier ihre Datei ab
optional("hypr-shell-extra")

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
