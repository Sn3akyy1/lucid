---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0.3,

        touchpad = {
            natural_scroll = true,
            scroll_factor  = 0.4,
        },
    },
})

-- Gesture sensitivity: shorter distance + lower forced-speed = triggers with less finger travel
hl.config({
    gestures = {
        workspace_swipe_distance           = 200, -- px needed to complete swipe (default 300)
        workspace_swipe_cancel_ratio       = 0.15, -- default ~0.5
        workspace_swipe_min_speed_to_force = 10,   -- px/timepoint flick to force-trigger (default 30)
    },
})