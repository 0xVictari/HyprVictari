-- =============================================================================
-- hyprland.lua  |  ~/.config/hypr/hyprland.lua
-- Hyprland 0.57.0
-- =============================================================================

require("style")

-- ================
---- MONITORS ----
-- ================
hl.monitor({
    output   = "",
    mode     = "1920x1080@120",
    position = "auto",
    scale    = 1,
})

-- =====================
---- MY PROGRAMS ----
-- =====================
local terminal    = "kitty"
local fileManager = "nemo"
local menu        = "wofi --show drun"
local browser     = "brave"
local editor      = "zeditor"

-- =================
---- AUTOSTART ----
-- =================
hl.on("hyprland.start", function()
    -- theme-switch.sh --init: crea themes/current si falta, aplica GTK/cursor
    -- y levanta waybar (asi la barra ya arranca con los symlinks del theme)
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/Scripts/theme-switch.sh --init")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/Scripts/wallpaper.sh")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("flameshot")
    hl.exec_cmd("hyprsunset") -- horario 07:00/20:00 en hyprsunset.conf
end)

-- =============================
---- ENVIRONMENT VARIABLES ----
-- =============================
-- XCURSOR_THEME/SIZE: en themes/<theme>/hypr.lua
hl.env("XDG_SESSION_TYPE",                    "wayland")
hl.env("XDG_SESSION_DESKTOP",                 "Hyprland")
hl.env("QT_QPA_PLATFORM",                     "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",         "1")
hl.env("MOZ_ENABLE_WAYLAND",                  "1")
hl.env("GDK_SCALE",                           "1")

-- =============
---- INPUT ----
-- =============
hl.config({
    input = {
        kb_layout    = "latam",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-- ============
---- MISC ----
-- ============
hl.config({
    misc = {
        vrr = 0,
    },
})

-- ==============================
---- WINDOWS AND WORKSPACES ----
-- ==============================

hl.window_rule({ match = { class = ".*" },                      suppress_event = "maximize" })
hl.window_rule({ match = { class = "^org.telegram.desktop$" }, workspace = "2 silent" })
hl.window_rule({ match = { class = "^discord$" },              workspace = "3 silent" })
hl.window_rule({ match = { class = "^steam$" },                workspace = "5 silent" })
hl.window_rule({ match = { class = "^steam$" },                force_rgbx = true })
-- immediate (tearing) solo tiene efecto con general.allow_tearing = true (style.lua)
-- hl.window_rule({ match = { class = "^steamwebhelper$" },       immediate = true })
-- hl.window_rule({ match = { class = "^steam_app.*" },           immediate = true })
hl.window_rule({ match = { class = "^steam$", title = "^notificationtoasts" }, no_initial_focus = true })
hl.window_rule({ match = { class = "^dev.zed.Zed$" },         workspace = "4 silent" })
-- hl.window_rule({ match = { class = "^gunz.exe$" }, fullscreen = true })
-- ====================
---- LAYOUTS      ----
-- ====================
hl.workspace_rule({
    workspace = "4",
    layout    = "scrolling",
})

hl.config({
    scrolling = {
        column_width             = 0.5,
        fullscreen_on_one_column = true,
        follow_focus             = true,
        focus_fit_method         = 1,
        explicit_column_widths   = "0.333, 0.5, 0.667, 1.0",
    },
})

-- ====================
---- KEYBINDINGS  ----
-- ====================
-- Todo bind lleva description: Super+F1 los lista (Scripts/keybinds.sh).
local mainMod = "SUPER"
local scripts = os.getenv("HOME") .. "/.config/hypr/Scripts/"

-- Teclas para workspaces 1-9 en latam (mismo que qwerty para numeros)
local wsKeys = { "1","2","3","4","5","6","7","8","9" }

-- Apps y acciones generales
hl.bind(mainMod .. " + Q",       hl.dsp.exec_cmd(terminal),                         { description = "Terminal" })
hl.bind(mainMod .. " + C",       hl.dsp.window.close(),                             { description = "Cerrar ventana" })
hl.bind(mainMod .. " + M",       hl.dsp.exit(),                                     { description = "Salir de Hyprland" })
hl.bind(mainMod .. " + E",       hl.dsp.exec_cmd(fileManager),                      { description = "Archivos" })
hl.bind(mainMod .. " + F",       hl.dsp.window.float({ action = "toggle" }),        { description = "Alternar flotante" })
hl.bind(mainMod .. " + R",       hl.dsp.exec_cmd("killall wofi || " .. menu),       { description = "Lanzador" })
hl.bind(mainMod .. " + P",       hl.dsp.window.pseudo(),                            { description = "Pseudo-tile (dwindle)" })
hl.bind(mainMod .. " + J",       hl.dsp.layout("togglesplit"),                      { description = "Alternar split (dwindle)" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen(),                      { description = "Pantalla completa" })
hl.bind(mainMod .. " + L",       hl.dsp.exec_cmd("hyprlock"),                       { description = "Bloquear pantalla" })
hl.bind(mainMod .. " + B",       hl.dsp.exec_cmd(scripts .. "hyprsunset-toggle.sh"), { description = "Luz calida / neutra" })
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd(scripts .. "gaming-mode-toggle.sh"), { description = "Modo gaming" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("flameshot gui"),                { description = "Captura de region" })
hl.bind("CTRL + ALT + W",        hl.dsp.exec_cmd("killall waybar || waybar"),       { description = "Mostrar / ocultar Waybar" })
hl.bind(mainMod .. " + T",       hl.dsp.exec_cmd(scripts .. "theme-switch.sh"),     { description = "Elegir theme" })
hl.bind(mainMod .. " + F1",      hl.dsp.exec_cmd(scripts .. "keybinds.sh"),         { description = "Esta lista de atajos" })

-- Foco con flechas
hl.bind(mainMod .. " + left",    hl.dsp.focus({ direction = "left" }),  { description = "Foco a la izquierda" })
hl.bind(mainMod .. " + right",   hl.dsp.focus({ direction = "right" }), { description = "Foco a la derecha" })
hl.bind(mainMod .. " + up",      hl.dsp.focus({ direction = "up" }),    { description = "Foco arriba" })
hl.bind(mainMod .. " + down",    hl.dsp.focus({ direction = "down" }),  { description = "Foco abajo" })

-- Workspaces 1-9
for i = 1, 9 do
    local key = wsKeys[i]
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       { description = "Ir al workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Mover ventana al workspace " .. i })
end
-- Workspace 10
hl.bind(mainMod .. " + 0",         hl.dsp.focus({ workspace = 10 }),       { description = "Ir al workspace 10" })
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }), { description = "Mover ventana al workspace 10" })
-- Workspace anterior
hl.bind(mainMod .. " + TAB",     hl.dsp.focus({ workspace = "previous" }), { description = "Workspace anterior" })

