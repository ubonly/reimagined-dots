// shell.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "Theme"
import "services"

ShellRoot {
    id: root
    // ── Global Configuration Service ───────────────────────────────────────
    property string dockStyle: ConfigService.ready ? ConfigService.values.dockStyle : "rounded"
    property bool dockTransparencyEnabled: ConfigService.ready ? ConfigService.values.dockTransparencyEnabled : false
    property real dockOpacity: ConfigService.ready ? ConfigService.values.dockOpacity : 0.85
    property bool dockIconFillEnabled: ConfigService.ready ? ConfigService.values.dockIconFillEnabled : false
    readonly property real effectiveDockOpacity: dockTransparencyEnabled ? dockOpacity : 1.0
    property bool dndMode: ConfigService.ready ? ConfigService.values.dnd : false

    property string kbLayout: "US"

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                var data = event.data;
                var commaIdx = data.indexOf(",");
                if (commaIdx >= 0) {
                    var layoutName = data.substring(commaIdx + 1);
                    root.updateKbLayout(layoutName);
                }
            }
        }
    }

    function updateKbLayout(raw) {
        if (!raw) return;
        var lower = raw.toLowerCase();
        if (lower.indexOf("russian") >= 0)       root.kbLayout = "RU";
        else if (lower.indexOf("english") >= 0)  root.kbLayout = "US";
        else if (lower.indexOf("german") >= 0)   root.kbLayout = "DE";
        else if (lower.indexOf("french") >= 0)   root.kbLayout = "FR";
        else if (lower.indexOf("spanish") >= 0)  root.kbLayout = "ES";
        else if (lower.indexOf("ukraine") >= 0)  root.kbLayout = "UA";
        else if (raw.length > 0 && raw.length <= 3)          root.kbLayout = raw.toUpperCase();
        else if (raw.length > 3)                             root.kbLayout = raw.substring(0, 2).toUpperCase();
        else                                                  root.kbLayout = "US";
    }

    Process {
        id: initialKbProc
        command: ["bash", "-c", "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[0].active_keymap' 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                root.updateKbLayout(line.trim());
            }
        }
    }
    property var _notifCenters: []
    function toggleNotificationCenter() {
        for (var i = 0; i < _notifCenters.length; i++) {
            if (_notifCenters[i]) _notifCenters[i].isOpen = !_notifCenters[i].isOpen
        }
    }


    // ── Глобальный список лаунчеров (заполняется из Variants) ─────────────
    property var _launchers: []
    property var _captures: []
    property var _clipboards: []

    function _toggleAllLaunchers() {
        for (var i = 0; i < _launchers.length; i++) {
            if (_launchers[i])
                _launchers[i].toggle()
        }
    }

    function toggleClipboard() {
        if (_clipboards.length > 0) {
            _clipboards[0].toggle()
        }
    }

    // ── Global System Settings Window ───────────────────────────────────────
    Loader {
        id: settingsInst
        property bool settingsVisible: false
        active: true
        sourceComponent: SettingsWindow {
            settingsVisible: settingsInst.settingsVisible
            onSettingsVisibleChanged: {
                if (settingsInst.settingsVisible !== settingsVisible)
                    settingsInst.settingsVisible = settingsVisible
            }
            onOpenWallpaperBrowser: wallpaperSelector.openBrowser("")
        }
        onSettingsVisibleChanged: {
            if (item && item.settingsVisible !== settingsVisible)
                item.settingsVisible = settingsVisible
        }
    }

    ChromeLock {
        id: chromeLock
    }

    // ── GlobalShortcut: Win+I → toggle settings ───────────────────────────
    GlobalShortcut {
        name: "settingsToggle"
        onPressed: settingsInst.settingsVisible = !settingsInst.settingsVisible
    }

    function _openRegionImmediate() {
        if (_captures.length > 0 && _captures[0]) {
            _captures[0].openRegionImmediate()
        }
    }

    function _openFullscreenWait() {
        for (var i = 0; i < _captures.length; i++) {
            if (_captures[i]) _captures[i].openFullscreenWait()
        }
    }

    // ── IPC: qs ipc call launcher toggle ──────────────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle() { _toggleAllLaunchers() }
    }

    IpcHandler {
        target: "clipboard_ui"
        function toggle() { toggleClipboard() }
    }

    IpcHandler {
        target: "notifications"
        function toggle() { toggleNotificationCenter() }
    }

    // ── IPC: qs ipc call screenshot region ──────────────────────────────────
    IpcHandler {
        target: "screenshot"
        function region() { _openRegionImmediate() }
        function fullscreen() { _openFullscreenWait() }
    }

    // ── IPC: qs ipc call TEST_ALIVE (для fallback bind) ──────────────────
    IpcHandler {
        target: "TEST_ALIVE"
        function call() { return "alive" }
    }

    // ── IPC: qs ipc call WallpaperSelector toggle ────────────────────────────
    IpcHandler {
        target: "WallpaperSelector"
        function toggle() {
            wallpaperSelector.selectorVisible = !wallpaperSelector.selectorVisible;
        }
        function open() {
            wallpaperSelector.openBrowser("");
        }
    }

    // ── GlobalShortcut: Super release → toggle launcher ────────────────────
    GlobalShortcut {
        name: "searchToggleRelease"
        onPressed: _toggleAllLaunchers()
    }

    // ── GlobalShortcut: Super+V → toggle clipboard ────────────────────────
    GlobalShortcut {
        name: "clipboardToggle"
        onPressed: toggleClipboard()
    }

    // ── GlobalShortcut: Super+Shift+S → Region Capture (Immediate) ────────
    GlobalShortcut {
        name: "captureRegion"
        onPressed: _openRegionImmediate()
    }

    // ── GlobalShortcut: PrintScreen → Fullscreen Capture (Wait) ────────────
    GlobalShortcut {
        name: "captureFullscreen"
        onPressed: _openFullscreenWait()
    }

    // ── TopBar + Dock на каждом экране ────────────────────────────────────
    Variants {
        id: screenVariants
        model: Quickshell.screens

        Item {
            id: screenItem
            property var modelData

            property var clientsByWs: ({})
            property var clientIconsByWs: ({})
            property string _buf: ""

            Process {
                id: hyprctlProc
                command: ["python3", Qt.resolvedUrl("workspace-clients.py").toString().replace("file://", "")]
                running: true
                stdout: SplitParser {
                    onRead: function(line) { screenItem._buf += line }
                }
                onRunningChanged: {
                    if (!running) {
                        try {
                            var obj = JSON.parse(screenItem._buf)
                            var m = {}
                            var icons = {}
                            for (var id in obj) {
                                if (obj[id]) {
                                    m[id] = obj[id]["class"] || ""
                                    icons[id] = obj[id]["icon"] || ""
                                }
                            }
                            screenItem.clientsByWs = m
                            screenItem.clientIconsByWs = icons
                        } catch(e) { console.log("JSON Parse Error:", e, "Buffer:", screenItem._buf.substring(0, 50) + "..." + screenItem._buf.substring(screenItem._buf.length - 50)); }
                        screenItem._buf = ""
                    } else {
                        screenItem._buf = ""
                    }
                }
            }

            Timer {
                interval: 1500; repeat: true; running: true
                onTriggered: hyprctlProc.running = true
            }

            // QuickSettings popup (отдельный PanelWindow, теперь будет снизу)
            QuickSettingsPopup {
                id: qsPopupInst
                screenRef: modelData
                settingsWindow: settingsInst
            }

            // App Launcher
            AppLauncher {
                id: appLauncherInst
                screenRef: modelData
            }

            // Screen Capture
            ScreenCapture {
                id: screenCaptureInst
                screenRef: modelData
            }

            // Clipboard History
            ClipboardPopup {
                id: clipboardInst
                screenRef: modelData
            }

            // Media Popup
            MediaPopup {
                id: mediaPopupInst
                screenRef: modelData
            }

            // Notifications stream (top-right)
            NotificationsPopup {
                id: notifPopupInst
                screenRef: modelData
            }

            // Notification Center (bottom-right popup)
            NotificationCenterPopup {
                id: notifCenterInst
                screenRef: modelData
            }

            Component.onCompleted: {
                var list = _launchers.slice()
                list.push(appLauncherInst)
                _launchers = list

                var clist = _captures.slice()
                clist.push(screenCaptureInst)
                _captures = clist

                var clipList = _clipboards.slice()
                clipList.push(clipboardInst)
                _clipboards = clipList

                var ncList = _notifCenters.slice()
                ncList.push(notifCenterInst)
                _notifCenters = ncList
            }
            Component.onDestruction: {
                var list = _launchers.slice()
                var idx = list.indexOf(appLauncherInst)
                if (idx >= 0) list.splice(idx, 1)
                _launchers = list

                var clist = _captures.slice()
                var cidx = clist.indexOf(screenCaptureInst)
                if (cidx >= 0) clist.splice(cidx, 1)
                _captures = clist

                var clipList = _clipboards.slice()
                var clipIdx = clipList.indexOf(clipboardInst)
                if (clipIdx >= 0) clipList.splice(clipIdx, 1)
                _clipboards = clipList

                var ncList = _notifCenters.slice()
                var ncIdx = ncList.indexOf(notifCenterInst)
                if (ncIdx >= 0) ncList.splice(ncIdx, 1)
                _notifCenters = ncList
            }

            // ── Данные для мини-иконок ───────────────────────────────────
            readonly property int wifiBars: NetworkService.statusBars
            readonly property bool btOn: BluetoothService.btOn
            readonly property int volume: AudioService.volume
            readonly property string kbLayout: root.kbLayout
            property bool isRecording: false
            property int recordingSeconds: 0

            onIsRecordingChanged: {
                if (isRecording) {
                    recordingSeconds = 0
                    recordingTimer.start()
                } else {
                    recordingTimer.stop()
                }
            }

            Timer {
                id: recordingTimer
                interval: 1000; repeat: true
                onTriggered: screenItem.recordingSeconds++
            }

            function formatRecTime(secs) {
                var m = Math.floor(secs / 60)
                var s = secs % 60
                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
            }

            Process {
                id: recordCheckProc
                command: ["bash", "-c", "pgrep wf-recorder >/dev/null && echo 'yes' || echo 'no'"]
                running: true
                stdout: SplitParser {
                    onRead: function(line) {
                        screenItem.isRecording = (line.trim() === "yes")
                    }
                }
            }
            Timer { interval: 1000; repeat: true; running: true; onTriggered: recordCheckProc.running = true }

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }

            // ══════════════════════════════════════════════════════════════════════
            //  BACKGROUND
            // ══════════════════════════════════════════════════════════════════════
            BackgroundWindow {
                screen: modelData
            }

            // ══════════════════════════════════════════════════════════════════════
            //  CHROMEOS-STYLE BOTTOM BAR
            // ══════════════════════════════════════════════════════════════════════
                PanelWindow {
                    screen: modelData
                    anchors.bottom: true
                    width: root.dockStyle === "floating" ? Math.min(modelData.width - 24, 1240) : modelData.width
                    implicitHeight: 48

                    // Резервируем высоту панели (floating не резервирует)
                    exclusiveZone: root.dockStyle === "floating" ? 0 : 48

                WlrLayershell.layer:     WlrLayer.Top
                WlrLayershell.namespace: "quickshell-dock"
                color: "transparent"

                // ── Full-width bar background ──────────────────────────────
                Rectangle {
                    id: barBg
                    width: parent.width
                    height: parent.height
                    anchors.bottom: parent.bottom
                    radius: 0
                    topLeftRadius: root.dockStyle === "square" ? 0 : 24
                    topRightRadius: root.dockStyle === "square" ? 0 : 24
                    bottomLeftRadius: root.dockStyle === "floating" ? 24 : 0
                    bottomRightRadius: root.dockStyle === "floating" ? 24 : 0
                    clip: true
                    color: Qt.rgba(Theme.dockBg.r, Theme.dockBg.g, Theme.dockBg.b, Theme.dockBg.a * root.effectiveDockOpacity)
                    border.width: 1
                    border.color: Qt.rgba(Theme.dockBorder.r, Theme.dockBorder.g, Theme.dockBorder.b, Theme.dockBorder.a * root.effectiveDockOpacity)
                }

                // ── Far-left: G launcher button ────────────────────────────
                Rectangle {
                    id: launcherBtn
                    anchors {
                        left: parent.left; leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    width: 38; height: 38; radius: 19
                    color: (appLauncherInst && appLauncherInst.isOpen) || launcherBtnArea.containsMouse
                        ? Theme.dockPillHover
                        : Theme.dockPill
                    border.color: Theme.dockBorder; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "G"
                        font { pixelSize: 18; family: "Google Sans"; weight: Font.Bold }
                        color: Theme.dockText
                    }

                        MouseArea {
                            id: launcherBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appLauncherInst.toggle()
                        }
                    }

                    // ── Recording indicator next to launcher ──────────────────
                    Rectangle {
                        id: recIndicator
                        visible: screenItem.isRecording
                        anchors {
                            left: launcherBtn.right; leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        width: recRow.implicitWidth + 16
                        height: 32; radius: 16
                        color: Qt.rgba(0.85, 0.12, 0.12, 0.25)
                        border.color: Qt.rgba(0.85, 0.12, 0.12, 0.6)
                        border.width: 1

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: recIndicator.visible
                            NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                        }

                        Row {
                            id: recRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: Qt.rgba(1, 0.15, 0.15, 1)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: screenItem.formatRecTime(screenItem.recordingSeconds)
                                color: Qt.rgba(1, 0.9, 0.9, 0.95)
                                font { pixelSize: 12; family: "Google Sans"; weight: Font.Medium }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Process {
                            id: killRecorderProc
                            command: ["killall", "-SIGINT", "wf-recorder"]
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                killRecorderProc.running = true
                                screenItem.isRecording = false
                            }
                        }
                    }

                    // ── Center: Workspace buttons directly on the bar ──────────
                    Row {
                        id: dockRow
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: 10
                            WorkspaceAppButton {
                                wsId: index + 1
                                clientsByWs: screenItem.clientsByWs
                                clientIconsByWs: screenItem.clientIconsByWs
                                dockIconFillEnabled: root.dockIconFillEnabled
                                dockIconFillColor: Theme.secondary
                            }
                        }

                        Loader {
                            // Disabled by default
                            active: false // SystemTray.items.values && SystemTray.items.values.length > 0
                            sourceComponent: Row {
                                spacing: 0
                                DockSeparator {}
                                Repeater {
                                    model: SystemTray.items
                                    TrayIcon { trayItem: modelData }
                                }
                            }
                        }
                    }

                    // ── Right side: ChromeOS-style status area ─────────────────
                    Row {
                        id: rightArea
                        anchors {
                            right: parent.right; rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2

                        // (Recording indicator moved next to launcher button)

                    // ── 0. Media Pill ────────────────────────────
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        anchors.verticalCenter: parent.verticalCenter
                        color: mediaPopupInst.isOpen ? Theme.dockActive : (mediaArea.containsMouse ? Theme.dockPillHover : Theme.dockPill)
                        border.color: Theme.dockBorder; border.width: 1

                        Image {
                            id: mediaImg
                            anchors.centerIn: parent
                            width: 18; height: 18
                            source: "assets/icons/music-note.svg"
                            sourceSize: Qt.size(18, 18)
                            smooth: true
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: mediaImg
                            source: mediaImg
                            color: mediaPopupInst.isOpen ? Theme.dockActiveText : Theme.dockText
                        }

                        MouseArea {
                            id: mediaArea
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                mediaPopupInst.isOpen = !mediaPopupInst.isOpen
                            }
                        }
                    }

                    Rectangle {
                        id: combinedPill
                        width: combinedRow.implicitWidth
                        height: 38; radius: 19
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.dockPill
                        border.color: Theme.dockBorder; border.width: 1
                        clip: true

                        Row {
                            id: combinedRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Item {
                                id: notifSection
                                visible: NotificationService.history.length > 0
                                width: 42; height: 38

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: height / 2
                                    color: notifCenterInst.isOpen
                                        ? Theme.dockActive
                                        : (notifBadgeArea.containsMouse ? Theme.dockPillHover : "transparent")
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: NotificationService.unread > 0
                                        ? NotificationService.unread
                                        : NotificationService.history.length
                                    color: notifCenterInst.isOpen
                                        ? Theme.dockActiveText
                                        : Theme.dockTextStrong
                                    font { pixelSize: 13; family: "Google Sans"; weight: Font.Bold }
                                }

                                MouseArea {
                                    id: notifBadgeArea
                                    anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: notifCenterInst.isOpen = !notifCenterInst.isOpen
                                }
                            }

                            Item {
                                visible: NotificationService.history.length > 0
                                width: 2; height: 38
                                Rectangle {
                                    width: 2; height: 20
                                    anchors.centerIn: parent
                                    color: Theme.dockDivider
                                }
                            }

                            Item {
                                id: dateSection
                                width: dateTxt.implicitWidth + 24; height: 38

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: height / 2
                                    color: "transparent"
                                }

                                Text {
                                    id: dateTxt
                                    anchors.centerIn: parent
                                    text: Qt.formatDateTime(clock.date, "MMM d")
                                    color: Theme.dockText
                                    font { pixelSize: 13; family: "Google Sans"; weight: Font.Bold }
                                }
                            }

                            Item {
                                width: 2; height: 38
                                Rectangle {
                                    width: 2; height: 20
                                    anchors.centerIn: parent
                                    color: Theme.dockDivider
                                }
                            }

                            Item {
                                id: statusSection
                                width: wifiTimeRow.implicitWidth + 28; height: 38

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: height / 2
                                    color: qsPopupInst.popupVisible
                                        ? Theme.dockActive
                                        : (statusArea.containsMouse ? Theme.dockPillHover : "transparent")
                                }

                                Row {
                                    id: wifiTimeRow
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Item {
                                        width: 22; height: 22
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            id: dockWifiImg
                                            anchors.fill: parent
                                            source: {
                                                if (screenItem.wifiBars === 100) return "assets/icons/ethernet.svg"
                                                if (screenItem.wifiBars <= 0) return "assets/icons/wifi-off.svg"
                                                if (screenItem.wifiBars === 1) return "assets/icons/network-wifi-1-bar.svg"
                                                if (screenItem.wifiBars === 2) return "assets/icons/network-wifi-2-bar.svg"
                                                if (screenItem.wifiBars === 3) return "assets/icons/network-wifi-3-bar.svg"
                                                return "assets/icons/signal-wifi-4-bar.svg"
                                            }
                                            sourceSize: Qt.size(22, 22)
                                            smooth: true
                                            visible: false
                                        }
                                        ColorOverlay {
                                            anchors.fill: dockWifiImg
                                            source: dockWifiImg
                                            color: qsPopupInst.popupVisible
                                                ? Theme.dockActiveText
                                                : Theme.dockText
                                        }
                                    }

                                    Text {
                                        id: timeTxt
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Qt.formatDateTime(clock.date, ConfigService.ready && ConfigService.values.use24Hour ? "HH:mm" : "h:mm AP")
                                        color: qsPopupInst.popupVisible
                                            ? Theme.dockActiveText
                                            : Theme.dockTextStrong
                                        font { pixelSize: 13; family: "Google Sans"; weight: Font.Bold }
                                    }
                                }

                                MouseArea {
                                    id: statusArea
                                    anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (qsPopupInst)
                                            qsPopupInst.popupVisible = !qsPopupInst.popupVisible
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    WallpaperSelectorWindow {
        id: wallpaperSelector
    }

    OnScreenDisplay {
        id: osdOverlay
    }
}
