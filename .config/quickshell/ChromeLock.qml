import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import "Theme"
import "services"

Scope {
    id: root

    property bool locked: false
    property bool passwordView: false
    property bool unlockInProgress: false
    property bool authFailed: false
    property bool powerMenuOpen: false
    property int focusSerial: 0
    property string password: ""
    property string username: Quickshell.env("USER") || "user"
    property string batteryText: ""

    function wallpaperUrl() {
        if (!ConfigService.ready || !ConfigService.values.wallpaperPath)
            return "";

        var path = ConfigService.values.wallpaperPath;
        var lower = path.toLowerCase();
        if (lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov"))
            return "";

        return "file://" + path;
    }

    function activate() {
        if (locked)
            return;

        password = "";
        authFailed = false;
        unlockInProgress = false;
        passwordView = false;
        powerMenuOpen = false;
        locked = true;
        batteryProc.running = true;
        focusLater.restart();
    }

    function focusLock() {
        focusSerial++;
        passwordView = true;
    }

    function tryUnlock() {
        if (unlockInProgress || password.length === 0)
            return;

        authFailed = false;
        unlockInProgress = true;
        pam.start();
    }

    function failUnlock() {
        password = "";
        authFailed = true;
        unlockInProgress = false;
        passwordView = true;
        focusLock();
    }

    function unlock() {
        password = "";
        authFailed = false;
        unlockInProgress = false;
        passwordView = false;
        powerMenuOpen = false;
        locked = false;
    }

    Timer {
        id: focusLater
        interval: 80
        repeat: false
        onTriggered: root.focusLock()
    }

    Timer {
        id: clearTimer
        interval: 12000
        repeat: false
        onTriggered: {
            if (root.locked && !root.unlockInProgress)
                root.password = "";
        }
    }

    Process {
        id: batteryProc
        running: false
        command: ["bash", "-c", "for b in /sys/class/power_supply/BAT*; do [ -r \"$b/capacity\" ] || continue; c=$(cat \"$b/capacity\"); s=$(cat \"$b/status\" 2>/dev/null); [ \"$s\" = Charging ] && echo \"$c% charging\" || echo \"$c%\"; exit; done"]
        stdout: SplitParser {
            onRead: function(line) {
                root.batteryText = line.trim();
            }
        }
    }

    Process {
        id: actionProc
        running: false
    }

    PamContext {
        id: pam
        config: "hyprlock"
        user: root.username

        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }

        onCompleted: function(result) {
            if (result === PamResult.Success)
                root.unlock();
            else
                root.failUnlock();
        }

        onError: function(_) {
            root.failUnlock();
        }
    }

    Component {
        id: lockSurfaceComponent

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"

            Item {
                id: content
                anchors.fill: parent
                focus: true

                Component.onCompleted: forceActiveFocus()

                Connections {
                    target: root
                    function onFocusSerialChanged() {
                        content.forceActiveFocus();
                        passwordInput.forceActiveFocus();
                    }
                    function onPasswordViewChanged() {
                        if (root.passwordView)
                            passwordInput.forceActiveFocus();
                        else
                            content.forceActiveFocus();
                    }
                    function onLockedChanged() {
                        if (root.locked)
                            content.forceActiveFocus();
                    }
                }

                Keys.onPressed: function(event) {
                    if (!root.passwordView) {
                        root.passwordView = true;
                        event.accepted = true;
                    }
                }

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: root.wallpaperUrl()
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.24) : Qt.rgba(0, 0, 0, 0.40)
                }

                GaussianBlur {
                    anchors.fill: wallpaper
                    source: wallpaper
                    radius: 64
                    samples: 129
                    opacity: root.passwordView && wallpaper.visible ? 0.92 : 0
                    scale: root.passwordView ? 1.04 : 1
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.passwordView ? Qt.rgba(0, 0, 0, 0.34) : Qt.rgba(0, 0, 0, 0.10)
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                Item {
                    id: clockView
                    anchors.fill: parent
                    opacity: root.passwordView ? 0 : 1
                    visible: opacity > 0
                    y: root.passwordView ? -48 : 0

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.passwordView
                        onClicked: root.passwordView = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Column {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                            topMargin: Math.max(68, parent.height * 0.10)
                        }
                        spacing: 4

                        SystemClock {
                            id: lockClock
                            precision: SystemClock.Seconds
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(lockClock.date, ConfigService.ready && ConfigService.values.use24Hour ? "HH:mm" : "h:mm")
                            color: "white"
                            font.pixelSize: Math.max(72, Math.min(136, lockSurface.height * 0.16))
                            font.family: "Google Sans"
                            font.weight: Font.Bold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(lockClock.date, "dddd, MMMM d")
                            color: Qt.rgba(1, 1, 1, 0.92)
                            font.pixelSize: 25
                            font.family: "Google Sans"
                            font.weight: Font.Medium
                        }
                    }
                }

                Item {
                    id: passwordView
                    anchors.fill: parent
                    opacity: root.passwordView ? 1 : 0
                    visible: opacity > 0
                    y: root.passwordView ? 0 : 32

                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 112
                            height: 112
                            radius: 56
                            color: Qt.rgba(1, 1, 1, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.26)

                            Text {
                                anchors.centerIn: parent
                                text: root.username.length > 0 ? root.username[0].toUpperCase() : "U"
                                color: "white"
                                font.pixelSize: 48
                                font.family: "Google Sans"
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.username
                            color: "white"
                            font.pixelSize: 24
                            font.family: "Google Sans"
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            id: passwordBox
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 320
                            height: 48
                            radius: 24
                            color: Qt.rgba(1, 1, 1, passwordInput.activeFocus ? 0.24 : 0.16)
                            border.width: 1
                            border.color: root.authFailed ? Theme.error : Qt.rgba(1, 1, 1, passwordInput.activeFocus ? 0.55 : 0.22)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 6
                                spacing: 8

                                TextInput {
                                    id: passwordInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "white"
                                    selectionColor: Qt.rgba(1, 1, 1, 0.30)
                                    selectedTextColor: "white"
                                    font.pixelSize: 16
                                    font.family: "Google Sans"
                                    echoMode: visibilityButton.pressed ? TextInput.Normal : TextInput.Password
                                    inputMethodHints: Qt.ImhSensitiveData
                                    text: root.password
                                    enabled: !root.unlockInProgress

                                    onTextChanged: {
                                        if (root.password !== text)
                                            root.password = text;
                                        root.authFailed = false;
                                        clearTimer.restart();
                                    }

                                    onAccepted: root.tryUnlock()

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: passwordInput.text.length === 0
                                        text: root.authFailed ? "Wrong password" : "Password"
                                        color: root.authFailed ? Theme.error : Qt.rgba(1, 1, 1, 0.72)
                                        font.pixelSize: 16
                                        font.family: "Google Sans"
                                    }
                                }

                                LockIconButton {
                                    id: visibilityButton
                                    iconSource: pressed ? "assets/icons/visibility-off.svg" : "assets/icons/visibility.svg"
                                    visible: root.password.length > 0
                                }

                                LockIconButton {
                                    iconSource: "assets/icons/chevron-right.svg"
                                    enabled: root.password.length > 0 && !root.unlockInProgress
                                    opacity: enabled ? 1 : 0.45
                                    onClicked: root.tryUnlock()
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: 28
                        bottomMargin: 24
                    }
                    spacing: 12

                    LockStatusPill {
                        iconSource: NetworkService.ethConnected ? "assets/icons/ethernet.svg" : NetworkService.wifiIcon()
                        text: NetworkService.ethConnected ? "Ethernet" : (NetworkService.wifiConnected ? NetworkService.wifiName : "Offline")
                    }

                    LockStatusPill {
                        visible: root.batteryText.length > 0
                        iconSource: "assets/icons/battery-full.svg"
                        text: root.batteryText
                    }

                    Rectangle {
                        id: powerButton
                        width: 40
                        height: 40
                        radius: 20
                        color: root.powerMenuOpen || powerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.20)

                        Image {
                            id: powerIcon
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: "assets/icons/power-settings-new.svg"
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: powerIcon
                            source: powerIcon
                            color: "white"
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerMenuOpen = !root.powerMenuOpen
                        }
                    }
                }

                Rectangle {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: 28
                        bottomMargin: 76
                    }
                    width: 210
                    height: powerColumn.implicitHeight + 18
                    radius: 20
                    visible: root.powerMenuOpen
                    color: Qt.rgba(0.10, 0.10, 0.12, 0.82)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)

                    Column {
                        id: powerColumn
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 4

                        PowerMenuItem {
                            label: "Shut down"
                            iconSource: "assets/icons/power-settings-new.svg"
                            command: "systemctl poweroff"
                        }
                        PowerMenuItem {
                            label: "Restart"
                            iconSource: "assets/icons/restart-alt.svg"
                            command: "systemctl reboot"
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    z: -1
                    onClicked: root.passwordView = true
                }
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked
        surface: lockSurfaceComponent
    }

    IpcHandler {
        target: "lock"
        function activate() { root.activate(); }
        function focus() { root.focusLock(); }
    }

    GlobalShortcut {
        name: "lock"
        description: "Lock the screen"
        onPressed: root.activate()
    }

    GlobalShortcut {
        name: "lockFocus"
        description: "Focus the Quickshell lock screen"
        onPressed: root.focusLock()
    }

    component LockIconButton: Rectangle {
        id: button
        property string iconSource: ""
        property alias pressed: mouse.pressed
        signal clicked()

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 17
        color: mouse.containsMouse || mouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

        Image {
            id: icon
            anchors.centerIn: parent
            width: 19
            height: 19
            source: button.iconSource
            sourceSize: Qt.size(19, 19)
            visible: false
        }

        ColorOverlay {
            anchors.fill: icon
            source: icon
            color: "white"
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component LockStatusPill: Rectangle {
        property string iconSource: ""
        property string text: ""

        width: statusRow.implicitWidth + 20
        height: 40
        radius: 20
        color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 8

            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: statusIcon
                    anchors.fill: parent
                    source: iconSource
                    sourceSize: Qt.size(18, 18)
                    smooth: true
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: statusIcon
                    source: statusIcon
                    color: "white"
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.text
                color: "white"
                font.pixelSize: 13
                font.family: "Google Sans"
                font.weight: Font.Medium
            }
        }
    }

    component PowerMenuItem: Rectangle {
        id: item
        property string iconSource: ""
        property string label: ""
        property string command: ""

        width: parent ? parent.width : 192
        height: 44
        radius: 14
        color: itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            spacing: 12

            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: itemIcon
                    anchors.fill: parent
                    source: item.iconSource
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: itemIcon
                    source: itemIcon
                    color: "white"
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: item.label
                color: "white"
                font.pixelSize: 14
                font.family: "Google Sans"
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                actionProc.command = ["bash", "-c", item.command];
                actionProc.running = true;
            }
        }
    }
}
