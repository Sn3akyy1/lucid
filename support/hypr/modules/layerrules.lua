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
-- It was off for a while, so a panel over a window frosted the window. But
-- without xray each surface is blurred on its own, and two that meet came out
-- in different shades: the launcher standing on the bar, or a panel hanging
-- from it, showed a seam where they join. On, all of them sample the same
-- blurred background and the glass matches wherever it joins; a panel over a
-- window frosts the wallpaper, not the window.
hl.layer_rule({ match = { namespace = "quickshell" }, xray = true })
