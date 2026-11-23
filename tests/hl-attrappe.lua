-- Attrappe der Hyprland-Lua-API (Stand Wiki 0.55): kennt nur dokumentierte Funktionen.
-- Ein Tippfehler in hyprland.lua (z. B. hl.dsp.windw.close) führt hier zu einem Fehler.
local M = { aufrufe = {}, binds = {}, flags = {}, layer = {}, start = {} }

local function streng(name, t)
    return setmetatable(t, {
        __index = function(_, k) error("unbekannter Aufruf: " .. name .. "." .. tostring(k), 2) end,
    })
end
local function merke(was) return function(...) table.insert(M.aufrufe, { was, ... }); return { set_enabled = function() end } end end
local function dsp(was) return function(arg) return { dsp = was, arg = arg } end end

local bind_flags = { click=1, ignore_mods=1, locked=1, long_press=1, mouse=1, non_consuming=1,
    release=1, repeating=1, submap_universal=1, transparent=1, description=1 }
local layer_keys = { name=1, match=1, above_lock=1, animation=1, blur=1, blur_popups=1, dim_around=1,
    ignore_alpha=1, no_anim=1, no_screen_share=1, order=1, xray=1 }
local monitor_keys = { output=1, mode=1, position=1, scale=1, reserved=1, reserved_area=1, disabled=1,
    transform=1, mirror=1, bitdepth=1, cm=1, sdr_eotf=1, sdrbrightness=1, sdrsaturation=1, vrr=1, icc=1,
    supports_wide_color=1, supports_hdr=1, sdr_min_luminance=1, sdr_max_luminance=1, min_luminance=1,
    max_luminance=1, max_avg_luminance=1 }
local config_cats = { general=1, decoration=1, animations=1, input=1, gestures=1, group=1, misc=1,
    binds=1, xwayland=1, opengl=1, render=1, cursor=1, ecosystem=1, debug=1, dwindle=1, master=1,
    scrolling=1, monocle=1, layout=1, quirks=1 }

local hl = {
    config = function(t)
        for k in pairs(t) do
            local cat = tostring(k):match("^([^.]+)")
            if not config_cats[cat] then error("unbekannte Konfigurationsgruppe: " .. tostring(k), 2) end
        end
        table.insert(M.aufrufe, { "config", t })
    end,
    -- hl.monitor: nur bekannte Felder (Hyprland 0.55, src/config/lua/bindings/LuaBindingsConfigRules.cpp),
    -- transform ist eine ganze Zahl 0–7 (wl_output_transform)
    monitor = function(t)
        for k in pairs(t) do
            if not monitor_keys[k] then error("hl.monitor: unbekanntes Feld " .. tostring(k), 2) end
        end
        if t.transform ~= nil and (math.type(t.transform) ~= "integer" or t.transform < 0 or t.transform > 7) then
            error("hl.monitor: transform muss 0–7 sein, nicht " .. tostring(t.transform), 2)
        end
        table.insert(M.aufrufe, { "monitor", t })
    end,
    env = merke("env"), curve = merke("curve"), animation = merke("animation"),
    gesture = merke("gesture"), window_rule = merke("window_rule"), workspace_rule = merke("workspace_rule"),
    device = merke("device"), permission = merke("permission"), unbind = merke("unbind"),
    exec_cmd = merke("exec_cmd"), dispatch = merke("dispatch"), timer = merke("timer"),
    get_config = function() return {} end, version = function() return "0.55.0" end,
    on = function(ev, fn)
        if type(fn) ~= "function" then error("hl.on braucht eine Funktion", 2) end
        if ev == "hyprland.start" then table.insert(M.start, fn) end
    end,
    bind = function(keys, action, flags)
        if type(keys) ~= "string" or keys == "" then error("hl.bind: Tasten fehlen", 2) end
        if action == nil then error("hl.bind: Aktion fehlt für " .. keys, 2) end
        for k in pairs(flags or {}) do
            if not bind_flags[k] then error("hl.bind: unbekannte Option " .. k, 2) end
        end
        if M.binds[keys] then error("hl.bind: doppelt belegt: " .. keys, 2) end
        M.binds[keys] = action
        M.flags[keys] = flags or {}
    end,
    layer_rule = function(r)
        for k in pairs(r) do
            if not layer_keys[k] then error("hl.layer_rule: unbekannte Wirkung " .. k, 2) end
        end
        if type(r.match) ~= "table" or not r.match.namespace then error("hl.layer_rule: match.namespace fehlt", 2) end
        table.insert(M.layer, r)
    end,
}
hl.dsp = streng("hl.dsp", {
    exec_cmd = dsp("exec_cmd"), exec_raw = dsp("exec_raw"), exit = dsp("exit"), focus = dsp("focus"),
    layout = dsp("layout"), global = dsp("global"), submap = dsp("submap"), no_op = dsp("no_op"),
    pass = dsp("pass"), event = dsp("event"), reload_config = dsp("reload_config"), dpms = dsp("dpms"),
    force_renderer_reload = dsp("force_renderer_reload"), send_shortcut = dsp("send_shortcut"),
    window = streng("hl.dsp.window", {
        close = dsp("close"), float = dsp("float"), move = dsp("move"), drag = dsp("drag"),
        resize = dsp("resize"), pseudo = dsp("pseudo"), fullscreen = dsp("fullscreen"), pin = dsp("pin"),
        center = dsp("center"), kill = dsp("kill"), swap = dsp("swap"), cycle_next = dsp("cycle_next"),
        set_prop = dsp("set_prop"), tag = dsp("tag"),
    }),
    workspace = streng("hl.dsp.workspace", { toggle_special = dsp("toggle_special") }),
})
M.hl = streng("hl", hl)
return M
