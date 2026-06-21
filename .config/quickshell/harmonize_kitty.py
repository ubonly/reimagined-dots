import json
import os
import subprocess

config_dir = "/home/ubonly/.config/quickshell"
colors_json_path = os.path.join(config_dir, "colors.json")
kitty_colors_path = os.path.expanduser("~/.config/kitty/colors.conf")

if not os.path.exists(colors_json_path):
    print("colors.json not found")
    exit(1)

with open(colors_json_path, "r") as f:
    data = json.load(f)

mode = data.get("mode", "dark")

def get_color(category, name):
    cat_dict = data.get(category, {})
    color_dict = cat_dict.get(name, {})
    # Safely get color based on mode
    return color_dict.get(mode, color_dict.get("default", {})).get("color", "#ffffff")

# Write kitty colors.conf using core Material You colors with guaranteed contrast
theme_content = f"""# Dynamic Kitty theme generated from Material You
foreground           {get_color('colors', 'on_surface')}
background           {get_color('colors', 'surface_container_low')}
cursor               {get_color('colors', 'on_surface')}

active_tab_foreground      {get_color('colors', 'on_secondary_container')}
active_tab_background      {get_color('colors', 'secondary_container')}
inactive_tab_foreground    {get_color('colors', 'on_surface_variant')}
inactive_tab_background    {get_color('colors', 'surface_variant')}

active_border_color        {get_color('colors', 'primary')}
inactive_border_color      {get_color('colors', 'outline')}

# Black / Grey
color0               {get_color('colors', 'surface_container_lowest')}
color8               {get_color('colors', 'surface_container_highest')}

# Red (Error / invalid command)
color1               {get_color('colors', 'error')}
color9               {get_color('colors', 'error')}

# Green (Primary Accent)
color2               {get_color('colors', 'primary')}
color10              {get_color('colors', 'primary')}

# Yellow (Secondary Accent)
color3               {get_color('colors', 'secondary')}
color11              {get_color('colors', 'secondary')}

# Blue (Tertiary Accent)
color4               {get_color('colors', 'tertiary')}
color12              {get_color('colors', 'tertiary')}

# Magenta
color5               {get_color('colors', 'primary_container')}
color13              {get_color('colors', 'primary_container')}

# Cyan
color6               {get_color('colors', 'secondary_container')}
color14              {get_color('colors', 'secondary_container')}

# White
color7               {get_color('colors', 'on_surface')}
color15              {get_color('colors', 'on_surface_variant')}
"""

os.makedirs(os.path.dirname(kitty_colors_path), exist_ok=True)
with open(kitty_colors_path, "w") as f:
    f.write(theme_content)

# Trigger kitty reload
subprocess.run(["killall", "-USR1", "kitty"], stderr=subprocess.DEVNULL)
print("Kitty colors harmonized and reloaded.")
