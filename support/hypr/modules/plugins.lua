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

    -- shaking does nothing: a tap of ctrl grows the pointer instead (the finder,
    -- below). the plugin's magnify only works while shake is on, so it stays on,
    -- with a threshold no shake can reach: a second of samples, each inside the
    -- box they make, adds up to at most the refresh rate
    shake = {
      enabled   = true,
      threshold = 100000.0,
      base      = 4.0,    -- how big the finder grows the pointer, x its own size
      timeout   = 1000,   -- ms it stays big before shrinking back
      -- tilt while big: the plugin tilts a grown pointer exactly as a small one,
      -- so it stays upright
      effects   = false,
      -- shakestart/update/end on socket2 while it is big: the shell draws the
      -- pointer itself in drags (HeldPointer), as big as this makes it
      ipc       = true,
    },

    -- the large copy the finder draws from, so a grown pointer stays sharp.
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

  -- on nvidia, hyprland draws a hardware pointer through a cpu buffer: the
  -- driver can't render into the cursor plane. the plugin draws hardware
  -- pointers itself and always renders them on the gpu, so there the pointer
  -- comes out blank, and shows only when it is drawn in software: grown, or too
  -- big for the plane (a large cursor size). so where hyprland would use the cpu
  -- buffer, the pointer is drawn in software, which the plugin draws as ever
  local function cpu_cursor_buffer()
    local cpu = hl.get_config("cursor.use_cpu_buffer")
    if cpu == 0 or cpu == 1 then return cpu == 1 end
    -- auto: hyprland's own test, any drm device on nvidia's driver
    for n = 0, 15 do
      local f = io.open("/sys/class/drm/card" .. n .. "/device/uevent", "r")
      if f then
        local ev = f:read("a") or ""
        f:close()
        if ev:lower():find("driver=nvidia", 1, true) then return true end
      end
    end
    return false
  end
  if cpu_cursor_buffer() then
    hl.config { cursor = { no_hardware_cursors = 1 } }
  end

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

  -- tap ctrl on its own to find the pointer: it grows to shake.base for
  -- shake.timeout ms, then shrinks back. Settings > Environment turns it off and
  -- on (modules/settings.lua). every key passes input.keyboard.key before
  -- hyprland's binds, so a tap is a ctrl going down with nothing else held and
  -- up again within tap_ms, with no other key, button or wheel in between. in a
  -- shortcut the other key's press is what counts, whichever is let go first.
  -- apps get their ctrl as ever: nothing here takes an event
  LucidCursor.tap_ms = 400
  LucidCursor.FIND = "Find the pointer (tap Ctrl)"
  -- left and right ctrl, as xkb keycodes
  local CTRL = { [37] = true, [105] = true }
  local BUTTONS = { "mouse:272", "mouse:273", "mouse:274", "mouse:275", "mouse:276" }
  local finder = { on = false, sub = nil, binds = {}, held = {}, buttons = 0, buttonAt = 0, armed = nil }

  local function key(code, time, state)
    if state == 1 then
      if CTRL[code] and not finder.armed then
        -- a key or button whose release went missing (a reload while it was
        -- down) must not block the finder for good: hyprland knows the keys
        for c in pairs(finder.held) do
          if not hl.is_key_down(c) then finder.held[c] = nil end
        end
        if finder.buttons > 0 and os.time() - finder.buttonAt > 60 then finder.buttons = 0 end
        -- a button held through it is ctrl in a drag: copy instead of move
        if next(finder.held) == nil and finder.buttons == 0 then
          finder.armed = { code = code, at = time }
        end
      elseif not (finder.armed and code == finder.armed.code) then
        finder.armed = nil
      end
      finder.held[code] = true
    elseif state == 0 then
      finder.held[code] = nil
      local a = finder.armed
      if a and code == a.code then
        finder.armed = nil
        if time >= a.at and time - a.at <= LucidCursor.tap_ms then
          hl.dispatch(hl.plugin.dynamic_cursors.dsp_magnify({}))
        end
      end
    end
  end

  local function button_down()
    finder.armed = nil
    finder.buttons = finder.buttons + 1
    finder.buttonAt = os.time()
  end

  local function button_up()
    finder.buttons = math.max(0, finder.buttons - 1)
  end

  local function scrolled()
    finder.armed = nil
  end

  function LucidCursor.finder(on)
    on = on ~= false
    if on == finder.on then return end
    finder.on = on
    if finder.sub then pcall(finder.sub.remove, finder.sub) end
    for _, b in ipairs(finder.binds) do pcall(b.remove, b) end
    finder.sub, finder.binds, finder.held, finder.buttons, finder.armed = nil, {}, {}, 0, nil
    if not on then return end
    -- an error here would come back on every key, so it is kept to itself
    finder.sub = hl.on("input.keyboard.key", function(code, time, state)
      pcall(key, code, time, state)
    end)
    local function add(keys, fn, opts)
      opts.non_consuming = true
      opts.description = LucidCursor.FIND
      finder.binds[#finder.binds + 1] = hl.bind(keys, fn, opts)
    end
    -- every button, whatever the modifiers, locked or not, in any submap: a
    -- release missed would leave a button held for good
    for _, b in ipairs(BUTTONS) do
      for _, release in ipairs({ false, true }) do
        add(b, release and button_up or button_down, { release = release or nil, ignore_mods = true, locked = true,
          dont_inhibit = true, submap_universal = true, allow_input_capture = true })
      end
    end
    for _, w in ipairs({ "mouse_up", "mouse_down", "mouse_left", "mouse_right" }) do
      add("CTRL + " .. w, scrolled, {})
    end
  end

  LucidCursor.finder(true)
end