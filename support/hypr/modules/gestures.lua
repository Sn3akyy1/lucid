------------------
---- GESTURES ----
------------------

-- Workspace switch: 3 & 4 fingers left/right
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- Pre-create workspaces 1-5 so gesture swipes can always live-track to them
for i = 1, 6 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- local function minimize_all()
--     local ws = hl.get_active_workspace()
--     if not ws then return end
--
--     local windows = hl.get_windows()
--     for _, w in pairs(windows) do
--         if w.workspace.id == ws.id then
--             -- Tag the window with its source workspace ID before hiding it
--             local tag = "minimized-ws-" .. ws.id
--             hl.dispatch(hl.dsp.window.tag({ tag = tag, window = w }))
--             hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = w }))
--         end
--     end
-- end

-- local function unminimize_all()
--     local min_ws = hl.get_workspace("special:minimized")
--     if not min_ws or min_ws.windows == 0 then return end
--
--     local ws = hl.get_active_workspace()
--     if not ws then return end
--
--     local tag = "minimized-ws-" .. ws.id
--
--     local windows = hl.get_windows()
--     for _, w in pairs(windows) do
--         if w.workspace.name == "special:minimized" then
--             -- Only restore windows that were minimized FROM this workspace
--             for _, t in pairs(w.tags or {}) do
--                 if t == tag then
--                     hl.dispatch(hl.dsp.window.move({ workspace = ws.id, follow = false, window = w }))
--                     hl.dispatch(hl.dsp.window.clear_tags({ window = w }))
--                     break
--                 end
--             end
--         end
--     end
-- end

-- hl.gesture({ fingers = 3, direction = "down", scale = 1.6, action = minimize_all })
-- hl.gesture({ fingers = 4, direction = "down", scale = 1.6, action = minimize_all })
-- hl.gesture({ fingers = 3, direction = "up",   scale = 1.6, action = unminimize_all })
-- hl.gesture({ fingers = 4, direction = "up",   scale = 1.6, action = unminimize_all })

-- Lucid workspace overview (lucidbar/Workspaces.qml): swipe down to open it,
-- up to dismiss. Vertical only, so the 3 & 4 finger horizontal workspace
-- swipes above are untouched. Directional open/close rather than a toggle so
-- the gesture is deterministic - swiping up on an already-closed overview is a
-- harmless no-op. Also reachable via SUPER + W (see modules/binds.lua).
local function overview(action)
    return function()
        hl.dispatch(hl.dsp.exec_cmd("qs ipc call workspaces " .. action))
    end
end

hl.gesture({ fingers = 3, direction = "down", scale = 1.6, action = overview("open") })
hl.gesture({ fingers = 3, direction = "up",   scale = 1.6, action = overview("close") })