import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "background"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1

    color: "#000000"

    property string lastWallpaperSig: ""
    property string lastWallpaperPath: ""
    property string loadingWallpaperSig: ""
    property string loadingWallpaperPath: ""
    property string queuedWallpaperSig: ""
    property string queuedWallpaperPath: ""
    property bool wallpaperAnimating: false

    // 1. Old wallpaper (always shown underneath)
    Image {
        id: bgOld
        anchors.fill: parent
        source: ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false  // load sync so first wallpaper shows instantly
    }

    // 2. New wallpaper — hidden, used as mask source
    Image {
        id: bgNew
        anchors.fill: parent
        source: ""
        fillMode: Image.PreserveAspectCrop
        visible: false
        cache: false
        asynchronous: true

        // Start animation ONLY when image is fully loaded
        onStatusChanged: {
            if (status === Image.Ready) {
                if (root.loadingWallpaperSig !== "") {
                    root.wallpaperAnimating = true
                    circleMask.scale = 0.0
                    growAnim.restart()
                }
            } else if (status === Image.Error) {
                if (root.loadingWallpaperSig !== "") {
                    bgNew.source = ""
                    root.loadingWallpaperSig = ""
                    root.loadingWallpaperPath = ""
                    root.wallpaperAnimating = false
                    if (root.queuedWallpaperSig !== "") {
                        let queuedSig = root.queuedWallpaperSig
                        let queuedPath = root.queuedWallpaperPath
                        root.queuedWallpaperSig = ""
                        root.queuedWallpaperPath = ""
                        root.applyWallpaper(queuedPath, queuedSig)
                    }
                }
            }
        }
    }

    // 3. Circle mask
    Item {
        id: maskRoot
        anchors.fill: parent
        visible: false
        Rectangle {
            id: circleMask
            width: 100
            height: 100
            radius: 50
            anchors.centerIn: parent
            color: "white"
            scale: 0.0
        }
    }

    // 4. Masked new wallpaper
    OpacityMask {
        anchors.fill: parent
        source: bgNew
        maskSource: maskRoot
        visible: bgNew.source != ""
    }

    property real maxScale: (Math.sqrt(root.width * root.width + root.height * root.height) * 1.5) / 100.0

    // 5. Grow animation
    NumberAnimation {
        id: growAnim
        target: circleMask
        property: "scale"
        from: 0.0
        to: root.maxScale
        duration: 1800
        easing.type: Easing.OutCubic

        onFinished: {
            bgOld.source = bgNew.source
            circleMask.scale = 0.0
            bgNew.source = ""
            root.lastWallpaperSig = root.loadingWallpaperSig
            root.lastWallpaperPath = root.loadingWallpaperPath
            root.loadingWallpaperSig = ""
            root.loadingWallpaperPath = ""
            root.wallpaperAnimating = false
            if (root.queuedWallpaperSig !== "") {
                let queuedSig = root.queuedWallpaperSig
                let queuedPath = root.queuedWallpaperPath
                root.queuedWallpaperSig = ""
                root.queuedWallpaperPath = ""
                root.applyWallpaper(queuedPath, queuedSig)
            }
        }
    }

    function applyWallpaper(filePath, reloadKey) {
        let src = "file://" + filePath + "?v=" + reloadKey
        let sig = reloadKey + ":" + filePath

        if (sig === root.lastWallpaperSig || sig === root.loadingWallpaperSig || sig === root.queuedWallpaperSig) {
            return
        }

        if (bgOld.source == "") {
            bgOld.source = src
            root.lastWallpaperSig = sig
            root.lastWallpaperPath = filePath
            return
        }

        if (root.wallpaperAnimating) {
            root.queuedWallpaperSig = sig
            root.queuedWallpaperPath = filePath
            return
        }

        root.loadingWallpaperSig = sig
        root.loadingWallpaperPath = filePath
        bgNew.source = src
        // animation starts in onStatusChanged when image is ready
    }

    Process {
        id: wallpaperWatchProc
        running: true
        command: ["bash", "-c", "state=/home/ubonly/.config/quickshell/wallpaper_state.txt; path=/home/ubonly/.config/quickshell/wallpaper_path.txt; touch \"$state\"; if [ -s \"$state\" ]; then cat \"$state\"; elif [ -s \"$path\" ]; then printf '0|%s\\n' \"$(head -n1 \"$path\")\"; fi; tail -n 0 -F \"$state\" 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                let raw = data.trim()
                if (raw === "") return

                let sep = raw.indexOf("|")
                if (sep < 0) return

                let reloadKey = raw.substring(0, sep)
                let p = raw.substring(sep + 1)
                let sig = reloadKey + ":" + p
                if (p !== "" && sig !== root.lastWallpaperSig) {
                    root.applyWallpaper(p, reloadKey)
                }
            }
        }
    }
}
