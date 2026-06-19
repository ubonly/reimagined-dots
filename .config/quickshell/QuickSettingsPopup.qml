// QuickSettingsPopup.qml — chromeOS Material you control center
// Wi-Fi + Bluetooth tiles, brightness/volume sliders, Wi-Fi network dropdown.
// Catppuccin Mocha palette, inline reusable components.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "Theme"

PanelWindow {
    id: root
    property var  screenRef
    property var  settingsWindow: null
    property bool popupVisible: false
    
    property bool _animVisible: false
    visible: _animVisible

    onPopupVisibleChanged: {
        if (!popupVisible) { 
            btPanelOpen = false; wifiMenuOpen = false; powerMenuOpen = false 
            closeTimer.start()
        } else {
            _animVisible = true
            focusGrabber.forceActiveFocus()
        }
    }

    Timer {
        id: closeTimer
        interval: 260
        repeat: false
        onTriggered: root._animVisible = false
    }

    screen: screenRef
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    WlrLayershell.layer:     WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-quicksettings"
    WlrLayershell.keyboardFocus: popupVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    // dismiss: click anywhere outside the panel
    MouseArea {
        anchors.fill: parent
        visible: root.popupVisible
        z: 0
        onClicked: {
            root.popupVisible    = false
            root.wifiPassVisible = false
            root.wifiPassError   = ""
        }
    }

    Item {
        id: focusGrabber
        focus: true
        Keys.onEscapePressed: {
            if (root.wifiPassVisible) {
                root.wifiPassVisible = false
                root.wifiPassError   = ""
                wifiPassField.text   = ""
            } else {
                root.popupVisible = false
            }
        }
    }

    //  palette  (Catppuccin Mocha — Material You)
    readonly property color panelBg:       Theme.surfaceVariant
    readonly property color activeColor:   Theme.colorOnSurface
    readonly property color inactiveColor: Theme.outline
    readonly property color textDark:      Theme.colorOnPrimary
    readonly property color textLight:     Theme.colorOnSurface
    readonly property color subtextDark:   Theme.colorOnPrimaryContainer
    readonly property color subtextLight:  Theme.colorOnSurfaceVariant
    readonly property color sliderBg:      Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.10)
    readonly property color sliderFill:    Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.45)
    readonly property color tileInactiveBg: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06)
    readonly property color tileActiveBg:   Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.14 : 0.11)
    readonly property color tileBorder:     Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.10 : 0.07)
    readonly property color tileHover:      Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.09 : 0.07)
    readonly property color sliderTrackBg:  Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.14 : 0.16)
    readonly property color sliderKnobGlow: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.12 : 0.10)

    // state
    property string wifiName:        "..."
    property int    wifiSignal:      -1
    property bool   wifiRadioOn:     false   // is the wifi radio enabled
    property bool   wifiConnected:   false   // is there an active wifi connection
    property bool   wifiHasInternet: true    // does the connection have internet
    // Convenience: legacy compat — "wifiOn" means radio is enabled
    property bool   wifiOn:          wifiRadioOn
    property bool   ethConnected:    false
    property string ethName:         ""
    property bool   btOn:            false
    property var    btDevices:       []
    property bool   isScanningBT:    false
    property bool   dndOn:           false
    property int    volume:          50

    // Wi-Fi password popup state
    property bool   wifiPassVisible: false
    property string wifiPassSsid:    ""
    property string wifiPassError:   ""
    property int    brightness: 80

    // sub-menu state
    property bool wifiMenuOpen:    false
    property bool btPanelOpen:     false
    property bool powerMenuOpen:   false
    property var  knownNetworks:   []
    property var  unknownNetworks: []

    function sigLabel(s) {
        if (s < 0) return "Off"; if (s < 30) return "Weak"
        if (s < 65) return "Medium"; return "Strong"
    }

    // helper- pick the right wifi icon asset for current state
    function wifiIcon() {
        if (!wifiRadioOn)    return "assets/icons/wifi-off.svg"
        if (!wifiConnected)  return "assets/icons/signal-wifi-statusbar-not-connected.svg"
        if (!wifiHasInternet) return "assets/icons/signal-wifi-statusbar-not-connected.svg"
        if (wifiSignal >= 75) return "assets/icons/signal-wifi-4-bar.svg"
        if (wifiSignal >= 50) return "assets/icons/network-wifi-3-bar.svg"
        if (wifiSignal >= 25) return "assets/icons/network-wifi-2-bar.svg"
        return "assets/icons/network-wifi-1-bar.svg"
    }

    // helper - subtitle text for the wifi tile
    function wifiSubtitle() {
        if (!wifiRadioOn)    return "Off"
        if (!wifiConnected)  return "Not connected"
        if (!wifiHasInternet) return "No internet"
        return sigLabel(wifiSignal)
    }

    
    //  process
    // comprehensive wifi status: radio state, active connection, connectivity, ethernet
    property string _wifiStatusBuf: ""
    Process { id: wifiProc; running: false
        command: ["bash", "-c",
            "eth=$(nmcli -t -f TYPE,STATE,NAME con show --active 2>/dev/null | awk -F: '/^802-3-ethernet:activated/{print $3; exit}'); " +
            "radio=$(nmcli -t -f WIFI general 2>/dev/null); " +
            "conn=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '/^yes/{print $2\"|\"$3;exit}'); " +
            "inet=$(nmcli -t -f CONNECTIVITY general 2>/dev/null); " +
            "echo \"ETH:${eth}|${radio}|${conn}|${inet}\""
        ]
        stdout: SplitParser { onRead: function(l) {
            // Format: "ETH:ethName|enabled|SSID|SIGNAL|full"
            var raw = l.trim()
            var ethEnd = raw.indexOf("|")
            var ethPart = raw.substring(0, ethEnd)
            var rest = raw.substring(ethEnd + 1)

            var ethName = ethPart.startsWith("ETH:") ? ethPart.substring(4) : ""
            root.ethConnected = (ethName.length > 0)
            root.ethName = ethName

            // Split rest into: [radio, SSID|SIGNAL, connectivity]
            var firstPipe = rest.indexOf("|")
            var lastPipe  = rest.lastIndexOf("|")
            if (firstPipe < 0) return

            var radio = rest.substring(0, firstPipe)
            var connPart = rest.substring(firstPipe + 1, lastPipe)
            var inet  = rest.substring(lastPipe + 1)

            // Radio state
            root.wifiRadioOn = (radio === "enabled")

            // Connection state
            if (connPart && connPart.indexOf("|") >= 0) {
                var cp = connPart.split("|")
                root.wifiName = cp[0] || "Wi-Fi"
                root.wifiSignal = parseInt(cp[1]) || 0
                root.wifiConnected = true
            } else {
                root.wifiName = "Wi-Fi"
                root.wifiSignal = -1
                root.wifiConnected = false
            }

            // Internet connectivity
            root.wifiHasInternet = (inet === "full")
        }}
    }
    Process { id: btProc; running: false
        command:["bash","-c","bluetoothctl show 2>/dev/null|grep -q 'Powered: yes'&&echo on||echo off"]
        stdout: SplitParser { onRead: function(l){root.btOn=l.trim()==="on"} }
        onRunningChanged: { if (!running) { if (root.btPanelOpen && root.btOn) { btListProc.running = true } } }
    }

    property string _btBuf: ""
    Process { id: btListProc; running: false
        command: ["/home/ubonly/.config/quickshell/bt_list.sh"]
        stdout: SplitParser { onRead: function(l) { root._btBuf += l + "\n" } }
        onRunningChanged: {
            if (!running) {
                var lines = root._btBuf.trim().split("\n")
                var devs = []
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|")
                    if (p.length < 4) continue
                    devs.push({ mac: p[0], name: p[1] || "Unknown Device", paired: p[2] === "1", connected: p[3] === "1" })
                }
                devs.sort(function(a, b) {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1;
                    if (a.paired !== b.paired) return a.paired ? -1 : 1;
                    return a.name.localeCompare(b.name);
                })
                root.btDevices = devs
                root._btBuf = ""
            } else { root._btBuf = "" }
        }
    }

    Process { id: btScanProc; running: false
        command: ["bash", "-c", "bluetoothctl --timeout 15 scan on"]
        onRunningChanged: { root.isScanningBT = running }
    }

    Process { id: btPairProc; command: []; running: false
        onRunningChanged: { if (!running) { btListProc.running = true } }
    }
    Process {
        id: dndProc
        running: true
        command: ["tail", "-F", "/home/ubonly/.config/quickshell/dnd.txt"]
        stdout: SplitParser {
            onRead: function(l) { root.dndOn = (l.trim() === "true") }
        }
    }
    Process { id: volProc; running: false
        command:["bash","-c","wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null|awk '{printf\"%d\",$2*100}'"]
        stdout: SplitParser { onRead: function(l){var v=parseInt(l);if(!isNaN(v))root.volume=v} }
    }
    Process { id: briProc; running: false
        command:["bash","-c","brightnessctl -m 2>/dev/null|awk -F, '{gsub(/%/,\"\",$4);print $4}'|head -1"]
        stdout: SplitParser { onRead: function(l){var v=parseInt(l);if(!isNaN(v))root.brightness=v} }
    }
    Process { id: cmdProc;  command:[]; running:false
        onRunningChanged:{if(!running){wifiProc.running=true;btProc.running=true}}
    }
    Process { id: volSet;   command:[]; running:false }
    Process { id: briSet;   command:[]; running:false }
    Process { id: powerProc; command:[]; running:false }

    // Wi-Fi network scan
    property string _wifiBuf: ""

    Process {
        id: wifiScanProc; running: false
        command: ["bash", "-c",
            "known=$(nmcli -t -f NAME con show 2>/dev/null | sort -u); " +
            "nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list --rescan no 2>/dev/null | " +
            "while IFS=: read ssid sig sec used; do " +
            "[ -z \"$ssid\" ] && continue; " +
            "is_known=$(echo \"$known\" | grep -qxF \"$ssid\" && echo 1 || echo 0); " +
            "echo \"${ssid}|${sig}|${sec}|${used}|${is_known}\"; " +
            "done | awk -F'|' '!seen[$1]++' | sort -t'|' -k5,5rn -k2,2rn"
        ]
        stdout: SplitParser {
            onRead: function(line) { root._wifiBuf += line + "\n" }
        }
        onRunningChanged: {
            if (!running) {
                var lines = root._wifiBuf.trim().split("\n")
                var kn = [], un = []
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|")
                    if (p.length < 5) continue
                    var e = { ssid: p[0], signal: parseInt(p[1])||0,
                              security: p[2]||"", inUse: p[3]==="*", isKnown: p[4]==="1" }
                    if (e.isKnown) kn.push(e); else un.push(e)
                }
                kn.sort(function(a, b) {
                    var aConn = (root.wifiConnected && a.ssid === root.wifiName);
                    var bConn = (root.wifiConnected && b.ssid === root.wifiName);
                    if (aConn !== bConn) return aConn ? -1 : 1;
                    return b.signal - a.signal;
                })
                root.knownNetworks = kn
                root.unknownNetworks = un
                root._wifiBuf = ""
            } else { root._wifiBuf = "" }
        }
    }

    Process { id: wifiConnProc; command:[]; running:false
        onRunningChanged: { if(!running){ wifiProc.running=true; wifiScanProc.running=true } }
    }

    // nmcli connect with password
    property string _wifiPassBuf: ""
    Process {
        id: wifiPassProc
        command: []
        running: false
        stdout: SplitParser { onRead: function(l) { root._wifiPassBuf += l + "\n" } }
        stderr: SplitParser { onRead: function(l) { root._wifiPassBuf += l + "\n" } }
        onRunningChanged: {
            if (!running) {
                var out = root._wifiPassBuf.toLowerCase()
                root._wifiPassBuf = ""
                if (out.indexOf("error") !== -1 || out.indexOf("failed") !== -1
                        || out.indexOf("secrets") !== -1 || out.indexOf("wrong") !== -1) {
                    root.wifiPassError = "Неверный пароль или ошибка подключения"
                } else {
                    root.wifiPassVisible = false
                    root.btPanelOpen = false
                    wifiProc.running = true
                    btProc.running = true
                    dndProc.running = true
                    volProc.running = true
                    briProc.running = true
                }
            }
        }
    }

    Timer{interval:5000;repeat:true;running:true;onTriggered:wifiProc.running=true}
    Timer{interval:8000;repeat:true;running:true;onTriggered:btProc.running=true}
    Timer{interval:3000;repeat:true;running:true;onTriggered:volProc.running=true}
    Timer{interval:5000;repeat:true;running:true;onTriggered:briProc.running=true}
    Component.onCompleted:{wifiProc.running=true;btProc.running=true;volProc.running=true;briProc.running=true}

    //reusable components

    // wideButton: split-interactive tile
    //    icon click  → iconClicked()  (toggle state)
    //    card body   → clicked()      (open sub-menu)
    component WideButton: Rectangle {
        id: wb
        property bool   active:   false
        property string icon:     ""
        property string title:    ""
        property string subtitle: ""
        signal iconClicked()
        signal clicked()

        Layout.fillWidth:  true
        implicitHeight: 76
        radius: 18
        color:  active ? root.tileActiveBg : root.tileInactiveBg
        border.width: 1
        border.color: active ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.14) : root.tileBorder

        // card-body MouseArea (covers everything, lowest z)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: wb.clicked()
        }

        RowLayout {
            anchors { fill:parent; leftMargin:16; rightMargin:12 }
            spacing: 10

            // icon circle — separate toggle target (higher z)
            Rectangle {
                Layout.preferredWidth:40; Layout.preferredHeight:40; radius:20
                color: iconArea.containsMouse ? root.tileHover : Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.08)

                Image {
                    id: wbIconImg
                    anchors.centerIn: parent
                    width: 20; height: 20
                    source: wb.icon
                    sourceSize: Qt.size(20, 20)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: wbIconImg
                    source: wbIconImg
                    color: root.textLight
                }

                MouseArea {
                    id: iconArea; anchors.fill:parent
                    cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                    onClicked: wb.iconClicked()
                }
            }

            // labels (clicks fall through to card-body)
            ColumnLayout {
                Layout.fillWidth:true; spacing:1
                Text {
                    text:wb.title; font.pixelSize:13; font.family:"Google Sans"
                    font.weight:Font.Medium
                    color: root.textLight
                    elide:Text.ElideRight; Layout.fillWidth:true
                }
                Text {
                    text:wb.subtitle; font.pixelSize:11; font.family:"Google Sans"
                    color: root.textLight
                    visible: wb.subtitle !== ""
                }
            }

            // chevron (clicks fall through to card-body)
            Text {
                text:"›"; font.pixelSize:20; font.weight:Font.Bold
                color: root.textLight
            }
        }
    }

    // sliderRow: thick rounded slider with icon + right buttons
    component SliderRow: Rectangle {
        id: sr
        property string leftIcon: ""
        property string rightIcon: ""
        property int    value: 50
        property bool   dragging: false
        signal moved(int newValue)

        Layout.fillWidth: true
        implicitHeight: 48; radius: 24
        color: root.sliderBg

        RowLayout {
            anchors { fill:parent; leftMargin:16; rightMargin:8 }
            spacing: 10

            Item {
                implicitWidth: 22; implicitHeight: 22
                Image {
                    id: srLeftImg
                    anchors.fill: parent
                    source: sr.leftIcon
                    sourceSize: Qt.size(22, 22)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: srLeftImg
                    source: srLeftImg
                    color: root.sliderFill
                }
            }

            Item {
                Layout.fillWidth:true; implicitHeight:12

                Rectangle {
                    id: sliderTrack
                    anchors { left:parent.left; right:parent.right; verticalCenter:parent.verticalCenter }
                    height:8; radius:4; color:root.sliderTrackBg

                    Rectangle {
                        width: Math.max(8, parent.width * (sr.value / 100))
                        height:parent.height; radius:parent.radius; color:root.sliderFill

                    }

                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - 16, parent.width * (sr.value / 100) - 8))
                        y: -4; width:16; height:16; radius:8
                        color: root.sliderFill


                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: root.sliderKnobGlow
                        }
                    }

                    MouseArea {
                        anchors { fill:parent; topMargin:-12; bottomMargin:-12 }
                        cursorShape: Qt.PointingHandCursor

                        onPressed: function(m) {
                            sr.dragging = true
                            var p = Math.max(0, Math.min(100, Math.round(m.x / width * 100)))
                            sr.moved(p)
                        }
                        onPositionChanged: function(m) {
                            if (sr.dragging) {
                                var p = Math.max(0, Math.min(100, Math.round(m.x / width * 100)))
                                sr.moved(p)
                            }
                        }
                        onReleased: { sr.dragging = false }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth:36; Layout.preferredHeight:36; radius:10
                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.08)
                Image {
                    id: srRightImg
                    anchors.centerIn: parent
                    width: 18; height: 18
                    source: sr.rightIcon
                    sourceSize: Qt.size(18, 18)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: srRightImg
                    source: srRightImg
                    color: root.textLight
                }
                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor }
            }

            Rectangle {
                Layout.preferredWidth:28; Layout.preferredHeight:28; radius:14
                color: "transparent"
                Text {
                    anchors.centerIn:parent; text:"›"; font.pixelSize:18; font.weight:Font.Bold
                    color:root.subtextLight
                }
                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor }
            }
        }
    }

    // NetworkItem: single row in Wi-Fi dropdown
    component NetworkItem: Rectangle {
        id: ni
        property string ssid:     ""
        property int    sigVal:   0
        property string security: ""
        property bool   inUse:    false
        signal clicked()

        implicitHeight: 42
        Layout.fillWidth: true
        radius: 12
                color: niArea.containsMouse ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06) : "transparent"

        RowLayout {
            anchors { fill:parent; leftMargin:14; rightMargin:14 }
            spacing: 10

            Item {
                implicitWidth: 18; implicitHeight: 18
                Image {
                    id: niWifiImg
                    anchors.fill: parent
                    source: {
                        if (ni.sigVal >= 75) return "assets/icons/signal-wifi-4-bar.svg"
                        if (ni.sigVal >= 50) return "assets/icons/network-wifi-3-bar.svg"
                        if (ni.sigVal >= 25) return "assets/icons/network-wifi-2-bar.svg"
                        return "assets/icons/network-wifi-1-bar.svg"
                    }
                    sourceSize: Qt.size(18, 18)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: niWifiImg
                    source: niWifiImg
                    color: root.textLight
                }
            }

            Text {
                text: ni.ssid; font.pixelSize:13; font.family:"Google Sans"
                font.weight: ni.inUse ? Font.SemiBold : Font.Normal
                color: root.textLight
                elide: Text.ElideRight; Layout.fillWidth: true
            }

            Rectangle {
                visible: ni.inUse
                implicitWidth: connLbl.implicitWidth + 12; implicitHeight: 18; radius: 9
                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.14)
                Text {
                    id: connLbl; anchors.centerIn:parent
                    text:"Connected"; font.pixelSize:9; font.family:"Google Sans"
                    font.weight:Font.SemiBold; color:root.textLight
                }
            }

            Item {
                visible: ni.security !== "" && ni.security !== "--"
                implicitWidth: 14; implicitHeight: 14
                Image {
                    id: niLockImg
                    anchors.fill: parent
                    source: "assets/icons/lock.svg"
                    sourceSize: Qt.size(14, 14)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: niLockImg
                    source: niLockImg
                    color: root.textLight
                }
            }

            Text {
                text: ni.sigVal + "%"; font.pixelSize:11; font.family:"Google Sans"
                color: root.subtextLight
            }
        }

        MouseArea {
            id: niArea; anchors.fill:parent
            cursorShape:Qt.PointingHandCursor; hoverEnabled:true
            onClicked: ni.clicked()
        }
    }

    //main panel
    Rectangle {
        id: panel
        z: 10
        anchors { bottom:parent.bottom; bottomMargin:64; right:parent.right; rightMargin:16 }

        // Stop clicks on the panel from dismissing it
        MouseArea { anchors.fill: parent; onClicked: {} }
        width:  380
        height: root.btPanelOpen
            ? (btCol.implicitHeight + 32)
            : (outerCol.implicitHeight + 32)
        radius: 24
        color:  root.panelBg

        scale: root.popupVisible ? 1.0 : 0.95
        opacity: root.popupVisible ? 1.0 : 0.0
        transformOrigin: Item.BottomRight

        transform: Translate {
            y: root.popupVisible ? 0 : 24
            Behavior on y {
                NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
            }
        }

        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        border.color: Theme.outlineVariant
        border.width: 1

        ColumnLayout {
            id: outerCol
            anchors {
                top:parent.top;    topMargin:16
                left:parent.left;  leftMargin:16
                right:parent.right;rightMargin:16
            }
            spacing: 10
            visible: !root.btPanelOpen

            
            //  tiles: Wi-Fi + Bluetooth  (side by side)
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                WideButton {
                    active: root.ethConnected || root.wifiRadioOn
                    icon:   root.ethConnected ? "assets/icons/ethernet.svg" : root.wifiIcon()
                    title:  root.ethConnected ? root.ethName : (root.wifiConnected ? root.wifiName : "Wi-Fi")
                    subtitle: root.ethConnected ? "Connected" : root.wifiSubtitle()
                    Layout.fillWidth: true
                    onIconClicked: {
                        cmdProc.command = root.wifiRadioOn
                            ? ["nmcli","radio","wifi","off"]
                            : ["nmcli","radio","wifi","on"]
                        cmdProc.running = true
                    }
                    onClicked: {
                        root.wifiMenuOpen = !root.wifiMenuOpen
                        if (root.wifiMenuOpen) wifiScanProc.running = true
                    }
                }

                WideButton {
                    active: root.btOn
                    icon:   "assets/icons/bluetooth.svg"
                    title:  "Bluetooth"
                    subtitle: root.btOn ? "On" : "Off"
                    Layout.fillWidth: true
                    onIconClicked: {
                        cmdProc.command = root.btOn
                            ? ["rfkill","block","bluetooth"]
                            : ["rfkill","unblock","bluetooth"]
                        cmdProc.running = true
                    }
                    onClicked: {
                        root.btPanelOpen = true
                    }
                }
            }

            
            //  tiles: screen capture + do not disturb (side by side)
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                WideButton {
                    active: false
                    icon:   "assets/icons/screenshot.svg"
                    title:  "Screen capture"
                    subtitle: "Capture region"
                    Layout.fillWidth: true
                    onIconClicked: {
                        root.popupVisible = false
                        cmdProc.command = ["qs", "ipc", "call", "screenshot", "region"]
                        cmdProc.running = true
                    }
                    onClicked: {
                        root.popupVisible = false
                        cmdProc.command = ["qs", "ipc", "call", "screenshot", "region"]
                        cmdProc.running = true
                    }
                }

                WideButton {
                    active: root.dndOn
                    icon:   root.dndOn ? "assets/icons/notifications-off.svg" : "assets/icons/notifications.svg"
                    title:  "Do not disturb"
                    subtitle: root.dndOn ? "On" : "Off"
                    Layout.fillWidth: true
                    onIconClicked: {
                        cmdProc.command = ["bash", "-c", "if [ \"$(cat ~/.config/quickshell/dnd.txt)\" = \"true\" ]; then echo false > ~/.config/quickshell/dnd.txt; else echo true > ~/.config/quickshell/dnd.txt; fi"]
                        cmdProc.running = true
                    }
                    onClicked: {
                        cmdProc.command = ["bash", "-c", "if [ \"$(cat ~/.config/quickshell/dnd.txt)\" = \"true\" ]; then echo false > ~/.config/quickshell/dnd.txt; else echo true > ~/.config/quickshell/dnd.txt; fi"]
                        cmdProc.running = true
                    }
                }
            }


            //wifi dropdow menu
            Rectangle {
                id: wifiDropdown
                Layout.fillWidth: true
                implicitHeight: root.wifiMenuOpen ? wifiCol.implicitHeight + 24 : 0
                clip: true
                radius: 18
                color: Theme.surface
                border.color: Theme.outlineVariant
                border.width: 1
                visible: implicitHeight > 0 || wifiHeightAnim.running

                opacity: root.wifiMenuOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on implicitHeight { NumberAnimation { id: wifiHeightAnim; duration: 250; easing.type: Easing.OutQuint } }


                ColumnLayout {
                    id: wifiCol
                    anchors {
                        top:parent.top; topMargin:12
                        left:parent.left; leftMargin:8
                        right:parent.right; rightMargin:8
                    }
                    spacing: 2

                    // known networks list
                    Text {
                        text: "Known networks"
                        font.pixelSize:11; font.family:"Google Sans"; font.weight:Font.SemiBold
                        color: root.subtextLight
                        Layout.leftMargin:8; Layout.bottomMargin:2
                        visible: root.knownNetworks.length > 0
                    }

                    Repeater {
                        model: root.knownNetworks
                        NetworkItem {
                            ssid: modelData.ssid; sigVal: modelData.signal
                            security: modelData.security
                            inUse: root.wifiConnected && modelData.ssid === root.wifiName
                            onClicked: {
                                wifiConnProc.command = ["nmcli","con","up",modelData.ssid]
                                wifiConnProc.running = true
                            }
                        }
                    }

                    // separator
                    Rectangle {
                        Layout.fillWidth:true; Layout.topMargin:4; Layout.bottomMargin:4
                        Layout.leftMargin:8; Layout.rightMargin:8
                        implicitHeight: 1; color: Qt.rgba(1,1,1,0.06)
                        visible: root.knownNetworks.length > 0 && root.unknownNetworks.length > 0
                    }

                    // unknown networks list
                    Text {
                        text: "Unknown networks"
                        font.pixelSize:11; font.family:"Google Sans"; font.weight:Font.SemiBold
                        color: root.subtextLight
                        Layout.leftMargin:8; Layout.bottomMargin:2
                        visible: root.unknownNetworks.length > 0
                    }

                    Repeater {
                        model: root.unknownNetworks
                        NetworkItem {
                            ssid: modelData.ssid; sigVal: modelData.signal
                            security: modelData.security; inUse: false
                            onClicked: {
                                root.wifiPassSsid    = modelData.ssid
                                root.wifiPassError   = ""
                                wifiPassField.text   = ""
                                root.wifiPassVisible = true
                            }
                        }
                    }

                    // empty state
                    Text {
                        visible: root.knownNetworks.length === 0 && root.unknownNetworks.length === 0
                        text: "Scanning for networks…"
                        font.pixelSize:12; font.family:"Google Sans"; font.italic:true
                        color: root.subtextLight
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin:8; Layout.bottomMargin:8
                    }
                }
            }

            //volume slider
            SliderRow {
                leftIcon:  "assets/icons/volume-up.svg"
                rightIcon: "assets/icons/music-note.svg"
                value: root.volume
                onMoved: function(v) {
                    root.volume = v
                    volSet.command = ["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",(v/100).toFixed(2)]
                    volSet.running = true
                }
            }

            //brightness slider (currently broken)
            SliderRow {
                leftIcon:  "assets/icons/brightness-5.svg"
                rightIcon: "assets/icons/wb-sunny.svg"
                value: root.brightness
                onMoved: function(v) {
                    root.brightness = v
                    briSet.command = ["brightnessctl","set",v+"%"]
                    briSet.running = true
                }
            }

            
            //  footer: Power + Settings
            
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Rectangle {
                    id: powerBtn
                    implicitWidth:56; implicitHeight:38; radius:19
                    color: powerBtnMa.containsMouse ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.85) : Theme.colorOnSurface
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout { anchors.centerIn:parent; spacing:4
                        Image {
                            id: powerImg
                            width: 17; height: 17
                            source: "assets/icons/power-settings-new.svg"
                            sourceSize: Qt.size(17, 17)
                            visible: false
                        }
                        ColorOverlay {
                            width: powerImg.width; height: powerImg.height
                            source: powerImg
                            color: Theme.surface
                        }
                        Text { text:"▾"; font.pixelSize:11; color:Theme.surface; font.bold: true }
                    }

                    MouseArea {
                        id: powerBtnMa
                        anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.powerMenuOpen = !root.powerMenuOpen
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: settingsBtn
                    implicitWidth:38; implicitHeight:38; radius:19
                    color: settingsBtnMa.containsMouse ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.85) : Theme.colorOnSurface
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Image {
                        id: settingsImg
                        anchors.centerIn: parent
                        width: 17; height: 17
                        source: "assets/icons/settings.svg"
                        sourceSize: Qt.size(17, 17)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: settingsImg
                        source: settingsImg
                        color: Theme.surface
                    }

                    MouseArea {
                        id: settingsBtnMa
                        anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (root.settingsWindow)
                                root.settingsWindow.settingsVisible = true
                            root.popupVisible = false
                        }
                    }
                }
            }

            //turn off/restart/sleep/log-out list  
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: root.powerMenuOpen ? powerMenuCol.implicitHeight + 16 : 0
                clip: true
                radius: 18
                color: Theme.surface
                border.color: Theme.outlineVariant
                border.width: 1
                visible: implicitHeight > 0 || heightAnim.running

                opacity: root.powerMenuOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on implicitHeight { NumberAnimation { id: heightAnim; duration: 250; easing.type: Easing.OutQuint } }


                ColumnLayout {
                    id: powerMenuCol
                    anchors {
                        top: parent.top; topMargin: 8
                        left: parent.left; leftMargin: 6
                        right: parent.right; rightMargin: 6
                    }
                    spacing: 0

                    // inline component: single power menu row
                    Repeater {
                        model: [
                            { icon: "assets/icons/power-settings-new.svg", label: "Выключить",     cmd: "systemctl poweroff" },
                            { icon: "assets/icons/restart-alt.svg",       label: "Перезагрузить",  cmd: "systemctl reboot" },
                            { icon: "assets/icons/logout.svg",            label: "Выйти",          cmd: "hyprctl dispatch exit" },
                            { icon: "assets/icons/lock-outline.svg",      label: "Заблокировать",  cmd: "hyprlock" }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 42
                            radius: 12
                            color: pmArea.containsMouse ? Theme.activeBg : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                spacing: 12

                                Item {
                                    implicitWidth: 20; implicitHeight: 20
                                    Image {
                                        id: pmIcon
                                        anchors.fill: parent
                                        source: modelData.icon
                                        sourceSize: Qt.size(20, 20)
                                        visible: false
                                    }
                                    ColorOverlay {
                                        anchors.fill: pmIcon
                                        source: pmIcon
                                        color: pmArea.containsMouse ? Theme.colorOnPrimaryContainer : Theme.colorOnSurface
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                }

                                Text {
                                    text: modelData.label
                                    font.pixelSize: 13; font.family: "Google Sans"
                                    font.weight: Font.Normal
                                    color: pmArea.containsMouse ? Theme.colorOnPrimaryContainer : Theme.colorOnSurface
                                    Layout.fillWidth: true
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }

                            MouseArea {
                                id: pmArea; anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: {
                                    root.powerMenuOpen = false
                                    root.popupVisible  = false
                                    powerProc.command = ["bash", "-c", modelData.cmd]
                                    powerProc.running = true
                                }
                            }
                        }
                    }
                }
            }

            Item { implicitHeight: 2 }
        }

        //bluetooth sub menu panel (dont work)
        ColumnLayout {
            id: btCol
            visible: root.btPanelOpen
            anchors {
                top:parent.top;    topMargin:16
                left:parent.left;  leftMargin:16
                right:parent.right;rightMargin:16
            }
            spacing: 10

            // header: back  |  "Bluetooth"  |  settings gear ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                // back button
                Rectangle {
                    implicitWidth:36; implicitHeight:36; radius:18
                    color: backArea.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"

                    Image {
                        id: backImg
                        anchors.centerIn: parent
                        width: 18; height: 18
                        source: "assets/icons/arrow-back.svg"
                        sourceSize: Qt.size(18, 18)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: backImg
                        source: backImg
                        color: root.textLight
                    }
                    MouseArea {
                        id: backArea; anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: root.btPanelOpen = false
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Bluetooth"
                    font.pixelSize: 16; font.family: "Google Sans"
                    font.weight: Font.SemiBold
                    color: root.textLight
                }

                Item { Layout.fillWidth: true }

                // settings gear
                Rectangle {
                    implicitWidth:36; implicitHeight:36; radius:18
                    color: gearArea.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"

                    Image {
                        id: btGearImg
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: "assets/icons/settings.svg"
                        sourceSize: Qt.size(16, 16)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: btGearImg
                        source: btGearImg
                        color: root.textLight
                    }
                    MouseArea {
                        id: gearArea; anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                    }
                }
            }

            // main toggle card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 56
                radius: 18
                color: root.btOn 
                       ? (toggleArea.containsMouse ? Qt.darker(root.activeColor, 1.1) : root.activeColor) 
                       : (toggleArea.containsMouse ? Qt.lighter(root.inactiveColor, 1.3) : root.inactiveColor)

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 12

                    // BT icon
                    Rectangle {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                        color: root.btOn ? Qt.rgba(0,0,0,0.10) : Qt.rgba(1,1,1,0.06)
                        Image {
                            id: btToggleImg
                            anchors.centerIn: parent
                            width: 18; height: 18
                            source: "assets/icons/bluetooth.svg"
                            sourceSize: Qt.size(18, 18)
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: btToggleImg
                            source: btToggleImg
                            color: root.btOn ? root.textDark : root.textLight
                        }
                    }

                    Text {
                        text: root.btOn ? "On" : "Off"
                        font.pixelSize: 14; font.family: "Google Sans"
                        font.weight: Font.Medium
                        color: root.btOn ? root.textDark : root.textLight
                        Layout.fillWidth: true
                    }

                    // toggle switch
                    Rectangle {
                        id: btSwitch
                        implicitWidth: 44; implicitHeight: 24; radius: 12
                        color: root.btOn
                            ? Qt.rgba(0.06, 0.06, 0.10, 0.35)
                            : Qt.rgba(1,1,1,0.12)

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.btOn ? parent.width - width - 3 : 3
                            color: root.btOn ? root.textDark : root.subtextLight
                        }
                    }
                }

                MouseArea {
                    id: toggleArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        cmdProc.command = root.btOn
                            ? ["rfkill","block","bluetooth"]
                            : ["rfkill","unblock","bluetooth"]
                        cmdProc.running = true
                    }
                }
            }

            //device list card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: btDeviceCol.implicitHeight + 16
                radius: 18
                color: root.inactiveColor

                ColumnLayout {
                    id: btDeviceCol
                    anchors {
                        top: parent.top; topMargin: 8
                        left: parent.left; leftMargin: 4
                        right: parent.right; rightMargin: 4
                    }
                    spacing: 0

                    // pair new device
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 44; radius: 12
                        color: pairArea.containsMouse ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06) : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                                Image {
                                    id: addImg
                                    anchors.centerIn: parent
                                    width: 14; height: 14
                                    source: "assets/icons/add.svg"
                                    sourceSize: Qt.size(14, 14)
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: addImg
                                    source: addImg
                                    color: root.activeColor
                                }
                            }

                            Text {
                                text: root.isScanningBT ? "Scanning..." : "Pair new device"
                                font.pixelSize: 13; font.family: "Google Sans"
                                font.weight: Font.Medium
                                color: root.activeColor
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: pairArea; anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: {
                                btScanProc.running = true
                                btListProc.running = true
                            }
                        }
                    }

                    //separator
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14; Layout.rightMargin: 14
                        implicitHeight: 1
                        color: Qt.rgba(1,1,1,0.06)
                    }

                    // Empty State Placeholder
                    Item {
                        visible: root.btDevices.length === 0 && !root.isScanningBT
                        Layout.fillWidth: true
                        implicitHeight: 52
                        Text {
                            anchors.centerIn: parent
                            text: "No device connected"
                            font.pixelSize: 12; font.family: "Google Sans"
                            font.italic: true
                            color: root.subtextLight
                        }
                    }

                    Repeater {
                        model: root.btDevices
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            color: devArea.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"
                            radius: 12

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                                    color: modelData.connected ? root.activeColor : Qt.rgba(1,1,1,0.08)
                                    Image {
                                        id: devImg
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        source: "assets/icons/bluetooth.svg"
                                        sourceSize: Qt.size(16, 16)
                                        visible: false
                                    }
                                    ColorOverlay {
                                        anchors.fill: devImg
                                        source: devImg
                                        color: modelData.connected ? root.textDark : root.textLight
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: modelData.name
                                        font.pixelSize: 13; font.family: "Google Sans"
                                        font.weight: Font.Medium
                                        color: root.textLight
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                                        font.pixelSize: 11; font.family: "Google Sans"
                                        color: modelData.connected ? root.activeColor : root.subtextLight
                                        visible: text !== ""
                                    }
                                }
                            }

                            MouseArea {
                                id: devArea; anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: {
                                    if (modelData.connected) {
                                        cmdProc.command = ["bash", "-c", "bluetoothctl disconnect " + modelData.mac]
                                    } else if (modelData.paired) {
                                        cmdProc.command = ["bash", "-c", "bluetoothctl connect " + modelData.mac]
                                    } else {
                                        cmdProc.command = ["bash", "-c", "bluetoothctl pair " + modelData.mac + " && bluetoothctl connect " + modelData.mac]
                                    }
                                    cmdProc.running = true
                                    btPairProc.running = true
                                }
                            }
                        }
                    }

                    //separator
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14; Layout.rightMargin: 14
                        implicitHeight: 1
                        color: Qt.rgba(1,1,1,0.06)
                    }

                    // Advanced settings
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 44; radius: 12
                        color: advArea.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            spacing: 10
                            Text {
                                text: "Advanced settings"
                                font.pixelSize: 13; font.family: "Google Sans"
                                font.weight: Font.Medium
                                color: root.textLight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: advArea; anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: {
                                cmdProc.command = ["bash", "-c", "hyprctl dispatch exec blueman-manager &"]
                                cmdProc.running = true
                                root.popupVisible = false
                            }
                        }
                    }
                }
            }

            Item { implicitHeight: 2 }
        }
    }
    //  WI-FI PASSWORD POPUP
    Rectangle {
        id: wifiPassOverlay
        anchors.fill: parent
        visible: root.wifiPassVisible && root.popupVisible

        // Full-screen transparent backdrop to catch clicks everywhere
        color: Qt.rgba(0, 0, 0, 0.35)

        // Auto-focus the password field when overlay becomes visible
        onVisibleChanged: {
            if (visible) {
                focusTimer.restart()
            }
        }
        Timer {
            id: focusTimer
            interval: 50
            onTriggered: wifiPassField.forceActiveFocus()
        }

        // catch any key press when focus is NOT on the TextInput > close
        Keys.onPressed: function(event) {
            if (!wifiPassField.activeFocus) {
                root.wifiPassVisible = false
                root.wifiPassError   = ""
                wifiPassField.text   = ""
                event.accepted = true
            }
        }

        // dismiss on backdrop click (outside the card)
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.wifiPassVisible = false
                root.wifiPassError   = ""
                wifiPassField.text   = ""
            }
        }

        // password card (positioned near the panel in top-right)
        Rectangle {
            id: wifiPassCard
            z: 10
            anchors {
                bottom: parent.bottom; bottomMargin: 64
                right: parent.right; rightMargin: 16
            }
            width: 380
            height: wifiPassCol.implicitHeight + 48
            radius: 20
            color: root.panelBg
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            // stop clicks from propagating to overlay dismiss; re-focus field
            MouseArea {
                anchors.fill: parent
                onClicked: wifiPassField.forceActiveFocus()
            }

            ColumnLayout {
                id: wifiPassCol
                anchors {
                    top: parent.top; topMargin: 24
                    left: parent.left; leftMargin: 20
                    right: parent.right; rightMargin: 20
                }
                spacing: 0

                // lock icon
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 12
                    implicitWidth: 40; implicitHeight: 40

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                    }
                    Image {
                        id: popupLockImg
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/lock.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: popupLockImg
                        source: popupLockImg
                        color: root.activeColor
                    }
                }

                // network name
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 4
                    text: root.wifiPassSsid
                    font.pixelSize: 15; font.family: "Google Sans"
                    font.weight: Font.SemiBold
                    color: root.textLight
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 20
                    text: "Введите пароль для подключения"
                    font.pixelSize: 11; font.family: "Google Sans"
                    color: root.subtextLight
                }

                //password input fieldd
                Rectangle {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    implicitHeight: 44
                    radius: 12
                    color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.05)
                    border.color: wifiPassField.activeFocus
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.70)
                        : Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.10)
                    border.width: wifiPassField.activeFocus ? 1.5 : 1

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                        spacing: 8

                        TextInput {
                            id: wifiPassField
                            Layout.fillWidth: true
                            echoMode: showPassBtn.showPass
                                ? TextInput.Normal
                                : TextInput.Password
                            passwordCharacter: "•"
                            color: root.textLight
                            selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                            font.pixelSize: 13; font.family: "Google Sans"
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true

                            Keys.onReturnPressed: connectBtn.doConnect()
                            Keys.onEscapePressed: {
                                root.wifiPassVisible = false
                                root.wifiPassError = ""
                            }
                        }

                        //eye toggle button
                        Rectangle {
                            id: showPassBtn
                            property bool showPass: false
                            implicitWidth: 28; implicitHeight: 28; radius: 8
                            color: eyeArea.containsMouse
                                ? Qt.rgba(1,1,1,0.10) : "transparent"

                            Image {
                                id: eyeImg
                                anchors.centerIn: parent
                                width: 16; height: 16
                                source: showPassBtn.showPass
                                    ? "assets/icons/visibility.svg"
                                    : "assets/icons/visibility-off.svg"
                                sourceSize: Qt.size(16, 16)
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: eyeImg
                                source: eyeImg
                                color: root.subtextLight
                            }

                            MouseArea {
                                id: eyeArea; anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: showPassBtn.showPass = !showPassBtn.showPass
                            }
                        }
                    }
                }

                //error mesage
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: root.wifiPassError !== "" ? 12 : 0
                    text: root.wifiPassError
                    font.pixelSize: 11; font.family: "Google Sans"
                    color: Theme.error
                    visible: root.wifiPassError !== ""
                }

                //connecting indicator
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 12
                    text: "Подключение…"
                    font.pixelSize: 11; font.family: "Google Sans"
                    color: root.activeColor
                    visible: wifiPassProc.running
                }

                //buttons row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Cancel
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40; radius: 12
                        color: cancelArea.containsMouse
                            ? Qt.rgba(1,1,1,0.10) : root.inactiveColor

                        Text {
                            anchors.centerIn: parent
                            text: "Отмена"
                            font.pixelSize: 13; font.family: "Google Sans"
                            font.weight: Font.Medium
                            color: root.textLight
                        }
                        MouseArea {
                            id: cancelArea; anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: {
                                root.wifiPassVisible = false
                                root.wifiPassError   = ""
                                wifiPassField.text   = ""
                            }
                        }
                    }

                    //connect
                    Rectangle {
                        id: connectBtn
                        function doConnect() {
                            if (wifiPassField.text.length < 8) {
                                root.wifiPassError = "Пароль должен быть не менее 8 символов"
                                return
                            }
                            root.wifiPassError = ""
                            wifiPassProc.command = [
                                "nmcli", "dev", "wifi", "connect",
                                root.wifiPassSsid,
                                "password", wifiPassField.text
                            ]
                            wifiPassProc.running = true
                        }

                        Layout.fillWidth: true
                        implicitHeight: 40; radius: 12
                        color: connectArea.containsMouse
                            ? Qt.lighter(root.activeColor, 1.12) : root.activeColor
                        opacity: wifiPassProc.running ? 0.55 : 1.0

                        Text {
                            anchors.centerIn: parent
                            text: wifiPassProc.running ? "…" : "Подключиться"
                            font.pixelSize: 13; font.family: "Google Sans"
                            font.weight: Font.SemiBold
                            color: root.textDark
                        }
                        MouseArea {
                            id: connectArea; anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            enabled: !wifiPassProc.running
                            onClicked: connectBtn.doConnect()
                        }
                    }
                }
            }
        }
    }
}
