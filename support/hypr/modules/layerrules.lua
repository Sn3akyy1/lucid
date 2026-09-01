hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true })
hl.layer_rule({ match = { namespace = "rofi" }, dim_around = true })
hl.layer_rule({ match = { namespace = "rofi" }, animation = "popin" })
-- The shell's glass surfaces blur through ext-background-effect-v1, and
-- Hyprland renders windows *before* top layers, so without this their blur
-- samples whatever window happens to be underneath. The kernel reaches far
-- past the surface too (size 9 at 3 passes is ~72px), so the bar picked up
-- window content from well below its own strip: its tint drifted with the
-- workspace, brightening over a white app and shifting over a game.
-- xray points the blur at the background instead, so every pill, the dock
-- and the OSD frost the wallpaper and nothing else. The lock screen is
-- unaffected - it blurs the wallpaper client-side, not through the region.
-- Turned off deliberately: xray made the glass frost the wallpaper instead
-- of whatever is actually behind it, so a panel opened over a window showed
-- blurred wallpaper rather than the window. Real see-through glass is worth
-- the tint drift described above.
-- hl.layer_rule({ match = { namespace = "quickshell" }, xray = true })
