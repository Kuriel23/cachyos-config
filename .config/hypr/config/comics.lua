local colors = require("comics.palette")
local script = os.getenv("HOME") .. "/.config/hypr/scripts/comics.py"

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 14,
        border_size = 4,
        col = {
            active_border = { colors = { colors.accent, colors.secondary }, angle = 35 },
            inactive_border = colors.outline,
        },
    },
    decoration = {
        rounding = 2,
        active_opacity = 0.92,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1,
        blur = { enabled = true },
        shadow = { enabled = true, range = 14, render_power = 3, sharp = true, offset = { 5, 5 }, color = colors.shadow },
    },
    group = {
        col = {
            border_active = colors.accent,
            border_inactive = colors.outline,
            border_locked_active = colors.secondary,
            border_locked_inactive = colors.outline,
        },
        groupbar = {
            col = {
                active = colors.accent,
                inactive = colors.surface,
                locked_active = colors.secondary,
                locked_inactive = colors.surface,
            },
        },
    },
})

hl.curve("comicsOut", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "comicsOut", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "comicsOut", style = "fade" })
hl.bind("SUPER + ALT + W", hl.dsp.exec_cmd("python3 " .. script .. " toggle"))
hl.bind("SUPER + ALT + P", hl.dsp.exec_cmd("python3 " .. script .. " pause"))
hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd("python3 " .. script .. " next"))
