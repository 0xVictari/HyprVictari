-- =============================================================================
-- hyprland.lua  |  ~/.config/hypr/hyprland.lua
-- Hyprland 0.55.0
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
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/Scripts/wallpaper.sh")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("flameshot")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/Scripts/hyprsunset.sh")
end)

-- =============================
---- ENVIRONMENT VARIABLES ----
-- =============================
hl.env("XCURSOR_THEME",                       "Qogir-dark-cursors")
hl.env("XCURSOR_SIZE",                        "24")
hl.env("HYPRCURSOR_SIZE",                     "24")
hl.env("XDG_SESSION_TYPE",                    "wayland")
hl.env("XDG_SESSION_DESKTOP",                 "Hyprland")
hl.env("QT_QPA_PLATFORM",                     "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",         "1")
hl.env("MOZ_ENABLE_WAYLAND",                  "1")
hl.env("GDK_SCALE",                           "1")
hl.env("WLR_NO_HARDWARE_CURSORS",             "1")

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

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
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
hl.window_rule({ match = { class = "^steam$" },                immediate = true })
hl.window_rule({ match = { class = "^steam$" },                force_rgbx = true })
-- hl.window_rule({ match = { class = "^steamwebhelper$" },       immediate = true })
-- hl.window_rule({ match = { class = "^steam_app.*" },           immediate = true })
hl.window_rule({ match = { class = "^steam$", title = "^notificationtoasts" }, no_initial_focus = true })
hl.window_rule({ match = { class = "^dev.zed.Zed$" },         workspace = "4 silent" })

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
        explicit_column_widths   = "0.333 0.5 0.667 1.0",
    },
})

-- ====================
---- KEYBINDINGS  ----
-- ====================
local mainMod = "SUPER"

-- Teclas para workspaces 1-9 en latam (mismo que qwerty para numeros)
local wsKeys = { "1","2","3","4","5","6","7","8","9" }

-- Apps y acciones generales
hl.bind(mainMod .. " + Q",       hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C",       hl.dsp.window.close())
hl.bind(mainMod .. " + M",       hl.dsp.exit())
hl.bind(mainMod .. " + E",       hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F",       hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R",       hl.dsp.exec_cmd("killall wofi || " .. menu))
hl.bind(mainMod .. " + P",       hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",       hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + L",       hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + B",       hl.dsp.exec_cmd("killall hyprsunset || hyprsunset -t 4000"))

hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd(
    os.getenv("HOME") .. "/.config/hypr/Scripts/gaming-mode-toggle.sh && pkill -RTMIN+8 waybar"
))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("flameshot gui"))
hl.bind("CTRL + ALT + W",        hl.dsp.exec_cmd("killall waybar || waybar"))

-- Foco con flechas
hl.bind(mainMod .. " + left",    hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right",   hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",      hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",    hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-9
for i = 1, 9 do
    local key = wsKeys[i]
    hl.bind(mainMod .. " + " .. key,       hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
-- Workspace 10
hl.bind(mainMod .. " + 0",       hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))
-- Workspace anterior
hl.bind(mainMod .. " + TAB",     hl.dsp.focus({ workspace = "previous" }))

-- Scratchpad
hl.bind(mainMod .. " + A",       hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mouse: mover/resize ventanas
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Mouse: scroll entre workspaces
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))

-- Scrolling layout: scroll columnas con rueda
hl.bind(mainMod .. " + mouse_down", hl.dsp.layout("move -col"))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.layout("move +col"))

-- Scrolling layout: mover columna izq/der
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.layout("swapcol l"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.layout("swapcol r"))

-- Scrolling layout: resize columna
hl.bind(mainMod .. " + SHIFT + up",   hl.dsp.layout("colresize 1.0"))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.layout("colresize 0.5"))
