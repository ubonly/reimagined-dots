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
        }
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
            property string wallpaperPath: ""
            property string wallpaperState: ""
            property string matugenScheme: "scheme-tonal-spot"
            property bool use24Hour: true
            property real clipboardWindowX: -1
            property real clipboardWindowY: -1
        }
    }
}
