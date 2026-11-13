if hl.plugin.dynamic_cursors then
  hl.config { plugin = { dynamic_cursors = {
    enabled   = true,
    -- every pointer stays upright: the shape rules below are the ones that lean
    mode      = "none",   -- "tilt" | "rotate" | "stretch" | "none"
    threshold = 1,        -- min angle change (°) before redraw; lower = smoother

    rotate = {
      length = 20,        -- stick length in px, ≈ your cursor size
      offset = 0.0,       -- clockwise angle offset for ALL shapes
    },

    tilt = {
      limit      = 5000,  -- speed (px/s) for full tilt; lower = tiltier
      activation = "negative_quadratic", -- "linear" | "quadratic" | "negative_quadratic"
      window     = 100,   -- ms of speed averaging; higher = smoother but laggier
      full       = 180,    -- max tilt each side (°)
    },

    stretch = {
      limit      = 3000,  -- speed (px/s) for full 2x stretch
      activation = "quadratic",
      window     = 100,
    },

    shake = {
      enabled   = true,
      threshold = 6.0,    -- lower = shake detected sooner
      base      = 4.0,    -- instant zoom on shake
      speed     = 4.0,    -- extra zoom per second of shaking
      influence = 0.0,    -- how much shake intensity affects speed
      limit     = 0.0,    -- max zoom (<1 = no limit)
      timeout   = 2000,   -- ms to stay big after shaking stops
      -- tilt while big: the plugin tilts a grown pointer exactly as a small one,
      -- and a shake swings it from side to side, so it stays upright
      effects   = false,
      -- shakestart/update/end on socket2: the shell draws the pointer itself in
      -- drags (HeldPointer), as big as this makes it
      ipc       = true,
    },

    -- the large copy shake to find draws from, so a grown pointer stays sharp.
    -- it loads on a thread of its own whenever the cursor theme changes, and
    -- hyprcursor cannot read two themes at once: a setcursor landing meanwhile
    -- crashes Hyprland. every setcursor of Lucid's waits its turn on a lock for
    -- that (lucidprefs/cursortheme.py); anything else calling hyprctl setcursor
    -- right after a theme change should leave a moment. the copy is only loaded
    -- again for a new name or size, so after a recolour cursortheme.py switches
    -- it off and on
    hyprcursor = {
      enabled    = true,
      nearest    = 1,     -- 0 never pixelated, 1 when no hi-res, 2 always
      resolution = -1,    -- -1 = cursor size × shake.base × 1.5
      fallback   = "clientside",
    },
  }}}

  -- the arrow, the busy and help pointers drawn on it, and the pointing hand
  -- lean into the way you move. text, resizing, moving, the crosshair and the
  -- rest stay upright
  LucidCursor = {
    tilting = {
      "default", "left_ptr", "arrow", "top_left_arrow",
      "progress", "left_ptr_watch", "half-busy", "wait", "watch",
      "help", "question_arrow", "whats_this", "left_ptr_help", "dnd-ask",
      "pointer", "hand2", "pointing_hand", "hand", "pin", "person",
    },
  }

  -- Settings > Environment turns these off and on again (modules/settings.lua).
  -- an app that draws its own pointer (zen and firefox, gtk 3, x11) never says
  -- which one it shows, so there its pointers lean all together or not at all
  function LucidCursor.tilt(on, apps)
    for _, shape in ipairs(LucidCursor.tilting) do
      hl.plugin.dynamic_cursors.shape_rule { shape = shape, mode = on and "tilt" or "none" }
    end
    hl.plugin.dynamic_cursors.shape_rule { shape = "clientside", mode = (on and apps ~= false) and "tilt" or "none" }
  end

  LucidCursor.tilt(true, true)
end