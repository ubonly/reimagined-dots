import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import "services"

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

    function isVideo(path) {
        if (!path) return false;
        let p = path.toLowerCase();
        return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
    }

    // 1. Old wallpaper (always shown underneath)
    Image {
        id: bgOld
        anchors.fill: parent
        source: ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false  // load sync so first wallpaper shows instantly
        opacity: root.isVideo(root.lastWallpaperPath) ? 0.0 : 1.0
        visible: opacity > 0.0
        Behavior on opacity { NumberAnimation { duration: 500 } }
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
        let sig = reloadKey + ":" + filePath

        if (sig === root.lastWallpaperSig || sig === root.loadingWallpaperSig || sig === root.queuedWallpaperSig) {
            return
        }

        if (isVideo(filePath)) {
            // For video wallpaper: stop any active animation, immediately set lastWallpaperPath
            root.wallpaperAnimating = false;
            bgNew.source = "";
            root.lastWallpaperSig = sig;
            root.lastWallpaperPath = filePath;
            return;
        }

        let src = "file://" + filePath + "?v=" + reloadKey

        if (bgOld.source == "" || isVideo(root.lastWallpaperPath)) {
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

    // Apply the initial wallpaper once ConfigService is ready
    Component.onCompleted: {
        if (ConfigService.ready) {
            applyInitialWallpaper();
        }
    }

    Connections {
        target: ConfigService
        ignoreUnknownSignals: true
        
        function onReadyChanged() {
            if (ConfigService.ready) {
                applyInitialWallpaper();
            }
        }

        function onValuesChanged() {
            if (ConfigService.ready) {
                applyConfigWallpaper();
            }
        }
    }

    function applyInitialWallpaper() {
        var raw = ConfigService.values.wallpaperState;
        if (raw && raw !== "") {
            applyConfigWallpaper();
        } else {
            var path = ConfigService.values.wallpaperPath;
            if (path && path !== "") {
                root.applyWallpaper(path, "0");
            }
        }
    }

    function applyConfigWallpaper() {
        var raw = ConfigService.values.wallpaperState;
        if (!raw || raw === "") return;

        var sep = raw.indexOf("|");
        if (sep < 0) return;

        var reloadKey = raw.substring(0, sep);
        var p = raw.substring(sep + 1);
        var sig = reloadKey + ":" + p;
        if (p !== "" && sig !== root.lastWallpaperSig) {
            root.applyWallpaper(p, reloadKey);
        }
    }
}
