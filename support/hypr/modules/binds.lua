---------------------
---- KEYBINDINGS ----
---------------------

-- The binds themselves live in ~/.config/lucid/keybinds.json, which Lucid
-- Settings -> Keybinds edits and the SUPER+/ sheet reads. This module only
-- reads that list and hands every entry to hl.bind, so a change there is one
-- `hyprctl reload` away and nothing here needs editing to add a bind.
--
-- An entry:
--   { "id": "terminal", "keys": "F9", "desc": "Terminal",
--     "category": "Apps", "type": "exec", "cmd": "kitty",
--     "opts": { "locked": true }, "enabled": false }
--
--   type "exec" runs cmd through the shell. type "lua" evaluates "lua" as an
--   expression giving a dispatcher (hl.dsp.window.close()) or a function run
--   on every press; `fn` (utils/functions.lua), `specials` (modules/specials.lua),
--   when present, and `seq(...)` are in scope. "each": "workspace" repeats the entry for workspaces 1-10,
--   filling in {n} (1..10) and {key} (1..9, 0) wherever they appear.
--
-- A missing or unreadable file binds a small emergency set instead, so a typo
-- never leaves the session without a terminal or a way back into Settings.
-- What happened on the last load goes to $XDG_RUNTIME_DIR/lucid-keybinds-status.json,
-- which the settings page shows. Anything in hypr-user.lua still binds on top.

local HOME        = os.getenv("HOME") or ""
local BINDS_FILE  = HOME .. "/.config/lucid/keybinds.json"
local STATUS_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/lucid-keybinds-status.json"

-- the JSON reader lives in modules/json.lua; if it cannot load, nothing parses
-- and the emergency set below binds instead
local json_ok, json = pcall(require, "modules.json")

---- binding ----

local fn_ok, fn = pcall(require, "utils.functions")
if not fn_ok then fn = {} end

-- several dispatchers on one key, in order
local function seq(...)
    local list = { ... }
    return function()
        for _, d in ipairs(list) do hl.dispatch(d) end
    end
end

-- special workspaces (Settings > Workspaces); entries call specials.toggle("music") etc.
local specials_ok, specials = pcall(require, "modules.specials")
if not specials_ok then specials = nil end

local lua_env = setmetatable({ fn = fn, seq = seq, specials = specials }, { __index = _G })

-- an expression first (the common case); a chunk with its own return after
local function compile(code, label)
    local chunk = load("return " .. code, "=" .. label, "t", lua_env)
    if not chunk then
        local err
        chunk, err = load(code, "=" .. label, "t", lua_env)
        if not chunk then error(err, 0) end
    end
    local ok, action = pcall(chunk)
    if not ok then error(action, 0) end
    if action == nil then error("the Lua gave nothing back; it must be a dispatcher or a function", 0) end
    return action
end

local function fill(s, n, key)
    if type(s) ~= "string" or n == nil then return s end
    return (string.gsub(string.gsub(s, "{n}", tostring(n)), "{key}", tostring(key)))
end

local function bind_one(entry, n, key)
    local keys = fill(entry.keys, n, key)
    if type(keys) ~= "string" or keys == "" then error("no keys", 0) end

    local action
    if entry.type == "lua" then
        action = compile(fill(entry.lua or "", n, key), entry.id or keys)
    else
        local cmd = fill(entry.cmd, n, key)
        if type(cmd) ~= "string" or cmd == "" then error("no command", 0) end
        action = hl.dsp.exec_cmd(cmd)
    end

    local opts = {}
    if type(entry.opts) == "table" then
        for k, v in pairs(entry.opts) do opts[k] = v end
    end
    -- carried into `hyprctl binds` too
    local desc = fill(entry.desc, n, key)
    if type(desc) == "string" and desc ~= "" and opts.description == nil then
        opts.description = desc
    end

    hl.bind(keys, action, opts)
end

local status = { file = BINDS_FILE, source = "file", error = "", total = 0, applied = 0, failed = {}, time = os.time() }

local function apply(entry)
    if type(entry) ~= "table" or entry.enabled == false then return end
    local runs = { {} }
    if entry.each == "workspace" then
        runs = {}
        for i = 1, 10 do runs[i] = { i, i % 10 } end
    end
    for _, r in ipairs(runs) do
        status.total = status.total + 1
        local ok, err = pcall(bind_one, entry, r[1], r[2])
        if ok then
            status.applied = status.applied + 1
        else
            status.failed[#status.failed + 1] = {
                id = tostring(entry.id or ""),
                keys = tostring(fill(entry.keys, r[1], r[2]) or ""),
                error = tostring(err),
            }
        end
    end
end

local function read_list()
    if not json_ok then return nil, "modules/json.lua did not load (" .. tostring(json) .. ")" end
    local f, open_err = io.open(BINDS_FILE, "r")
    if not f then return nil, "cannot read " .. BINDS_FILE .. " (" .. tostring(open_err) .. ")" end
    local text = f:read("a")
    f:close()
    local ok, data = pcall(json.decode, text)
    if not ok then return nil, "keybinds.json does not parse: " .. tostring(data) end
    if type(data) ~= "table" or type(data.binds) ~= "table" then
        return nil, "keybinds.json has no \"binds\" list"
    end
    return data.binds
end

-- enough to get around, reach Settings and fix the file
local EMERGENCY = {
    { id = "terminal", keys = "F9", type = "exec", cmd = "kitty" },
    { id = "close", keys = "SUPER + C", type = "lua", lua = "hl.dsp.window.close()" },
    { id = "settings", keys = "SUPER + S", type = "exec", cmd = "qs ipc call settings keybinds" },
    { id = "launcher", keys = "SUPER + Super_L", type = "exec", cmd = "qs ipc call launcher toggle", opts = { release = true } },
    { id = "reload", keys = "SUPER + R", type = "exec", cmd = "hyprctl reload" },
    { id = "exit", keys = "SUPER + M", type = "lua", lua = "hl.dsp.exit()" },
    { id = "ws-focus", keys = "SUPER + {key}", each = "workspace", type = "lua", lua = "hl.dsp.focus({ workspace = {n} })" },
    { id = "ws-move", keys = "SUPER + SHIFT + {key}", each = "workspace", type = "lua", lua = "hl.dsp.window.move({ workspace = {n} })" },
}

local list, load_err = read_list()
if list then
    for _, entry in ipairs(list) do apply(entry) end
    if status.applied == 0 then
        load_err = "keybinds.json bound nothing"
    end
end

if load_err then
    status.source = "emergency"
    status.error = load_err
    for _, entry in ipairs(EMERGENCY) do apply(entry) end
    pcall(hl.notification.create, {
        text = "Lucid keybinds: " .. load_err .. ". Emergency binds are active - SUPER+S opens Settings.",
        timeout = 12000,
    })
end

-- Settings switches into this while it records a key, so the combo reaches the
-- window instead of firing whatever it is bound to. It holds one bind: the way
-- out, in case the shell dies mid-recording.
pcall(hl.define_submap, "lucid_capture", function()
    hl.bind("SUPER + Escape", hl.dsp.submap("reset"))
end)

local sf = json_ok and io.open(STATUS_FILE, "w")
if sf then
    sf:write(json.encode(status))
    sf:close()
end
