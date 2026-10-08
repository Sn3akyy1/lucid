--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

local suppressMaximizeRule = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name  = "float-lucid-settings",
    match = { class = "org.quickshell", title = "Lucid Settings" },

    float  = true,
    size   = "1180 800",
    center = true,
})

hl.window_rule({
    match = { class = "org.gnome.Calculator" },

    float  = true,
    size   = "200 400",
    center = true,
})

-- lucid's file choosers. the portal opens them with no parent window to hang
-- off, so they would tile. matched by the titles lucidprefs/pickfile.py and
-- the kde connect bridge pass, so the file manager itself is left alone
hl.window_rule({
    name  = "float-lucid-choosers",
    match = {
        class = "^(org\\.gnome\\.Nautilus|xdg-desktop-portal-gtk|xdg-desktop-portal-gnome|zenity|org\\.kde\\.kdialog|kdialog)$",
        title = "^(Choose an account picture|Choose a template|Choose a colour scheme|Export the palette|Add wallpaper|Send files|Send to .+)$",
    },

    float  = true,
    center = true,
})
