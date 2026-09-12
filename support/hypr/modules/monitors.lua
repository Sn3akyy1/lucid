------------------
---- MONITORS ----
------------------

-- Every output starts on its preferred mode, placed automatically. Lucid
-- Settings > Displays writes what you change to ~/.config/hypr/lucid-monitors.lua,
-- which is read on every apply, so a change there needs no reload. Without that
-- file nothing below the defaults runs.

local M = {}

M.data = os.getenv("HOME") .. "/.config/hypr/lucid-monitors.lua"

-- what an output gets before the page has said otherwise
M.defaults = {
    mode     = "preferred",
    position = "auto",
    scale    = "1",
}

hl.monitor({
    output   = "",
    mode     = M.defaults.mode,
    position = M.defaults.position,
    scale    = M.defaults.scale,
})

-- the file is data only, so it runs with an empty environment
local function config()
    local chunk = loadfile(M.data, "t", {})
    local ok, cfg = false, nil
    if chunk then ok, cfg = pcall(chunk) end
    if not ok or type(cfg) ~= "table" or type(cfg.monitors) ~= "table" then
        return { monitors = {} }
    end
    return cfg
end

-- "desc:AU Optronics 0x408D" and "eDP-1" both reach the same output
local function present(output)
    local ok, mon = pcall(hl.get_monitor, output)
    return ok and mon ~= nil
end

-- which outputs the last apply gave a rule to, so one dropped from the page
-- goes back to the defaults rather than staying at whatever it was given
local touched = {}

local function put(output, spec)
    spec.output = output
    hl.monitor(spec)
end

function M.apply()
    local cfg = config()
    local want = {}

    -- switching off the only screen leaves nothing to switch it back on from,
    -- so the disables are counted first and dropped whole if that is what they
    -- would do
    local off = 0
    for _, m in ipairs(cfg.monitors) do
        if m.disabled and type(m.output) == "string" and m.output ~= "" and present(m.output) then
            off = off + 1
        end
    end
    local allow_off = off < #(hl.get_monitors() or {})

    for _, m in ipairs(cfg.monitors) do
        local output = m.output
        if type(output) == "string" and output ~= "" then
            want[output] = true
            if m.disabled then
                if allow_off then
                    put(output, { disabled = true })
                else
                    put(output, {
                        mode     = M.defaults.mode,
                        position = M.defaults.position,
                        scale    = M.defaults.scale,
                    })
                end
            else
                local spec = {
                    mode      = tostring(m.mode or M.defaults.mode),
                    scale     = tostring(m.scale or M.defaults.scale),
                    transform = tonumber(m.transform) or 0,
                    vrr       = tonumber(m.vrr) or 0,
                    disabled  = false,
                }
                -- a mirror takes its position from what it mirrors
                if type(m.mirror) == "string" and m.mirror ~= "" then
                    spec.mirror = m.mirror
                else
                    spec.position = tostring(m.position or M.defaults.position)
                end
                put(output, spec)
            end
        end
    end

    for output in pairs(touched) do
        if not want[output] then
            put(output, {
                mode      = M.defaults.mode,
                position  = M.defaults.position,
                scale     = M.defaults.scale,
                transform = 0,
                vrr       = 0,
                disabled  = false,
            })
        end
    end
    touched = want
end

-- the settings page runs hyprctl eval 'LucidMonitors.apply()' after a change
LucidMonitors = M
pcall(M.apply)

return M
