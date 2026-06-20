pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int brightness: 100
    property int maxBrightness: 100
    property bool ready: false

    Process {
        id: initProc
        command: ["sh", "-c", "echo \"$(brightnessctl g) $(brightnessctl m)\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(" ");
                if (parts.length >= 2) {
                    var current = parseInt(parts[0]);
                    var max = parseInt(parts[1]);
                    if (!isNaN(current) && !isNaN(max) && max > 0) {
                        root.maxBrightness = max;
                        root.brightness = Math.round((current / max) * 100);
                    }
                }
                root.ready = true;
            }
        }
    }

    function setBrightness(v) {
        v = Math.max(1, Math.min(100, v));
        root.brightness = v;
        Quickshell.execDetached(["brightnessctl", "set", v + "%"]);
    }
}
