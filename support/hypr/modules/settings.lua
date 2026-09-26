-----------------------------
---- SETTINGS FROM LUCID ----
-----------------------------

-- The Hyprland options Lucid Settings changes (Windows, Input) are written to
-- ~/.config/hypr/lucid-settings.lua and applied here, so a change needs no
-- reload. hyprland.lua requires this before anything of your own, and what
-- your own config sets afterwards (hypr-user.lua, HyprMod's hyprland-gui)
-- still wins: once the whole config is read, an option that no longer holds
-- what was set here is listed in $XDG_RUNTIME_DIR/lucid-settings-status.json,
-- Settings says so on its row, and a live change leaves it alone.

local M = {}

M.data = os.getenv("HOME") .. "/.config/hypr/lucid-settings.lua"
M.status = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/lucid-settings-status.json"

-- the file is data only, so it runs with an empty environment
local function config()
    local chunk = loadfile(M.data, "t", {})
    local ok, cfg = false, nil
    if chunk then ok, cfg = pcall(chunk) end
    if not ok or type(cfg) ~= "table" or type(cfg.options) ~= "table" then
        return { options = {} }
    end
    return cfg
end

-- an option's value as one string, so two readings compare; gaps and
-- colours come back as tables
local function flat(v)
    if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. flat(x) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local function reading(key)
    local ok, v = pcall(hl.get_config, key)
    return ok and flat(v) or ""
end

local function quote(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c)
        return c == '"' and '\\"' or c == "\\" and "\\\\" or string.format("\\u%04x", c:byte())
    end) .. '"'
end

-- what each option read right after this module set it
local set = {}
-- what each option held before this module first set it: your config's own
-- value, which a reset puts back and Settings compares a change against
local base = {}
-- options something later in the config set again, left alone on a live apply
local skip = {}
local failed = {}

-- a value as JSON for Settings: gaps as one number (or "t r b l"), colours as
-- "aarrggbb,…@angle"
local function plain(v)
    if type(v) == "number" then return string.format("%.6g", v) end
    if type(v) == "boolean" then return tostring(v) end
    if type(v) == "string" then return quote(v) end
    if type(v) == "table" and v.top ~= nil then
        if v.top == v.right and v.top == v.bottom and v.top == v.left then return plain(v.top) end
        return quote(v.top .. " " .. v.right .. " " .. v.bottom .. " " .. v.left)
    end
    if type(v) == "table" and type(v.colors) == "table" then
        local out = {}
        for _, c in ipairs(v.colors) do out[#out + 1] = (tostring(c):lower():gsub("^0x", "")) end
        return quote(table.concat(out, ",") .. "@" .. math.floor((tonumber(v.angle) or 0) + 0.5))
    end
    return "null"
end

local function write_status()
    local applied, overridden, errors, bases = {}, {}, {}, {}
    for k in pairs(set) do
        if skip[k] then overridden[#overridden + 1] = quote(k) else applied[#applied + 1] = quote(k) end
    end
    for k, e in pairs(failed) do errors[#errors + 1] = quote(k) .. ": " .. quote(e) end
    for k, v in pairs(base) do bases[#bases + 1] = quote(k) .. ": " .. plain(v) end
    table.sort(bases)
    table.sort(applied)
    table.sort(overridden)
    table.sort(errors)
    local f = io.open(M.status, "w")
    if not f then return end
    f:write("{\"time\": " .. os.time()
        .. ", \"applied\": [" .. table.concat(applied, ", ")
        .. "], \"overridden\": [" .. table.concat(overridden, ", ")
        .. "], \"failed\": {" .. table.concat(errors, ", ")
        .. "}, \"base\": {" .. table.concat(bases, ", ") .. "}}\n")
    f:close()
end

-- live is true from Settings, where an option your config overrides is left
-- as your config has it
function M.apply(live)
    local cfg = config()
    failed = {}
    for k in pairs(set) do
        if cfg.options[k] == nil then set[k] = nil; skip[k] = nil end
    end
    -- one option at a time, so a bad one does not take the rest with it
    for k, v in pairs(cfg.options) do
        local known, current = pcall(hl.get_config, k)
        if type(k) ~= "string" or not known or current == nil then
            -- an option this Hyprland does not have would only add a config error
            failed[tostring(k)] = "this Hyprland has no such option"
        elseif not (live and skip[k]) then
            if base[k] == nil then base[k] = current end
            local ok, err = pcall(hl.config, { [k] = v })
            if ok then
                set[k] = reading(k)
                skip[k] = nil
            else
                failed[k] = tostring(err)
            end
        end
    end
    write_status()
end

-- options Settings hands back to your config: their own value goes back on,
-- live, so no reload is needed when it is known
function M.restore(keys)
    for _, k in ipairs(keys or {}) do
        if base[k] ~= nil and not skip[k] then pcall(hl.config, { [k] = base[k] }) end
        set[k] = nil
        skip[k] = nil
    end
    write_status()
end

-- after the whole config is read, including whatever comes after this module
hl.on("config.reloaded", function()
    skip = {}
    for k, v in pairs(set) do
        if reading(k) ~= v then skip[k] = true end
    end
    write_status()
end)

-- the settings page runs hyprctl eval 'LucidSettings.apply(true)' after a change
LucidSettings = M
pcall(M.apply, false)

return M
