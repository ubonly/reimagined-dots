pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configDir: "/home/ubonly/.config/quickshell"
    readonly property string configPath: configDir + "/config.json"

    property alias values: configJsonAdapter
    property bool ready: false

    Timer {
        id: fileReloadTimer
        interval: 100
        repeat: false
        onTriggered: configFileView.reload()
    }

    Timer {
        id: fileWriteTimer
        interval: 100
        repeat: false
        onTriggered: {
            configFileView.writeAdapter()
            // Write legacy fallbacks for shell scripts
            writeTxt("theme_mode.txt", configJsonAdapter.themeMode)
            writeTxt("dock_style.txt", configJsonAdapter.dockStyle)
            writeTxt("dock_transparency_enabled.txt", configJsonAdapter.dockTransparencyEnabled ? "true" : "false")
            writeTxt("dock_opacity.txt", configJsonAdapter.dockOpacity.toFixed(2))
            writeTxt("dock_icon_fill_enabled.txt", configJsonAdapter.dockIconFillEnabled ? "true" : "false")
            writeTxt("konachan_tags.txt", configJsonAdapter.konachanTags)
            writeTxt("wallpaper_upscale_enabled.txt", configJsonAdapter.wallpaperUpscaleEnabled ? "true" : "false")
            writeTxt("wallpaper_upscale_factor.txt", configJsonAdapter.wallpaperUpscaleFactor.toString())
            writeTxt("dnd.txt", configJsonAdapter.dnd ? "true" : "false")
        }
    }

    function writeTxt(filename, content) {
        Quickshell.execDetached(["bash", "-c", "echo '" + content + "' > " + configDir + "/" + filename])
    }

    FileView {
        id: configFileView
        path: root.configPath
        watchChanges: true

        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: {
            if (root.ready) {
                fileWriteTimer.restart()
            }
        }
        onLoaded: root.ready = true
        onLoadFailed: error => {
            console.log("Failed to load config.json:", error);
            if (error == FileViewError.FileNotFound) {
                root.ready = true
                fileWriteTimer.restart()
            }
        }

        adapter: JsonAdapter {
            id: configJsonAdapter

            property string themeMode: "dark"
            property string dockStyle: "rounded"
            property bool dockTransparencyEnabled: false
            property real dockOpacity: 0.85
            property bool dockIconFillEnabled: false
            property string konachanTags: ""
            property bool wallpaperUpscaleEnabled: false
            property int wallpaperUpscaleFactor: 2
            property bool dnd: false
        }
    }
}