-- Scratchpad
hl.bind(mainMod .. " + A",         hl.dsp.workspace.toggle_special("magic"),               { description = "Mostrar / ocultar scratchpad" })
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "special:magic" }),    { description = "Mover ventana al scratchpad" })

-- Mouse: mover/resize ventanas
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Arrastrar ventana" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Redimensionar ventana" })

-- Mouse: scroll entre workspaces
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Siguiente workspace con ventanas" })
hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace anterior con ventanas" })

-- Scrolling layout: scroll columnas con rueda
hl.bind(mainMod .. " + mouse_down", hl.dsp.layout("move -col"), { description = "Scrolling: columna anterior" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.layout("move +col"), { description = "Scrolling: columna siguiente" })

-- Scrolling layout: mover columna izq/der
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.layout("swapcol l"), { description = "Scrolling: mover columna a la izquierda" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.layout("swapcol r"), { description = "Scrolling: mover columna a la derecha" })

-- Scrolling layout: resize columna
hl.bind(mainMod .. " + SHIFT + up",   hl.dsp.layout("colresize 1.0"), { description = "Scrolling: columna a ancho completo" })
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.layout("colresize 0.5"), { description = "Scrolling: columna a la mitad" })

-- Teclas multimedia (locked: andan con la pantalla bloqueada). Brillo: sin
-- backlight (desktop) brightnessctl no hace nada; en una laptop si.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Subir volumen" })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Bajar volumen" })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, description = "Silenciar" })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "Silenciar microfono" })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true, description = "Subir brillo" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true, description = "Bajar brillo" })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                          { locked = true, description = "Play / pausa" })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                          { locked = true, description = "Play / pausa" })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                { locked = true, description = "Pista siguiente" })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                            { locked = true, description = "Pista anterior" })

