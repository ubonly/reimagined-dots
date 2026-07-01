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
    property bool unlockAnimating: false
    property bool authFailed: false
    property bool powerMenuOpen: false
    property bool networkMenuOpen: false
    property bool wifiPassVisible: false
    property bool wifiPassShow: false
    property int focusSerial: 0
    property string password: ""
    property string wifiPassSsid: ""
    property string wifiPassError: ""
    property string username: Quickshell.env("USER") || "user"
    readonly property string lockDisplayName: GoogleSyncService.lockScreenName(username)
    readonly property string lockAvatarSource: GoogleSyncService.lockScreenAvatar()
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
        unlockAnimating = false;
        unlockTransition.reset();
        passwordView = false;
        powerMenuOpen = false;
        networkMenuOpen = false;
        wifiPassVisible = false;
        wifiPassShow = false;
        wifiPassSsid = "";
        wifiPassError = "";
        locked = true;
        batteryProc.running = true;
        NetworkService.update();
        NetworkService.scan();
        focusLater.restart();
    }

    function focusLock() {
        focusSerial++;
        passwordView = true;
    }

    function tryUnlock() {
        if (unlockInProgress || unlockAnimating || password.length === 0)
            return;

        authFailed = false;
        unlockInProgress = true;
        pam.start();
    }

    function failUnlock() {
        password = "";
        authFailed = true;
        unlockInProgress = false;
        unlockAnimating = false;
        unlockTransition.reset();
        passwordView = true;
        focusLock();
    }

    function startUnlockAnimation() {
        authFailed = false;
        unlockInProgress = false;
        unlockAnimating = true;
        powerMenuOpen = false;
        networkMenuOpen = false;
        wifiPassVisible = false;
        unlockTransition.start();
    }

    function finishUnlock() {
        password = "";
        authFailed = false;
        unlockInProgress = false;
        unlockAnimating = false;
        passwordView = false;
        powerMenuOpen = false;
        networkMenuOpen = false;
        wifiPassVisible = false;
        wifiPassShow = false;
        wifiPassSsid = "";
        wifiPassError = "";
        locked = false;
    }

    function toggleNetworkMenu() {
        if (unlockAnimating)
            return;
        networkMenuOpen = !networkMenuOpen;
        powerMenuOpen = false;
        wifiPassVisible = false;
        wifiPassError = "";
        if (networkMenuOpen) {
            NetworkService.update();
            NetworkService.scan();
        }
    }

    function openWifiPassword(ssid) {
        wifiPassSsid = ssid;
        wifiPassError = "";
        wifiPassShow = false;
        wifiPassVisible = true;
    }

    function closeWifiPassword() {
        wifiPassVisible = false;
        wifiPassShow = false;
        wifiPassSsid = "";
        wifiPassError = "";
        focusLock();
    }

    function connectWifiWithPassword(passwordText) {
        if (passwordText.length < 8) {
            wifiPassError = "Password must be at least 8 characters";
            return;
        }
        wifiPassError = "";
        NetworkService.connectWithPassword(wifiPassSsid, passwordText);
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

    Connections {
        target: NetworkService
        function onPasswordFinished(ok, message) {
            if (!root.locked || !root.wifiPassVisible)
                return;
            if (ok) {
                root.closeWifiPassword();
                root.networkMenuOpen = false;
            } else {
                root.wifiPassError = message || "Connection failed";
            }
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
                root.startUnlockAnimation();
            else
                root.failUnlock();
        }

        onError: function(_) {
            root.failUnlock();
        }
    }

    UnlockTransition {
        id: unlockTransition
        wallpaperSource: root.wallpaperUrl()
        onReleaseLockRequested: root.finishUnlock()
    }

    Component {
        id: lockSurfaceComponent

        WlSessionLockSurface {
            id: lockSurface
            color: Theme.bgColor

            Item {
                id: content
                anchors.fill: parent
                focus: true
                enabled: !root.unlockAnimating

                Component.onCompleted: forceActiveFocus()

                Connections {
                    target: root
                    function onFocusSerialChanged() {
                        content.forceActiveFocus();
                        if (root.wifiPassVisible)
                            wifiPasswordInput.forceActiveFocus();
                        else
                            passwordInput.forceActiveFocus();
                    }
                    function onPasswordViewChanged() {
                        if (root.wifiPassVisible)
                            wifiPasswordInput.forceActiveFocus();
                        else if (root.passwordView)
                            passwordInput.forceActiveFocus();
                        else
                            content.forceActiveFocus();
                    }
                    function onWifiPassVisibleChanged() {
                        if (root.wifiPassVisible)
                            wifiPasswordFocusTimer.restart();
                        else if (root.passwordView)
                            passwordInput.forceActiveFocus();
                    }
                    function onLockedChanged() {
                        if (root.locked)
                            content.forceActiveFocus();
                    }
                }

                Keys.onPressed: function(event) {
                    if (!root.passwordView && !root.wifiPassVisible && !root.unlockAnimating) {
                        root.passwordView = true;
                        event.accepted = true;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bgColor
                }

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: root.wallpaperUrl()
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: false
                    scale: root.passwordView || root.unlockAnimating ? unlockTransition.lockWallpaperScale : 1
                    transformOrigin: Item.Center
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
                    opacity: root.passwordView && wallpaper.visible ? 0.92 * unlockTransition.lockBlurOpacity : 0
                    scale: root.passwordView ? 1.04 * unlockTransition.lockWallpaperScale : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        enabled: !root.unlockAnimating
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        enabled: !root.unlockAnimating
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.passwordView
                        ? Qt.rgba(0, 0, 0, 0.34 * unlockTransition.lockDimOpacity)
                        : Qt.rgba(0, 0, 0, 0.10)
                    Behavior on color {
                        enabled: !root.unlockAnimating
                        ColorAnimation { duration: 180 }
                    }
                }

                Item {
                    id: clockView
                    anchors.fill: parent
                    opacity: root.unlockAnimating ? unlockTransition.lockWidgetsOpacity : 1
                    visible: opacity > 0
                    y: root.unlockAnimating ? unlockTransition.lockWidgetsY : 0
                    scale: root.unlockAnimating ? unlockTransition.lockClockScale : 1
                    transformOrigin: Item.Center

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.passwordView
                        onClicked: root.passwordView = true
                    }

                    Behavior on opacity {
                        enabled: !root.unlockAnimating
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: !root.unlockAnimating
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }

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
                    opacity: root.unlockAnimating ? unlockTransition.lockWidgetsOpacity : (root.passwordView ? 1 : 0)
                    visible: opacity > 0
                    y: root.unlockAnimating ? unlockTransition.lockWidgetsY : (root.passwordView ? 0 : 32)
                    scale: root.unlockAnimating ? unlockTransition.lockWidgetScale : 1
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        enabled: !root.unlockAnimating
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: !root.unlockAnimating
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }

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
                            clip: true

                            Image {
                                id: googleAvatar
                                anchors.fill: parent
                                source: root.lockAvatarSource
                                sourceSize: Qt.size(112, 112)
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                visible: root.lockAvatarSource !== "" && status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.lockDisplayName.length > 0 ? root.lockDisplayName[0].toUpperCase() : "U"
                                color: "white"
                                font.pixelSize: 48
                                font.family: "Google Sans"
                                font.weight: Font.Bold
                                visible: !googleAvatar.visible
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.lockDisplayName
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
                                    enabled: !root.unlockInProgress && !root.unlockAnimating && !root.wifiPassVisible

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
                                    enabled: root.password.length > 0 && !root.unlockInProgress && !root.unlockAnimating
                                    opacity: enabled ? 1 : 0.45
                                    onClicked: root.tryUnlock()
                                }
                            }
                        }
                    }
                }

                Timer {
                    id: wifiPasswordFocusTimer
                    interval: 60
                    repeat: false
                    onTriggered: {
                        if (root.wifiPassVisible)
                            wifiPasswordInput.forceActiveFocus();
                    }
                }

                Row {
                    id: lockStatusRow
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: 28
                        bottomMargin: 24
                    }
                    spacing: 12
                    opacity: root.unlockAnimating ? unlockTransition.lockWidgetsOpacity : 1

                    transform: Translate {
                        y: root.unlockAnimating ? Math.max(0, -unlockTransition.lockWidgetsY * 0.45) : 0
                    }

                    Behavior on opacity {
                        enabled: !root.unlockAnimating
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    LockStatusPill {
                        interactive: true
                        iconSource: NetworkService.ethConnected ? "assets/icons/ethernet.svg" : NetworkService.wifiIcon()
                        text: NetworkService.ethConnected ? "Ethernet" : (NetworkService.wifiConnected ? NetworkService.wifiName : "Offline")
                        onClicked: root.toggleNetworkMenu()
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
                            onClicked: {
                                root.powerMenuOpen = !root.powerMenuOpen;
                                root.networkMenuOpen = false;
                                root.wifiPassVisible = false;
                            }
                        }
                    }
                }

                Rectangle {
                    id: networkMenu
                    z: 30
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: 28
                        bottomMargin: 76
                    }
                    width: 360
                    height: Math.min(440, networkMenuColumn.implicitHeight + 24)
                    radius: 22
                    visible: root.networkMenuOpen && !root.wifiPassVisible && !root.unlockAnimating
                    opacity: visible ? 1 : 0
                    color: Qt.rgba(0.10, 0.10, 0.12, 0.86)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    clip: true

                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: networkMenuColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 17
                                    color: Qt.rgba(1, 1, 1, 0.14)
                                }

                                Image {
                                    id: networkMenuIcon
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: NetworkService.ethConnected ? "assets/icons/ethernet.svg" : NetworkService.wifiIcon()
                                    sourceSize: Qt.size(18, 18)
                                    visible: false
                                }

                                ColorOverlay {
                                    anchors.fill: networkMenuIcon
                                    source: networkMenuIcon
                                    color: "white"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: NetworkService.ethConnected ? "Ethernet" : "Wi-Fi"
                                    color: "white"
                                    font.pixelSize: 14
                                    font.family: "Google Sans"
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: NetworkService.connecting ? "Connecting..."
                                        : (NetworkService.ethConnected ? NetworkService.ethName
                                            : (NetworkService.wifiRadioOn
                                                ? (NetworkService.wifiConnected ? NetworkService.wifiName : "Not connected")
                                                : "Off"))
                                    color: Qt.rgba(1, 1, 1, 0.70)
                                    font.pixelSize: 12
                                    font.family: "Google Sans"
                                    elide: Text.ElideRight
                                }
                            }

                            LockTextButton {
                                label: NetworkService.wifiRadioOn ? "Off" : "On"
                                visible: !NetworkService.ethConnected
                                onClicked: {
                                    NetworkService.toggleWifi();
                                    if (!NetworkService.wifiRadioOn)
                                        NetworkService.scan();
                                }
                            }

                            LockTextButton {
                                label: "Scan"
                                visible: NetworkService.wifiRadioOn && !NetworkService.ethConnected
                                enabled: !NetworkService.scanning
                                opacity: enabled ? 1 : 0.55
                                onClicked: NetworkService.scan()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(316, networkList.implicitHeight)
                            contentHeight: networkList.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height

                            ColumnLayout {
                                id: networkList
                                width: parent.width
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: NetworkService.ethConnected ? "Wi-Fi controls are available when Ethernet is not the active connection." : "Wi-Fi is off"
                                    color: Qt.rgba(1, 1, 1, 0.68)
                                    font.pixelSize: 12
                                    font.family: "Google Sans"
                                    wrapMode: Text.WordWrap
                                    visible: NetworkService.ethConnected || !NetworkService.wifiRadioOn
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 4
                                    text: "Known networks"
                                    color: Qt.rgba(1, 1, 1, 0.58)
                                    font.pixelSize: 11
                                    font.family: "Google Sans"
                                    font.weight: Font.Bold
                                    visible: !NetworkService.ethConnected && NetworkService.wifiRadioOn && NetworkService.knownNetworks.length > 0
                                }

                                Repeater {
                                    model: (!NetworkService.ethConnected && NetworkService.wifiRadioOn) ? NetworkService.knownNetworks : []

                                    LockNetworkItem {
                                        ssid: modelData.ssid
                                        sigVal: modelData.signal
                                        security: modelData.security
                                        inUse: NetworkService.wifiConnected && modelData.ssid === NetworkService.wifiName
                                        onClicked: NetworkService.connectKnown(modelData.ssid)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 4
                                    text: "Other networks"
                                    color: Qt.rgba(1, 1, 1, 0.58)
                                    font.pixelSize: 11
                                    font.family: "Google Sans"
                                    font.weight: Font.Bold
                                    visible: !NetworkService.ethConnected && NetworkService.wifiRadioOn && NetworkService.unknownNetworks.length > 0
                                }

                                Repeater {
                                    model: (!NetworkService.ethConnected && NetworkService.wifiRadioOn) ? NetworkService.unknownNetworks : []

                                    LockNetworkItem {
                                        ssid: modelData.ssid
                                        sigVal: modelData.signal
                                        security: modelData.security
                                        inUse: false
                                        onClicked: root.openWifiPassword(modelData.ssid)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    text: NetworkService.scanning ? "Scanning for networks..." : "No Wi-Fi networks found"
                                    color: Qt.rgba(1, 1, 1, 0.62)
                                    font.pixelSize: 12
                                    font.family: "Google Sans"
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: !NetworkService.ethConnected
                                        && NetworkService.wifiRadioOn
                                        && NetworkService.knownNetworks.length === 0
                                        && NetworkService.unknownNetworks.length === 0
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: wifiPasswordCard
                    z: 40
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: 28
                        bottomMargin: 76
                    }
                    width: 360
                    height: wifiPasswordColumn.implicitHeight + 28
                    radius: 22
                    visible: root.wifiPassVisible && !root.unlockAnimating
                    opacity: visible ? 1 : 0
                    color: Qt.rgba(0.10, 0.10, 0.12, 0.90)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.18)

                    onVisibleChanged: {
                        if (visible) {
                            wifiPasswordInput.text = "";
                            wifiPasswordFocusTimer.restart();
                        }
                    }

                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: wifiPasswordInput.forceActiveFocus()
                    }

                    ColumnLayout {
                        id: wifiPasswordColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 17
                                    color: Qt.rgba(1, 1, 1, 0.14)
                                }

                                Image {
                                    id: wifiPasswordLockIcon
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: "assets/icons/lock.svg"
                                    sourceSize: Qt.size(18, 18)
                                    visible: false
                                }

                                ColorOverlay {
                                    anchors.fill: wifiPasswordLockIcon
                                    source: wifiPasswordLockIcon
                                    color: "white"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: root.wifiPassSsid
                                    color: "white"
                                    font.pixelSize: 14
                                    font.family: "Google Sans"
                                    font.weight: Font.Bold
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Enter network password"
                                    color: Qt.rgba(1, 1, 1, 0.70)
                                    font.pixelSize: 12
                                    font.family: "Google Sans"
                                }
                            }

                            LockTextButton {
                                label: "Close"
                                onClicked: root.closeWifiPassword()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 14
                            color: Qt.rgba(1, 1, 1, wifiPasswordInput.activeFocus ? 0.18 : 0.10)
                            border.width: 1
                            border.color: root.wifiPassError.length > 0 ? Theme.error : Qt.rgba(1, 1, 1, wifiPasswordInput.activeFocus ? 0.42 : 0.18)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 6
                                spacing: 8

                                TextInput {
                                    id: wifiPasswordInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "white"
                                    selectionColor: Qt.rgba(1, 1, 1, 0.30)
                                    selectedTextColor: "white"
                                    font.pixelSize: 14
                                    font.family: "Google Sans"
                                    echoMode: root.wifiPassShow ? TextInput.Normal : TextInput.Password
                                    passwordCharacter: "•"
                                    inputMethodHints: Qt.ImhSensitiveData
                                    enabled: !NetworkService.connecting

                                    Keys.onEscapePressed: root.closeWifiPassword()
                                    Keys.onReturnPressed: root.connectWifiWithPassword(text)
                                }

                                LockIconButton {
                                    iconSource: root.wifiPassShow ? "assets/icons/visibility-off.svg" : "assets/icons/visibility.svg"
                                    onClicked: root.wifiPassShow = !root.wifiPassShow
                                }

                                LockIconButton {
                                    iconSource: "assets/icons/chevron-right.svg"
                                    enabled: wifiPasswordInput.text.length > 0 && !NetworkService.connecting
                                    opacity: enabled ? 1 : 0.45
                                    onClicked: root.connectWifiWithPassword(wifiPasswordInput.text)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.wifiPassError
                            color: Theme.error
                            font.pixelSize: 12
                            font.family: "Google Sans"
                            wrapMode: Text.WordWrap
                            visible: root.wifiPassError.length > 0
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Connecting..."
                            color: Qt.rgba(1, 1, 1, 0.72)
                            font.pixelSize: 12
                            font.family: "Google Sans"
                            visible: NetworkService.connecting
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
                    visible: root.powerMenuOpen && !root.unlockAnimating
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
        id: statusPill
        property string iconSource: ""
        property string text: ""
        property bool interactive: false
        signal clicked()

        width: statusRow.implicitWidth + 20
        height: 40
        radius: 20
        color: statusMouse.containsMouse || (statusPill.interactive && root.networkMenuOpen) ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.14)
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

        MouseArea {
            id: statusMouse
            anchors.fill: parent
            enabled: statusPill.interactive
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: statusPill.clicked()
        }
    }

    component LockTextButton: Rectangle {
        id: textButton
        property string label: ""
        signal clicked()

        Layout.preferredHeight: 30
        Layout.preferredWidth: Math.max(58, buttonLabel.implicitWidth + 24)
        radius: 15
        color: textButtonMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: textButton.label
            color: "white"
            font.pixelSize: 12
            font.family: "Google Sans"
            font.weight: Font.Medium
        }

        MouseArea {
            id: textButtonMouse
            anchors.fill: parent
            enabled: textButton.enabled
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: textButton.clicked()
        }
    }

    component LockNetworkItem: Rectangle {
        id: item
        property string ssid: ""
        property int sigVal: 0
        property string security: ""
        property bool inUse: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: 14
        color: itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Item {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18

                Image {
                    id: networkItemIcon
                    anchors.fill: parent
                    source: {
                        if (item.sigVal >= 75) return "assets/icons/signal-wifi-4-bar.svg";
                        if (item.sigVal >= 50) return "assets/icons/network-wifi-3-bar.svg";
                        if (item.sigVal >= 25) return "assets/icons/network-wifi-2-bar.svg";
                        return "assets/icons/network-wifi-1-bar.svg";
                    }
                    sourceSize: Qt.size(18, 18)
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: networkItemIcon
                    source: networkItemIcon
                    color: "white"
                }
            }

            Text {
                Layout.fillWidth: true
                text: item.ssid
                color: "white"
                font.pixelSize: 13
                font.family: "Google Sans"
                font.weight: item.inUse ? Font.Bold : Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                visible: item.inUse
                Layout.preferredWidth: connectedLabel.implicitWidth + 14
                Layout.preferredHeight: 20
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.16)

                Text {
                    id: connectedLabel
                    anchors.centerIn: parent
                    text: "Connected"
                    color: "white"
                    font.pixelSize: 10
                    font.family: "Google Sans"
                    font.weight: Font.Medium
                }
            }

            Item {
                visible: item.security !== "" && item.security !== "--"
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14

                Image {
                    id: networkItemLock
                    anchors.fill: parent
                    source: "assets/icons/lock.svg"
                    sourceSize: Qt.size(14, 14)
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: networkItemLock
                    source: networkItemLock
                    color: Qt.rgba(1, 1, 1, 0.76)
                }
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.clicked()
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
