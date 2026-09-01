---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "rofi -show drun"

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Lucid Launcher
hl.bind(mainMod .. " + Super_L", hl.dsp.exec_cmd("qs ipc call launcher toggle"), { release = true })

-- Core
hl.bind(mainMod .. " + C",       hl.dsp.window.close())
hl.bind(mainMod .. " + M",       hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E",       hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",       hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + J",       hl.dsp.layout("togglesplit"))

-- Lucid Launcher shortcuts
hl.bind(mainMod .. " + B",       hl.dsp.exec_cmd("qs ipc call launcher wallpaper"))
hl.bind(mainMod .. " + T",       hl.dsp.exec_cmd("qs ipc call launcher theme"))
hl.bind(mainMod .. " + P",       hl.dsp.exec_cmd("qs ipc call launcher command"))

-- Lucid Settings (took SUPER+S from the scratchpad, which moved down a
-- modifier - see the Scratchpad section below)
hl.bind(mainMod .. " + S",       hl.dsp.exec_cmd("qs ipc call settings toggle"))

-- LucidMoji
hl.bind(mainMod .. " + period",  hl.dsp.exec_cmd("qs ipc call moji toggle"))

-- Lucid workspace overview (also: 3-finger swipe down/up, see modules/gestures.lua)
hl.bind(mainMod .. " + W",       hl.dsp.exec_cmd("qs ipc call workspaces toggle"))

-- Focus with arrow keys
hl.bind(mainMod .. " + left",    hl.dsp.focus({ direction = "left"  }))
hl.bind(mainMod .. " + right",   hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",      hl.dsp.focus({ direction = "up"    }))
hl.bind(mainMod .. " + down",    hl.dsp.focus({ direction = "down"  }))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad (moved off SUPER+S, which now opens Lucid Settings)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Function keys
hl.bind("F1",  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),               { locked = true })
hl.bind("F2",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),                 { locked = true, repeating = true })
hl.bind("F3",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),           { locked = true, repeating = true })
hl.bind("F4",  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),             { locked = true })
hl.bind("F5",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                            { locked = true, repeating = true })
hl.bind("F6",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                            { locked = true, repeating = true })
-- F7: reserved
hl.bind("F8",  hl.dsp.exec_cmd("rfkill toggle all"),                                        { locked = true })
hl.bind("F9",  hl.dsp.exec_cmd(terminal),                                                    { locked = true })
hl.bind("F10", hl.dsp.exec_cmd("qs ipc call lock lock"),                                              { locked = true }) -- coming soon
-- F11: reserved
hl.bind("F12", hl.dsp.exec_cmd("gnome-calculator"),                                         { locked = true })

-- XF86 multimedia keys (hardware fallback)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),      { locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),    { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                   { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                   { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                             { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                             { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                               { locked = true })

--Screenshot

-- PrtSc alone → toggle region screenshot (press again while selecting to cancel, mirrors your rofi toggle)
hl.bind("Print", hl.dsp.exec_cmd("qs ipc call snap toggle"), { locked = true })

-- Fn + PrtSc → full screen screenshot (Quickshell-native)
hl.bind("SUPER + Print", hl.dsp.exec_cmd("qs ipc call screenshot full"), { locked = true })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs ipc call snap toggle"), { locked = true })

local reload = os.getenv("HOME") .. "/.config/hypr/scripts/reload.sh"

-- Reload
hl.bind("SUPER + R", hl.dsp.exec_cmd(reload))