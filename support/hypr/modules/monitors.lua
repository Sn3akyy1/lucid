------------------
---- MONITORS ----
------------------

-- Every output starts on its preferred mode, placed automatically. Lucid
-- Settings > Displays writes what you change to ~/.config/hypr/lucid-monitors.lua,
-- which is read on every apply, so a change there needs no reload - except to the
-- workspaces it ties to a display, which reload. Without that file nothing below
-- the defaults runs.

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

-- which outputs the last apply made a mirror. one that stops being a mirror is
-- switched off and back on, or clients never hear of it as a display of its own
-- and nothing (wallpaper, bar) is drawn on it
local mirrored = {}

local function put(output, spec)
    spec.output = output
    hl.monitor(spec)
end

function M.apply()
    local cfg = config()
    local want = {}
    local mirrors = {}

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
                -- a mirror takes its position from what it mirrors. hyprland keeps
                -- an output's mirror when a rule leaves the field out, so stopping
                -- one has to say mirror = "" outright
                if type(m.mirror) == "string" and m.mirror ~= "" then
                    spec.mirror = m.mirror
                    mirrors[output] = true
                else
                    spec.mirror = ""
                    spec.position = tostring(m.position or M.defaults.position)
                    if mirrored[output] then put(output, { disabled = true }) end
                end
                put(output, spec)
            end
        end
    end

    for output in pairs(touched) do
        if not want[output] then
            if mirrored[output] then put(output, { disabled = true }) end
            put(output, {
                mode      = M.defaults.mode,
                position  = M.defaults.position,
                scale     = M.defaults.scale,
                transform = 0,
                vrr       = 0,
                mirror    = "",
                disabled  = false,
            })
        end
    end
    touched = want
    mirrored = mirrors
end

-- workspaces tied to a display. hyprland keeps a workspace rule once it has
-- one, so the page reloads rather than evals when these change, and they are
-- only set here, on load
local owner = {}

local function workspaces(cfg)
    if type(cfg.workspaces) ~= "table" then return end
    for _, w in ipairs(cfg.workspaces) do
        if type(w.workspace) == "string" and type(w.monitor) == "string" and w.monitor ~= "" then
            owner[w.workspace] = w.monitor
            pcall(hl.workspace_rule, {
                workspace = w.workspace,
                monitor   = w.monitor,
                default   = w.default == true or nil,
            })
        end
    end
end

-- a rule only places a workspace as it is made, and a display plugged in gets
-- back whatever last sat on its port, so after the rules change the page calls
-- this to move the open workspaces onto the displays they now belong to
function M.gather()
    local name, key = {}, {}
    for _, mon in ipairs(hl.get_monitors() or {}) do
        if not mon.is_mirror then
            local d = mon.description or ""
            key[mon.name] = d ~= "" and ("desc:" .. d) or mon.name
            name[key[mon.name]] = mon.name
            name[mon.name] = mon.name
        end
    end
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        local want = name[owner[tostring(ws.id)] or ""]
        if want and ws.monitor and ws.monitor.name ~= want then
            pcall(hl.dispatch, hl.dsp.workspace.move({ workspace = ws.id, monitor = want }))
        end
    end
    -- a display left showing an empty workspace of nobody's opens on its own
    -- lowest one, as it would have if the rules had been there when it came
    for _, mon in ipairs(hl.get_monitors() or {}) do
        local active = mon.active_workspace
        if key[mon.name] and active and active.is_empty and owner[tostring(active.id)] ~= key[mon.name] then
            local first
            for ws, k in pairs(owner) do
                local n = tonumber(ws)
                if n and (k == key[mon.name] or k == mon.name) and (not first or n < first) then first = n end
            end
            if first then pcall(function() mon:set_workspace({ workspace = first }) end) end
        end
    end
end

-- the settings page runs hyprctl eval 'LucidMonitors.apply()' after a change
LucidMonitors = M
pcall(M.apply)
pcall(workspaces, config())

return M
