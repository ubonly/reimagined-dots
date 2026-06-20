import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "Theme"
import "services"

PanelWindow {
    id: mediaPopup
    property var screenRef
    property bool isOpen: false

    screen: screenRef
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-media"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    // Keep window alive during close animation
    property bool _animVisible: false
    visible: _animVisible

    onIsOpenChanged: {
        if (isOpen) {
            _animVisible = true
            focusGrabber.forceActiveFocus()
        } else {
            closeTimer.start()
        }
    }

    Item {
        id: focusGrabber
        focus: true
        Keys.onPressed: function(event) {
            mediaPopup.isOpen = false
            event.accepted = true
        }
    }

    Timer {
        id: closeTimer
        interval: 260
        repeat: false
        onTriggered: mediaPopup._animVisible = false
    }

    // Dismiss area
    MouseArea {
        anchors.fill: parent
        visible: mediaPopup.isOpen
        z: 0
        onClicked: mediaPopup.isOpen = false
    }

    // Time formatting helper
    function formatTime(microsecs) {
        if (isNaN(microsecs) || microsecs <= 0) return "0:00";
        var totalSeconds = Math.floor(microsecs / 1000000);
        var minutes = Math.floor(totalSeconds / 60);
        var seconds = totalSeconds % 60;
        return minutes + ":" + (seconds < 10 ? "0" + seconds : seconds);
    }

    // Live position tracking timer
    Timer {
        id: positionTimer
        interval: 1000
        running: mediaPopup.isOpen && MprisService.activePlayer && MprisService.activePlayer.isPlaying
        repeat: true
        property int localPosition: 0

        onRunningChanged: {
            if (running && MprisService.activePlayer) {
                localPosition = MprisService.activePlayer.position;
            }
        }

        onTriggered: {
            if (MprisService.activePlayer) {
                localPosition = Math.min(MprisService.activePlayer.length, localPosition + 1000000);
            }
        }
    }

    // Active track position
    readonly property real currentPosition: MprisService.activePlayer
        ? (MprisService.activePlayer.isPlaying ? positionTimer.localPosition : MprisService.activePlayer.position)
        : 0

    Connections {
        target: MprisService.activePlayer ?? null
        ignoreUnknownSignals: true
        
        function onPositionChanged() {
            positionTimer.localPosition = MprisService.activePlayer.position;
        }
        function onPlaybackStateChanged() {
            positionTimer.localPosition = MprisService.activePlayer.position;
        }
        function onTrackTitleChanged() {
            positionTimer.localPosition = MprisService.activePlayer.position;
        }
    }

    // Main popup container
    Rectangle {
        id: bgRect
        z: 10
        anchors { bottom: parent.bottom; right: parent.right; bottomMargin: 64; rightMargin: 16 }

        // Stop clicks from falling through to the dismiss area
        MouseArea { anchors.fill: parent; onClicked: {} }

        width: 360
        height: contentCol.implicitHeight + 24
        color: Theme.surfaceVariant
        radius: 20
        border.color: Theme.outlineVariant
        border.width: 1
        clip: true

        scale: mediaPopup.isOpen ? 1.0 : 0.95
        opacity: mediaPopup.isOpen ? 1.0 : 0.0
        transformOrigin: Item.BottomRight

        transform: Translate {
            y: mediaPopup.isOpen ? 0 : 24
            Behavior on y {
                NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
            }
        }

        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        ColumnLayout {
            id: contentCol
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 16; leftMargin: 16; rightMargin: 16
            }
            spacing: 12

            // Header Row: title & player selector
            RowLayout {
                Layout.fillWidth: true
                implicitHeight: 32

                Text {
                    text: "Media Control"
                    color: Theme.colorOnSurface
                    font { family: "Google Sans"; pixelSize: 15; weight: Font.Bold }
                    Layout.fillWidth: true
                }

                // Horizontal selector for other players
                RowLayout {
                    spacing: 6
                    visible: MprisService.players.length > 1

                    Repeater {
                        model: MprisService.players
                        delegate: Rectangle {
                            id: selBtn
                            width: 26; height: 26; radius: 13
                            color: MprisService.activePlayer === modelData
                                ? Theme.primary
                                : (selArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            border.color: MprisService.activePlayer === modelData
                                ? Theme.primary
                                : Theme.outlineVariant
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: (modelData.identity ? modelData.identity.substring(0, 1).toUpperCase() : "?")
                                font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold }
                                color: MprisService.activePlayer === modelData ? Theme.colorOnPrimary : Theme.colorOnSurface
                            }

                            MouseArea {
                                id: selArea; anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: MprisService.setActivePlayer(modelData)
                            }
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Empty state (no active players)
            Item {
                Layout.fillWidth: true
                implicitHeight: 80
                visible: !MprisService.activePlayer

                Text {
                    anchors.centerIn: parent
                    text: "No active media playing"
                    color: Theme.colorOnSurfaceVariant
                    font { family: "Google Sans"; pixelSize: 13; italic: true }
                }
            }

            // Active player layout
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14
                visible: !!MprisService.activePlayer

                // Row: Album Art + Track Information
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Album Art
                    Rectangle {
                        id: artWrapper
                        width: 76; height: 76; radius: 14
                        color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.08)
                        border.color: Theme.outlineVariant
                        border.width: 1
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: MprisService.activePlayer ? (MprisService.activePlayer.trackArtUrl || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: MprisService.activePlayer && MprisService.activePlayer.trackArtUrl !== ""
                            mipmap: true
                            asynchronous: true
                        }

                        Image {
                            id: genericNote
                            anchors.centerIn: parent
                            width: 28; height: 28
                            source: "assets/icons/music-note.svg"
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: genericNote
                            source: genericNote
                            color: Theme.colorOnSurfaceVariant
                            opacity: 0.5
                            visible: !MprisService.activePlayer || MprisService.activePlayer.trackArtUrl === ""
                        }
                    }

                    // Track details
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: MprisService.activePlayer ? (MprisService.activePlayer.trackTitle || "Unknown Track") : ""
                            color: Theme.colorOnSurface
                            font { family: "Google Sans"; pixelSize: 15; weight: Font.Bold }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: MprisService.activePlayer ? (MprisService.activePlayer.trackArtist || "Unknown Artist") : ""
                            color: Theme.colorOnSurfaceVariant
                            font { family: "Google Sans"; pixelSize: 13 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: MprisService.activePlayer ? (MprisService.activePlayer.identity || "Media Player") : ""
                            color: Theme.primary
                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // Progress SeekBar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Slider Track
                    Rectangle {
                        id: progressTrack
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.12)

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                            width: {
                                if (MprisService.activePlayer && MprisService.activePlayer.length > 0) {
                                    return parent.width * (Math.max(0, Math.min(MprisService.activePlayer.length, currentPosition)) / MprisService.activePlayer.length);
                                }
                                return 0;
                            }

                            Rectangle {
                                width: 10; height: 10; radius: 5
                                anchors { verticalCenter: parent.verticalCenter; horizontalCenter: parent.right }
                                color: Theme.primary
                                visible: progressArea.containsMouse
                            }
                        }

                        MouseArea {
                            id: progressArea
                            anchors.fill: parent
                            anchors.margins: -4 // Expands click area slightly for easier interactions
                            cursorShape: (MprisService.activePlayer && MprisService.activePlayer.length > 0 && MprisService.activePlayer.canSeek)
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor
                            hoverEnabled: true

                            onClicked: (mouse) => {
                                if (MprisService.activePlayer && MprisService.activePlayer.length > 0 && MprisService.activePlayer.canSeek) {
                                    var ratio = mouse.x / width;
                                    var targetPos = ratio * MprisService.activePlayer.length;
                                    MprisService.activePlayer.position = targetPos;
                                    positionTimer.localPosition = targetPos;
                                }
                            }
                        }
                    }

                    // Position duration labels
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: formatTime(currentPosition)
                            font { family: "Google Sans"; pixelSize: 11 }
                            color: Theme.colorOnSurfaceVariant
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: MprisService.activePlayer ? formatTime(MprisService.activePlayer.length) : "0:00"
                            font { family: "Google Sans"; pixelSize: 11 }
                            color: Theme.colorOnSurfaceVariant
                        }
                    }
                }

                // Controls row: Loop | Previous | Play/Pause | Next | Shuffle
                RowLayout {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    Layout.alignment: Qt.AlignHCenter

                    Item { Layout.fillWidth: true }

                    // Loop Toggle
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: loopMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        visible: MprisService.activePlayer ? MprisService.activePlayer.loopSupported : false

                        Image {
                            id: loopIcon
                            anchors.centerIn: parent
                            width: 18; height: 18
                            source: "assets/icons/restart-alt.svg"
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: loopIcon
                            source: loopIcon
                            color: (MprisService.activePlayer && MprisService.activePlayer.loopState !== MprisLoopState.None)
                                ? Theme.primary
                                : Theme.colorOnSurfaceVariant
                        }

                        MouseArea {
                            id: loopMa; anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: {
                                if (MprisService.activePlayer) {
                                    var cur = MprisService.activePlayer.loopState;
                                    if (cur === MprisLoopState.None) {
                                        MprisService.setLoopState(MprisLoopState.Track);
                                    } else if (cur === MprisLoopState.Track) {
                                        MprisService.setLoopState(MprisLoopState.Playlist);
                                    } else {
                                        MprisService.setLoopState(MprisLoopState.None);
                                    }
                                }
                            }
                        }
                    }

                    Item { implicitWidth: 10 }

                    // Skip Previous
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        visible: MprisService.activePlayer ? MprisService.activePlayer.canGoPrevious : false

                        Image {
                            id: prevIcon
                            anchors.centerIn: parent
                            width: 22; height: 22
                            source: "assets/icons/skip-previous.svg"
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: prevIcon
                            source: prevIcon
                            color: Theme.colorOnSurface
                        }

                        MouseArea {
                            id: prevMa; anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: MprisService.previous()
                        }
                    }

                    Item { implicitWidth: 10 }

                    // Play / Pause Circle Button
                    Rectangle {
                        width: 48; height: 48; radius: 24
                        color: Theme.primary
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1

                        Image {
                            id: playIcon
                            anchors.centerIn: parent
                            width: 24; height: 24
                            source: (MprisService.activePlayer && MprisService.activePlayer.isPlaying)
                                ? "assets/icons/pause.svg"
                                : "assets/icons/play-arrow.svg"
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: playIcon
                            source: playIcon
                            color: Theme.colorOnPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MprisService.togglePlaying()
                        }
                    }

                    Item { implicitWidth: 10 }

                    // Skip Next
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        visible: MprisService.activePlayer ? MprisService.activePlayer.canGoNext : false

                        Image {
                            id: nextIcon
                            anchors.centerIn: parent
                            width: 22; height: 22
                            source: "assets/icons/skip-next.svg"
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: nextIcon
                            source: nextIcon
                            color: Theme.colorOnSurface
                        }

                        MouseArea {
                            id: nextMa; anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: MprisService.next()
                        }
                    }

                    Item { implicitWidth: 10 }

                    // Shuffle Toggle
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: shufMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        visible: MprisService.activePlayer ? MprisService.activePlayer.shuffleSupported : false

                        Image {
                            id: shufIcon
                            anchors.centerIn: parent
                            width: 18; height: 18
                            source: "assets/icons/swap-horiz.svg"
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: shufIcon
                            source: shufIcon
                            color: (MprisService.activePlayer && MprisService.activePlayer.shuffle)
                                ? Theme.primary
                                : Theme.colorOnSurfaceVariant
                        }

                        MouseArea {
                            id: shufMa; anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: {
                                if (MprisService.activePlayer) {
                                    MprisService.setShuffle(!MprisService.activePlayer.shuffle);
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
