-----------------------
-------- LAYOUT -------
-----------------------

hl.config({
    dwindle = {
    preserve_split = true,
    -- a space splits side by side while wider than its height times this, so
    -- higher stacks sooner. 2 sits right on a 16:9 screen's full-height window
    split_width_multiplier = 1.5,
},
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})
