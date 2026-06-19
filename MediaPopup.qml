import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "Theme"

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

    // keep window alive during close animation
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

    // dismiss area
    MouseArea {
        anchors.fill: parent
        visible: mediaPopup.isOpen
        z: 0
        onClicked: mediaPopup.isOpen = false
    }

    // main popup container
    Rectangle {
        id: bgRect
        z: 10
        anchors { bottom: parent.bottom; right: parent.right; bottomMargin: 64; rightMargin: 16 }

        // Stop clicks from falling through to the dismiss area
        MouseArea { anchors.fill: parent; onClicked: {} }

        width: 360
        // Height is driven by the inner Column → never drifts from content
        height: contentCol.implicitHeight + contentCol.anchors.topMargin + contentCol.anchors.bottomMargin
        color: Theme.surfaceVariant
        radius: 16
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

        Column {
            id: contentCol
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 12; leftMargin: 16; rightMargin: 16; bottomMargin: 16
            }
            spacing: 12

            // header
            Item {
                id: header
                width: parent.width
                height: 36

                Text {
                    anchors.centerIn: parent
                    text: "Media controls"
                    color: Theme.colorOnSurface
                    font { family: "Google Sans"; pixelSize: 15; weight: Font.Medium }
                }
            }

            // empty state
            Item {
                width: parent.width
                height: 60
                visible: Mpris.players.count === 0

                Text {
                    anchors.centerIn: parent
                    text: "No media playing"
                    color: Theme.colorOnSurfaceVariant
                    font { family: "Google Sans"; pixelSize: 13 }
                }
            }

            // players
            Repeater {
                model: Mpris.players

                delegate: Rectangle {
                    id: playerCard
                    property var player: modelData

                    width: contentCol.width
                    height: 132
                    color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06)
                    radius: 16

                    // top row: art + info + play
                    Item {
                        id: topRow
                        anchors {
                            top: parent.top; left: parent.left; right: parent.right
                            topMargin: 12; leftMargin: 12; rightMargin: 12
                        }
                        height: 72

                        // album art
                        Rectangle {
                            id: artBg
                            width: 72; height: 72; radius: 10
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.08)
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: playerCard.player.trackArtUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                visible: playerCard.player.trackArtUrl !== ""
                                mipmap: true
                                asynchronous: true
                            }

                            Image {
                                id: noteIcon
                                anchors.centerIn: parent
                                width: 28; height: 28
                                source: "assets/icons/music-note.svg"
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: noteIcon
                                source: noteIcon
                                color: Theme.colorOnSurfaceVariant
                                opacity: 0.5
                                visible: playerCard.player.trackArtUrl === ""
                            }
                        }

                        // play / Pause
                        Rectangle {
                            id: playBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 44; height: 44; radius: 22
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)

                            Image {
                                id: playIcon
                                anchors.centerIn: parent
                                width: 22; height: 22
                                source: playerCard.player.isPlaying ? "assets/icons/pause.svg" : "assets/icons/play-arrow.svg"
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: playIcon
                                source: playIcon
                                color: Theme.colorOnSurfaceVariant
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: playerCard.player.togglePlaying()
                            }
                        }

                        // track info — anchored between art and play button
                        Column {
                            anchors {
                                left: artBg.right; leftMargin: 12
                                right: playBtn.left; rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            Text {
                                width: parent.width
                                text: playerCard.player.identity || "Unknown App"
                                color: Theme.colorOnSurfaceVariant
                                font { family: "Google Sans"; pixelSize: 11 }
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: playerCard.player.trackTitle || "No Track"
                                color: Theme.colorOnSurface
                                font { family: "Google Sans"; pixelSize: 14; weight: Font.Medium }
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: playerCard.player.trackArtist || ""
                                color: Theme.colorOnSurfaceVariant
                                font { family: "Google Sans"; pixelSize: 12 }
                                elide: Text.ElideRight
                                visible: text !== ""
                            }
                        }
                    }

                    // bottom row: prev + slider + next
                    Item {
                        id: bottomRow
                        anchors {
                            left: parent.left; right: parent.right; bottom: parent.bottom
                            leftMargin: 12; rightMargin: 12; bottomMargin: 12
                        }
                        height: 24

                        // prev
                        Item {
                            id: prevBtn
                            width: 24; height: 24
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            Image {
                                id: prevIcon
                                anchors.centerIn: parent
                                width: 20; height: 20
                                source: "assets/icons/skip-previous.svg"
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: prevIcon
                                source: prevIcon
                                color: Theme.colorOnSurfaceVariant
                                opacity: prevArea.pressed ? 0.5 : 0.85
                            }
                            MouseArea {
                                id: prevArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: playerCard.player.previous()
                            }
                        }

                        // slider
                        Item {
                            id: sliderArea
                            anchors {
                                left: prevBtn.right; leftMargin: 10
                                right: nextBtn.left; rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            height: 24

                            Rectangle {
                                id: trackBg
                                width: parent.width; height: 4; radius: 2
                                anchors.centerIn: parent
                                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.18)

                                Rectangle {
                                    id: trackFill
                                    height: parent.height; radius: 2
                                    width: playerCard.player.length > 0
                                        ? Math.max(0, Math.min(parent.width,
                                            parent.width * (playerCard.player.position / playerCard.player.length)))
                                        : 0
                                    color: Theme.primary

                                    Rectangle {
                                        width: 12; height: 12; radius: 6
                                        anchors { verticalCenter: parent.verticalCenter; horizontalCenter: parent.right }
                                        color: Theme.colorOnPrimary
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (playerCard.player.length > 0) {
                                        let ratio = mouse.x / width
                                        playerCard.player.seek(ratio * playerCard.player.length - playerCard.player.position)
                                    }
                                }
                            }
                        }

                        // next
                        Item {
                            id: nextBtn
                            width: 24; height: 24
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            Image {
                                id: nextIcon
                                anchors.centerIn: parent
                                width: 20; height: 20
                                source: "assets/icons/skip-next.svg"
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: nextIcon
                                source: nextIcon
                                color: Theme.colorOnSurfaceVariant
                                opacity: nextArea.pressed ? 0.5 : 0.85
                            }
                            MouseArea {
                                id: nextArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: playerCard.player.next()
                            }
                        }
                    }
                }
            }
        }
    }
}
