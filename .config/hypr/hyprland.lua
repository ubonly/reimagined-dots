-- Reimagined Hyprland config.
-- Hyprland 0.55+ loads Lua configs from ~/.config/hypr/hyprland.lua.
-- Keep hyprland.conf as a legacy fallback for older distro packages.

local home = os.getenv("HOME") or "/home/ubonly"

local function rgba(value)
    return "rgba(" .. value .. ")"
end

local colors = {
    primary = rgba("ffb598ff"),
    primary_container = rgba("71361cff"),
    secondary = rgba("e7beaeff"),
    secondary_container = rgba("5d4035ff"),
    tertiary = rgba("d3c78eff"),
    surface = rgba("1a110eff"),
    surface_container_low = rgba("231a16ff"),
    surface_container = rgba("271e1aff"),
    surface_container_high = rgba("322824ff"),
    outline = rgba("a08d86ff"),
    outline_variant = rgba("53433eff"),
    error = rgba("ffb4abff"),
}

local function load_matugen_colors(path)
    local file = io.open(path, "r")
    if not file then
        return
    end

    for line in file:lines() do
        local name, value = line:match("^%s*%$([%w_]+)%s*=%s*(rgba%([^)]+%))")
        if name and value then
            colors[name] = value
        end
    end

    file:close()
end

load_matugen_colors(home .. "/.config/hypr/myColors.conf")

local terminal = "kitty"
local file_manager = "dolphin"
local menu = "wofi"
local browser = "firefox"
local main_mod = "SUPER"

----------------
-- Monitors
----------------

hl.monitor({
    output = "DP-2",
    mode = "1920x1080@165",
    position = "0x0",
    scale = 1,
})

-- hl.monitor({
--     output = "HDMI-A-1",
--     mode = "3840x2160@120",
--     position = "auto",
--     scale = 3,
-- })

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})

----------------
-- Autostart
----------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("wl-paste --type text/uri-list --watch cliphist store")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
end)

----------------
-- Environment
----------------

hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

