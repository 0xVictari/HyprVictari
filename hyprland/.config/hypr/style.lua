-- =============================================================================
-- style.lua  |  ~/.config/hypr/style.lua
-- require("style") desde hyprland.lua
-- Lo comun a todos los themes. Lo visual (bordes, gaps, rounding, blur,
-- sombras, animaciones, cursor) esta en themes/<theme>/hypr.lua; el activo es
-- el symlink themes/current (Super+T, Scripts/theme-switch.sh).
-- =============================================================================

hl.config({
    general = {
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})

-- Sin themes/current (clon nuevo, antes del primer theme-switch.sh) cae a
-- tokyonight. Ojo: pcall tambien oculta un error dentro del theme; luac -p
-- en check.sh lo detecta.
if not pcall(require, "themes.current.hypr") then
    require("themes.tokyonight.hypr")
end
