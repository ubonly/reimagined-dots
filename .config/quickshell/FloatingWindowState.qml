// Persists Hyprland floating-window placement for Quickshell windows.
import Quickshell
import Quickshell.Io
import QtQuick
import "services"

Item {
    id: root

    property string windowTitle: ""
    property string kind: "settings"
    property bool active: false
    property int restoreDelay: 180
    property int pollInterval: 700

    onActiveChanged: {
        if (active) {
            restoreTimer.restart();
        } else {
            saveNow();
        }
    }

    function savedX() {
        if (!ConfigService.ready)
            return -1;
        return kind === "clipboard" ? ConfigService.values.clipboardWindowX : ConfigService.values.settingsWindowX;
    }

    function savedY() {
        if (!ConfigService.ready)
            return -1;
        return kind === "clipboard" ? ConfigService.values.clipboardWindowY : ConfigService.values.settingsWindowY;
    }

    function setSavedPosition(px, py) {
        if (!ConfigService.ready || isNaN(px) || isNaN(py))
            return;

        if (kind === "clipboard") {
            ConfigService.values.clipboardWindowX = px;
            ConfigService.values.clipboardWindowY = py;
        } else {
            ConfigService.values.settingsWindowX = px;
            ConfigService.values.settingsWindowY = py;
        }
    }

    function restoreNow() {
        if (!ConfigService.ready)
            return;

        var px = savedX();
        var py = savedY();
        if (px < 0 || py < 0)
            return;

        Quickshell.execDetached([
            "hyprctl",
            "dispatch",
            "movewindowpixel",
            "exact " + Math.round(px) + " " + Math.round(py) + ",title:" + windowTitle
        ]);
    }

    function saveNow() {
        if (!ConfigService.ready || windowTitle === "" || saveProc.running)
            return;

        saveProc.command = [
            "bash",
            "-c",
            "hyprctl clients -j | jq -r --arg title \"$1\" '.[] | select(.class == \"org.quickshell\" and .title == $title) | \"\\(.at[0]) \\(.at[1])\"' | head -n1",
            "--",
            windowTitle
        ];
        saveProc.running = true;
    }

    Timer {
        id: restoreTimer
        interval: root.restoreDelay
        repeat: false
        onTriggered: root.restoreNow()
    }

    Timer {
        interval: root.pollInterval
        repeat: true
        running: root.active
        onTriggered: root.saveNow()
    }

    Process {
        id: saveProc
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(/\s+/);
                if (parts.length < 2)
                    return;

                var px = parseInt(parts[0], 10);
                var py = parseInt(parts[1], 10);
                root.setSavedPosition(px, py);
            }
        }
    }
}
