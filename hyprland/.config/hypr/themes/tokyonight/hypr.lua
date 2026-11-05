-- Tokyo Night: lo visual de Hyprland. Todos los themes setean las mismas
-- claves, asi al cambiar no queda nada del anterior.

-- Mantener igual a CURSOR_THEME/CURSOR_SIZE de theme.sh
hl.env("XCURSOR_THEME", "Qogir-dark-cursors")
hl.env("XCURSOR_SIZE",  "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,
        col = {
            active_border   = "rgba(7aa2f7aa)",
            inactive_border = "rgba(414868aa)",
        },
    },

    decoration = {
        rounding         = 10,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
        },
        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "default",  style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "default" })
