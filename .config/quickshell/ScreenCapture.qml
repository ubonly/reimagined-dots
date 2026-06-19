// ScreenCapture.qml — Chrome OS-style Screen Capture toolbar
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "Theme"

PanelWindow {
    id: capture
    property var screenRef
    property bool isOpen: false

    screen: screenRef
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-capture"
    property bool isCapturing: captureProc.running
    WlrLayershell.keyboardFocus: (isOpen && !isCapturing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: isOpen
    color: "transparent"

    property bool hideContentsForCapture: false

    onIsOpenChanged: {
        if (isOpen) {
            hideContentsForCapture = false
            Qt.callLater(function() { focusCatcher.forceActiveFocus() })
        } else {
            isDragging = false
        }
    }

    // ── State ──────────────────────────────────────────────────────────────
    // "screenshot" or "record"
    property string captureType: "screenshot"
    // "fullscreen", "region", or "window"
    property string captureMode: "region"

    // ── Palette ────────────────────────────────────────────────────────────
    readonly property color barBg:        Theme.surfaceVariant
    readonly property color barBorder:    Theme.outline
    readonly property color btnDefault:   Qt.rgba(1, 1, 1, 0.0)
    readonly property color btnHover:     Theme.outlineVariant
    readonly property color btnActive:    Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
    readonly property color accentColor:  Theme.primary
    readonly property color textPrimary:  Theme.colorOnSurface
    readonly property color textSecondary:Theme.colorOnSurfaceVariant
    readonly property color dividerColor: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.10)

    // ── Native Region Selection ───────────────────────────────────────────
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragCurX: 0
    property real dragCurY: 0
    property bool isDragging: false

    readonly property real selX: Math.min(dragStartX, dragCurX)
    readonly property real selY: Math.min(dragStartY, dragCurY)
    readonly property real selW: Math.abs(dragCurX - dragStartX)
    readonly property real selH: Math.abs(dragCurY - dragStartY)

    // ── Commands ──────────────────────────────────────────────────────────
    function getCommand() {
        var ts = "$(date +%Y-%m-%d_%H-%M-%S)"
        if (captureType === "screenshot") {
            if (captureMode === "fullscreen") return "mkdir -p \"$HOME/Pictures\"; cp /tmp/screen_freeze.png \"$HOME/Pictures/Screenshot_" + ts + ".png\" && wl-copy --type image/png < \"$HOME/Pictures/Screenshot_" + ts + ".png\""
            if (captureMode === "window")     return "mkdir -p \"$HOME/Pictures\"; hyprshot -z -s -m window -o \"$HOME/Pictures\" -f Screenshot_" + ts + ".png"
            if (captureMode === "region")     return "mkdir -p \"$HOME/Pictures\"; hyprshot -z -s -m region -o \"$HOME/Pictures\" -f Screenshot_" + ts + ".png"
            if (captureMode === "grimblast-region") return "mkdir -p \"$HOME/Pictures\"; grimblast --freeze copysave area \"$HOME/Pictures/Screenshot_" + ts + ".png\""
        } else {
            var vid = "$HOME/Videos/Screenrecord_" + ts + ".mp4"
            var notifyStart = "(action=$(notify-send -a \"Screen Recorder\" \"Запись экрана начата\" \"Нажмите Super+Shift+S для остановки.\" -A \"stop=Остановить\"); if [ \"$action\" = \"stop\" ]; then pkill -SIGINT wf-recorder; fi) & "
            if (captureMode === "fullscreen") return "mkdir -p \"$HOME/Videos\"; " + notifyStart + "exec wf-recorder -o \"" + capture.screenRef.name + "\" -f \"" + vid + "\""
            if (captureMode === "window")     return "mkdir -p \"$HOME/Videos\"; " + notifyStart + "exec wf-recorder -f \"" + vid + "\""
            if (captureMode === "region")     return "mkdir -p \"$HOME/Videos\"; " + notifyStart + "exec wf-recorder -f \"" + vid + "\""
        }
        return ""
    }

    Process {
        id: captureProc
        command: ["bash", "-c", ""]
        onRunningChanged: {
            if (!running) {
                if (capture.isOpen) {
                    capture.isOpen = false
                }
                if (capture.captureType === "record") {
                    notifyProc.running = true
                }
            }
        }
    }

    Process {
        id: notifyProc
        command: ["notify-send", "-a", "Screen Recorder", "Запись экрана завершена", "Сохранено в ~/Videos"]
    }

    Timer {
        id: captureDelayTimer
        interval: 35
        repeat: false
        property string commandToRun: ""
        onTriggered: {
            capture.isOpen = false
            captureProc.command = ["bash", "-c", commandToRun]
            captureProc.running = true
        }
    }

    function doCapture(hideFirst) {
        var cmd = getCommand()
        if (!cmd) return
        if (hideFirst) {
            // Close overlay first, then bash sleeps 1s for fade-out to finish
            capture.isOpen = false
        }
        captureProc.command = ["bash", "-c", cmd]
        captureProc.running = true
    }

    property string frozenImage: ""
    property bool _freezePending: false

    Process {
        id: freezeProc
        command: ["bash", "-c", "grim -o \"" + capture.screenRef.name + "\" /tmp/screen_freeze.png"]
        onRunningChanged: {
            if (!running && _freezePending) {
                _freezePending = false
                capture.frozenImage = "file:///tmp/screen_freeze.png?" + Date.now()
                capture.isOpen = true
                focusCatcher.forceActiveFocus()
            }
        }
    }

    function prepareAndOpen(mode) {
        if (freezeProc.running) return
        captureType = "screenshot"
        captureMode = mode
        _freezePending = true
        freezeProc.running = true
    }

    function openRegionImmediate() {
        prepareAndOpen("region")
    }

    function openFullscreenWait() {
        prepareAndOpen("fullscreen")
    }

    function toggle() {
        if (captureProc.running) {
            captureProc.running = false
            return
        }
        if (isOpen) {
            isOpen = false
        } else {
            prepareAndOpen("region")
        }
    }

    Item {
        id: focusCatcher
        focus: capture.isOpen
        Keys.onReturnPressed: function(event) { capture.doCapture(true); event.accepted = true; }
        Keys.onEnterPressed: function(event) { capture.doCapture(true); event.accepted = true; }
        Keys.onEscapePressed: function(event) { capture.isOpen = false; event.accepted = true; }
    }



    // ── Dimming and Cutout ───────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: capture.isOpen && !capture.hideContentsForCapture && (capture.captureMode === "region" || capture.captureMode === "fullscreen" || capture.captureMode === "window")

        // Display the frozen screen image
        Image {
            anchors.fill: parent
            source: capture.frozenImage
            visible: capture.frozenImage !== ""
            fillMode: Image.PreserveAspectCrop
        }

        // Base dimming if not dragging
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)
            visible: !capture.isDragging
        }

        // 4 rectangles for cutout when dragging
        Item {
            anchors.fill: parent
            visible: capture.isDragging
            
            Rectangle { x: 0; y: 0; width: parent.width; height: capture.selY; color: Qt.rgba(0,0,0,0.4) }
            Rectangle { x: 0; y: capture.selY + capture.selH; width: parent.width; height: parent.height - (capture.selY + capture.selH); color: Qt.rgba(0,0,0,0.4) }
            Rectangle { x: 0; y: capture.selY; width: capture.selX; height: capture.selH; color: Qt.rgba(0,0,0,0.4) }
            Rectangle { x: capture.selX + capture.selW; y: capture.selY; width: parent.width - (capture.selX + capture.selW); height: capture.selH; color: Qt.rgba(0,0,0,0.4) }
            
            Rectangle {
                x: capture.selX; y: capture.selY; width: capture.selW; height: capture.selH
                color: "transparent"
                border.color: capture.accentColor
                border.width: 1.5
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    capture.isOpen = false
                    return
                }
                capture.isDragging = true
                capture.dragStartX = mouse.x
                capture.dragStartY = mouse.y
                capture.dragCurX = mouse.x
                capture.dragCurY = mouse.y
            }

            onPositionChanged: function(mouse) {
                if (capture.isDragging) {
                    capture.dragCurX = mouse.x
                    capture.dragCurY = mouse.y
                }
            }

            onReleased: function(mouse) {
                if (!capture.isDragging) return
                capture.isDragging = false
                capture.doCustomRegionCapture()
            }
        }
    }

    function doCustomRegionCapture() {
        if (selW < 10 || selH < 10) {
            isOpen = false
            return
        }

        var cX = Math.max(0, Math.round(selX))
        var cY = Math.max(0, Math.round(selY))
        var cW = Math.round(selW)
        var cH = Math.round(selH)

        if (cX + cW > capture.width) cW = capture.width - cX
        if (cY + cH > capture.height) cH = capture.height - cY

        var absX = Math.round(capture.screenRef.x + cX)
        var absY = Math.round(capture.screenRef.y + cY)
        var geometry = absX + "," + absY + " " + cW + "x" + cH

        var ts = "$(date +%Y-%m-%d_%H-%M-%S)"
        var cmd = ""
        if (captureType === "screenshot") {
            cmd = "mkdir -p \"$HOME/Pictures\"; ffmpeg -y -i /tmp/screen_freeze.png -vf \"crop=" + cW + ":" + cH + ":" + cX + ":" + cY + "\" \"$HOME/Pictures/Screenshot_" + ts + ".png\" && wl-copy --type image/png < \"$HOME/Pictures/Screenshot_" + ts + ".png\""
        } else {
            cmd = "mkdir -p \"$HOME/Videos\"; (action=$(notify-send -a \"Screen Recorder\" \"Запись экрана начата\" \"Нажмите Super+Shift+S для остановки.\" -A \"stop=Остановить\"); if [ \"$action\" = \"stop\" ]; then pkill -SIGINT wf-recorder; fi) & exec wf-recorder -g \"" + geometry + "\" -f \"$HOME/Videos/Screenrecord_" + ts + ".mp4\""
        }

        // Hide selection border/UI immediately
        capture.hideContentsForCapture = true

        // Let QML render the clean (transparent) frame, then run capture command
        // and close the window in the timer callback.
        captureDelayTimer.commandToRun = cmd
        captureDelayTimer.start()
    }


    // ── Main layout (Capture button + Toolbar) ────────────────────────────
    Column {
        visible: !capture.hideContentsForCapture
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 16
        }
        spacing: 12

        // ── Floating "Capture" / "Record" button ─────────────────────────────────
        Rectangle {
            id: captureButton
            visible: true
            anchors.horizontalCenter: parent.horizontalCenter
            width: captureButtonRow.implicitWidth + 32
            height: 40
            radius: 20
            color: captureBtnArea.containsMouse
                ? Qt.rgba(0.12, 0.14, 0.22, 0.98)
                : Qt.rgba(0.10, 0.12, 0.18, 0.96)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // Entrance animation
            opacity: (capture.isOpen && capture.captureMode !== "region") ? 1.0 : 0.0
            transformOrigin: Item.Bottom
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Row {
                id: captureButtonRow
                anchors.centerIn: parent
                spacing: 8

                Image {
                    id: captureBtnIcon
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    source: capture.captureType === "screenshot"
                        ? "assets/icons/screenshot.svg"
                        : "assets/icons/screen-record.svg"
                    sourceSize: Qt.size(18, 18)
                    visible: false
                }
                ColorOverlay {
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    source: captureBtnIcon
                    color: capture.textPrimary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: capture.captureType === "screenshot" ? "Capture" : "Record"
                    color: capture.textPrimary
                    font { pixelSize: 14; family: "Google Sans"; weight: Font.Medium }
                }
            }

            MouseArea {
                id: captureBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: capture.doCapture(true)
            }
        }

        // ── Toolbar pill ──────────────────────────────────────────────────
        Rectangle {
            id: toolbar
            anchors.horizontalCenter: parent.horizontalCenter
            width: toolbarRow.implicitWidth + 24
            height: 52
            radius: 26
            color: capture.barBg
            border.color: capture.barBorder
            border.width: 1

            // Entrance animation
            opacity: (capture.isOpen && !capture.isDragging) ? 1.0 : 0.0
            transformOrigin: Item.Bottom
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            // Block clicks from dismissing
            MouseArea { anchors.fill: parent; onClicked: {} }

            RowLayout {
                id: toolbarRow
                anchors.centerIn: parent
                spacing: 4

                // ═══════════════ Block 1: Capture Type ═══════════════
                // Screenshot button
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureType === "screenshot"
                        ? capture.btnActive
                        : screenshotArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureType === "screenshot" ? capture.accentColor : "transparent"
                    border.width: capture.captureType === "screenshot" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: screenshotIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/screenshot.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: screenshotIcon
                        color: Qt.rgba(1, 1, 1, capture.captureType === "screenshot" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: screenshotArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureType = "screenshot"
                    }
                }

                // Record button
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureType === "record"
                        ? capture.btnActive
                        : recordArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureType === "record" ? capture.accentColor : "transparent"
                    border.width: capture.captureType === "record" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: recordIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/screen-record.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: recordIcon
                        color: Qt.rgba(1, 1, 1, capture.captureType === "record" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: recordArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureType = "record"
                    }
                }

                // ═══════════════ Divider 1 ═══════════════
                Rectangle {
                    width: 1; height: 28
                    color: capture.dividerColor
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                }

                // ═══════════════ Block 2: Capture Mode ═══════════════
                // Fullscreen
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureMode === "fullscreen"
                        ? capture.btnActive
                        : fullscreenArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureMode === "fullscreen" ? capture.accentColor : "transparent"
                    border.width: capture.captureMode === "fullscreen" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: fullscreenIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/fullscreen.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: fullscreenIcon
                        color: Qt.rgba(1, 1, 1, capture.captureMode === "fullscreen" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: fullscreenArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureMode = "fullscreen"
                    }
                }

                // Region
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureMode === "region"
                        ? capture.btnActive
                        : regionArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureMode === "region" ? capture.accentColor : "transparent"
                    border.width: capture.captureMode === "region" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: regionIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/crop-region.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: regionIcon
                        color: Qt.rgba(1, 1, 1, capture.captureMode === "region" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: regionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureMode = "region"
                    }
                }

                // Window
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureMode === "window"
                        ? capture.btnActive
                        : windowArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureMode === "window" ? capture.accentColor : "transparent"
                    border.width: capture.captureMode === "window" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: windowIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/window-capture.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: windowIcon
                        color: Qt.rgba(1, 1, 1, capture.captureMode === "window" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: windowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureMode = "window"
                    }
                }

                // ═══════════════ Divider 2 ═══════════════
                Rectangle {
                    width: 1; height: 28
                    color: capture.dividerColor
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                }

                // ═══════════════ Block 3: Settings + Close ═══════════════
                // Settings (placeholder)
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: settingsArea.containsMouse ? capture.btnHover : capture.btnDefault
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: settingsIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/settings.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: settingsIcon
                        color: Qt.rgba(1, 1, 1, 0.6)
                    }

                    MouseArea {
                        id: settingsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {} // Placeholder
                    }
                }

                // Close
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: closeArea.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.15) : capture.btnDefault
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: closeIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/close.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: closeIcon
                        color: closeArea.containsMouse ? Qt.rgba(1, 0.5, 0.5, 1.0) : Qt.rgba(1, 1, 1, 0.6)
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.isOpen = false
                    }
                }
            }
        }
    }
}
