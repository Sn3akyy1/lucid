-------------------
---- GLASS ----
-------------------

-- Per-app translucency. Lucid Settings > Glass picks the apps and writes them
-- to ~/.config/hypr/lucid-glass.lua, which is read on every apply, so a change
-- there needs no reload. Nothing here runs unless that file exists.

local M = {}

M.data = os.getenv("HOME") .. "/.config/hypr/lucid-glass.lua"

-- the file is data only, so it runs with an empty environment
local function config()
    local chunk = loadfile(M.data, "t", {})
    local ok, cfg = false, nil
    if chunk then ok, cfg = pcall(chunk) end
    if not ok or type(cfg) ~= "table" or type(cfg.apps) ~= "table" then
        return { apps = {} }
    end
    return cfg
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

-- window rules take regex, so names are escaped and matched whole
local function pattern(list)
    local out = {}
    for _, s in ipairs(list) do
        out[#out + 1] = (tostring(s):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?%{%}|\\]", "\\%0"))
    end
    return "(?i)^(" .. table.concat(out, "|") .. ")$"
end

-- rules cannot be removed, only switched off, so each apply retires the last set
local rules = {}
-- what the last apply left on screen, so an app dropped from the list can be
-- put back rather than staying at whatever it was given
local touched = {}

function M.apply()
    local cfg = config()
    for _, r in ipairs(rules) do r:set_enabled(false) end
    rules = {}

    local want = {}
    for _, app in ipairs(cfg.apps or {}) do
        local opacity = tonumber(app.opacity)
        if opacity and type(app.class) == "table" and #app.class > 0 then
            rules[#rules + 1] = hl.window_rule({
                match   = { class = pattern(app.class) },
                opacity = opacity,
            })
            for _, c in ipairs(app.class) do want[lower(c)] = opacity end
        end
    end

    -- a rule only meets a window as that window opens, so anything already up
    -- is set by hand; without this nothing moves until the app is restarted
    for _, w in ipairs(hl.get_windows() or {}) do
        local cls = lower(w.class)
        local opacity = want[cls] or (touched[cls] and 1.0 or nil)
        if opacity then
            hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "opacity", value = opacity }))
        end
    end
    touched = want
end

-- the settings page runs hyprctl eval 'LucidGlass.apply()' after a change
LucidGlass = M
pcall(M.apply)

return M
