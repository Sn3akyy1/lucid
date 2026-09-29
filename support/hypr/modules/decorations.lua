-----------------------
---- LOOK AND FEEL ----
-----------------------

-- window borders follow Lucid's palette. the shell's own colour cache is
-- written for every theme (matugen, pywal, the static ones, light mode), so
-- this reads that rather than a matugen-only template, and the shell calls
-- LucidBorders.apply() whenever the palette changes under a running session
local palette = os.getenv("HOME") .. "/.cache/quickshell/matugen.json"

local function role(json, name, fallback)
  local hex = json:match('"' .. name .. '"%s*:%s*"#(%x%x%x%x%x%x)')
  return "rgb(" .. string.lower(hex or fallback) .. ")"
end

local function borders()
  local f = io.open(palette, "r")
  local json = f and f:read("a") or ""
  if f then f:close() end
  return role(json, "primary", "a8c7fa"), role(json, "surface_container", "1d2024")
end

LucidBorders = {}

function LucidBorders.apply()
  local active, inactive = borders()
  hl.config({
    ["general.col.active_border"]   = active,
    ["general.col.inactive_border"] = inactive,
  })
end

local active_border, inactive_border = borders()

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 20,
    border_size = 2,
    col = {
      active_border   = active_border,
      inactive_border = inactive_border,
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