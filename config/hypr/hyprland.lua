-- hypr-shell: Hyprland-Konfiguration (Lua, Hyprland ab 0.55)
-- Wird von install.sh nach ~/.config/hypr/hyprland.lua kopiert.
-- Eigene Änderungen gehören nach ~/.config/hypr/user.lua (wird nie überschrieben).
-- Doku: https://wiki.hypr.land/configuring/

local home = os.getenv("HOME")
local bin  = home .. "/.local/bin/"

-- optionale Teildateien: fehlt eine, wird sie übersprungen statt die Konfiguration zu brechen
local function optional(name)
    local ok, err = pcall(require, name)
    if not ok and not tostring(err):find("not found", 1, true) then
        print("hypr-shell: " .. name .. ": " .. tostring(err))
    end
end

-- Farben aus dem Hintergrundbild (matugen schreibt hypr-shell-colors.lua)
local colors = { accent = "rgba(d4d4d4ee)", inactive = "rgba(59595966)" }
do
    local ok, c = pcall(require, "hypr-shell-colors")
    if ok and type(c) == "table" then colors = c end
end

-- Tastaturlayout und alte Umgebungsvariablen (von install.sh erzeugt)
local localcfg = { kb_layout = "us", kb_variant = "" }
do
    local ok, c = pcall(require, "hypr-shell-local")
    if ok and type(c) == "table" then localcfg = c end
end
optional("hypr-shell-env")

------------------
---- MONITORE ----
------------------

-- jeder Bildschirm mit seiner bevorzugten Auflösung, automatisch angeordnet
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

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

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

------------------
---- AUSSEHEN ----
------------------

hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 12,
        border_size = 1,
        col = {
            active_border   = colors.accent,
            inactive_border = colors.inactive,
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 14,
            render_power = 3,
            color        = 0x661a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 10,
            passes   = 3,
            noise    = 0.02,
            vibrancy = 0.17,
            popups   = true,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    input = {
        kb_layout    = localcfg.kb_layout or "us",
        kb_variant   = localcfg.kb_variant or "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-- weiche Animationen (Kurven nach Augenmass an die Vorlage angelehnt)
hl.curve("smooth", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("quick",  { type = "bezier", points = { { 0.15, 0.85 }, { 0.25, 1.0 } } })
hl.curve("linear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })

hl.animation({ leaf = "windows",      enabled = true, speed = 4, bezier = "smooth", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 3, bezier = "quick",  style = "popin 90%" })
hl.animation({ leaf = "windowsMove",  enabled = true, speed = 3, bezier = "smooth" })
hl.animation({ leaf = "border",       enabled = true, speed = 6, bezier = "linear" })
hl.animation({ leaf = "fade",         enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "layers",       enabled = true, speed = 3, bezier = "quick",  style = "fade" })
hl.animation({ leaf = "workspaces",   enabled = true, speed = 5, bezier = "smooth", style = "slidefade 15%" })

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
local terminal    = "kitty"
local fileManager = "nautilus"
local launcher    = "rofi -show drun"

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
