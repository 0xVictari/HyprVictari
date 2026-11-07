-- Chicago95 (Windows 95) en tiling: sin titulos (no hay hyprbars), solo
-- bordes. Ventana activa = azul marino de la barra de titulo de Win95,
-- inactiva = gris de la barra inactiva. Sin rounding, blur, sombras ni
-- animaciones. Todos los themes setean las mismas claves.

-- Mantener igual a CURSOR_THEME/CURSOR_SIZE de theme.sh
hl.env("XCURSOR_THEME", "Chicago95 Standard Cursors Black")
hl.env("XCURSOR_SIZE",  "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in     = 2,
        gaps_out    = 4,
        border_size = 3,
        col = {
            active_border   = "rgba(000080ff)",
            inactive_border = "rgba(808080ff)",
        },
    },

    decoration = {
        rounding         = 0,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled  = false,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    -- Win95 no animaba nada: workspaces y ventanas aparecen de golpe
    animations = {
        enabled = false,
    },
})