----------------
-- Look and feel
----------------

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 5,
        gaps_workspaces = 50,
        border_size = 1,
        col = {
            active_border = { colors = { colors.primary, colors.primary_container }, angle = 45 },
            inactive_border = colors.surface_container_low,
        },
        resize_on_border = true,
        no_focus_fallback = true,
        allow_tearing = true,
        snap = {
            enabled = true,
            window_gap = 4,
            monitor_gap = 5,
            respect_gaps = true,
        },
        layout = "scrolling",
    },

    decoration = {
        rounding = 18,
        rounding_power = 2,
        active_opacity = 1,
        inactive_opacity = 1,
        shadow = {
            enabled = true,
            range = 50,
            offset = { 0, 4 },
            render_power = 10,
            color = "rgba(00000027)",
        },
        blur = {
            enabled = true,
            xray = false,
            special = false,
            new_optimizations = true,
            size = 10,
            passes = 3,
            brightness = 1,
            contrast = 0.89,
            vibrancy = 0.5,
            vibrancy_darkness = 0.5,
            popups = false,
            popups_ignorealpha = 0.6,
            input_methods = true,
            input_methods_ignorealpha = 0.8,
        },
        dim_inactive = true,
        dim_strength = 0.05,
        dim_special = 0.2,
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,
        vrr = 1,
        font_family = "chillax",
    },

    input = {
        kb_layout = "us,ru",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.curve("expressiveFastSpatial", { type = "bezier", points = { { 0.42, 1.67 }, { 0.21, 0.90 } } })
hl.curve("expressiveSlowSpatial", { type = "bezier", points = { { 0.39, 1.29 }, { 0.35, 0.98 } } })
hl.curve("expressiveDefaultSpatial", { type = "bezier", points = { { 0.38, 1.21 }, { 0.22, 1.00 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("standardDecel", { type = "bezier", points = { { 0, 0 }, { 0, 1 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.52, 0.03 }, { 0.72, 0.08 } } })
hl.curve("stall", { type = "bezier", points = { { 1, -0.1 }, { 0.7, 0.85 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "emphasizedDecel", style = "popin 80%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "emphasizedDecel" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "emphasizedDecel", style = "popin 90%" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "emphasizedDecel" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "emphasizedDecel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.7, bezier = "emphasizedDecel", style = "popin 93%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.4, bezier = "menu_accel", style = "popin 94%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.5, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.7, bezier = "stall" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.2, bezier = "emphasizedAccel", style = "slidevert" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "standardDecel" })

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

----------------
-- Keybindings
----------------

local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts)
end

local function exec(command)
    return hl.dsp.exec_cmd(command)
end

bind(main_mod .. " + Q", exec(terminal))
bind(main_mod .. " + C", hl.dsp.window.close())
bind(main_mod .. " + M", exec("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
bind(main_mod .. " + E", exec(file_manager))
bind(main_mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
bind(main_mod .. " + X", exec(menu))
bind(main_mod .. " + P", hl.dsp.window.pseudo())
bind(main_mod .. " + B", exec(browser))
bind(main_mod .. " + L", exec("sh -c \"$HOME/.config/hypr/lock.sh\""))
bind(main_mod .. " + SHIFT + W", exec("qs ipc call WallpaperSelector toggle"))
bind(main_mod .. " + SHIFT + V", hl.dsp.global("quickshell:clipboardToggle"), { desc = "Toggle clipboard" })

bind(main_mod .. " + F1", exec("sh -c \"/home/ubonly/Downloads/Antigravity/Antigravity-x64/antigravity\""))
bind(main_mod .. " + F2", exec("sh -c \"/home/ubonly/Downloads/Antigravity\\ IDE/antigravity-ide\""))

bind("SUPER + SUPER_L", exec("qs ipc call launcher toggle"), { release = true, desc = "Toggle search" })
bind("SUPER + SUPER_R", exec("qs ipc call launcher toggle"), { release = true, desc = "Toggle search" })
bind("SUPER + I", hl.dsp.global("quickshell:settingsToggle"), { desc = "Toggle Settings" })
bind("F13", exec("hyprctl notify 1 1500 \"rgb(00ff00)\" \"F13 received\""))
bind("SUPER + SHIFT + S", hl.dsp.global("quickshell:captureRegion"), { desc = "Screen Capture Region" })
bind("Print", hl.dsp.global("quickshell:captureFullscreen"), { desc = "Screen Capture Fullscreen" })
bind("SUPER + ALT + S", exec("hyprshot -m window --clipboard-only"))

bind(main_mod .. " + left", hl.dsp.focus({ direction = "left" }))
bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }))
bind(main_mod .. " + up", hl.dsp.focus({ direction = "up" }))
bind(main_mod .. " + down", hl.dsp.focus({ direction = "down" }))

for workspace = 1, 10 do
    local key = workspace % 10
    bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
bind("XF86MonBrightnessUp", exec("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
bind("XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
bind("XF86AudioNext", exec("playerctl next"), { locked = true })
bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })

----------------
-- Rules
----------------

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name = "vesktop",
    match = { class = "vesktop" },
    border_size = 1,
    opacity = 0.95,
})

local layer_rules = {
    { name = "hyprpicker-no-anim", namespace = "hyprpicker", no_anim = true },
    { name = "selection-no-anim", namespace = "selection", no_anim = true },
    { name = "slurp-no-anim", namespace = "slurp", no_anim = true },
    { name = "quickshell-dock-blur", namespace = "quickshell-dock", blur = true },
    { name = "quickshell-dock-xray", namespace = "quickshell-dock", xray = false },
    { name = "quickshell-dock-ignore-alpha", namespace = "quickshell-dock", ignore_alpha = 0.5 },
    { name = "quickshell-launcher-no-anim", namespace = "quickshell-launcher", no_anim = true },
    { name = "quickshell-quicksettings-no-anim", namespace = "quickshell-quicksettings", no_anim = true },
    { name = "quickshell-notif-center-no-anim", namespace = "quickshell-notif-center", no_anim = true },
    { name = "quickshell-notifications-no-anim", namespace = "quickshell-notifications", no_anim = true },
}

for _, rule in ipairs(layer_rules) do
    local namespace = rule.namespace
    rule.namespace = nil
    rule.match = { namespace = namespace }
    hl.layer_rule(rule)
end

hl.window_rule({
    name = "steam-app-immediate",
    match = { namespace = "^(steam_app_2012840)$" },
    immediate = true,
})

hl.window_rule({
    name = "zen-browser-opaque",
    match = { namespace = "zen-browser" },
    opaque = true,
})

hl.window_rule({
    name = "zen-browser-opacity",
    match = { namespace = "zen-browser" },
    opacity = "1.0 override 1.0 override",
})

hl.window_rule({
    name = "quickshell-settings",
    match = {
        class = "org.quickshell",
        title = "Settings",
    },
    float = true,
    size = "920 620",
    center = true,
    border_size = 0,
})

hl.window_rule({
    name = "quickshell-clipboard",
    match = {
        class = "org.quickshell",
        title = "Clipboard",
    },
    float = true,
    size = "340 440",
    center = true,
    border_size = 0,
})
