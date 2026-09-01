-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 20,
    border_size = 2,
    col = {
      active_border   = "rgba(00000000)",
      inactive_border = "rgba(00000000)",
    },
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding       = 25,
    rounding_power = 2,
    active_opacity   = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled      = true,
      range        = 20,
      render_power = 3,
      color        = "rgba(00000099)",
    },
    blur = {
      enabled        = true,
      size           = 9,
      passes         = 3,
      vibrancy       = 0.1696,
      noise          = 0.04,
      ignore_opacity = true,
    },
  },

dwindle = {
    preserve_split = false,
},

  animations = {
    enabled = true,
  },
})