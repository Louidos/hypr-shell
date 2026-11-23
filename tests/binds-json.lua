-- Lädt config/hypr/hyprland.lua mit der Attrappe und gibt die Kürzel so aus wie "hyprctl binds -j"
-- (modmask, key, description, has_description, dispatcher, arg). Für den Oberflächentest des
-- Kürzel-Spickzettels: lua5.4 tests/binds-json.lua > binds.json (HOME mit hypr-shell-settings.lua)
package.path = (os.getenv("HOME") or ".") .. "/.config/hypr/?.lua;./tests/?.lua;" .. package.path
local A = require("hl-attrappe")
_G.hl = A.hl
dofile("config/hypr/hyprland.lua")

local MASKE = { SHIFT = 1, CAPS = 2, CTRL = 4, CONTROL = 4, ALT = 8, MOD2 = 16, MOD3 = 32, SUPER = 64, MOD5 = 128 }
local function json(s) return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
local keys = {}
for k in pairs(A.binds) do keys[#keys + 1] = k end
table.sort(keys)
local out = {}
for _, k in ipairs(keys) do
    local teile = {}
    for t in k:gmatch("[^+]+") do teile[#teile + 1] = t:match("^%s*(.-)%s*$") end
    local taste = teile[#teile]
    local maske = 0
    for i = 1, #teile - 1 do maske = maske + (MASKE[teile[i]:upper()] or 0) end
    local f = A.flags[k] or {}
    local d = f.description or ""
    out[#out + 1] = string.format('{"modmask": %d, "key": %s, "description": %s, "has_description": %s, "dispatcher": "__lua", "arg": "%d", "submap": ""}',
        maske, json(taste), json(d), d ~= "" and "true" or "false", #out + 1)
end
print("[" .. table.concat(out, ",\n") .. "]")
