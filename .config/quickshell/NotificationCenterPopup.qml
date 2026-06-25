// NotificationCenterPopup.qml — ChromeOS Material You notification center
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "Theme"
import "services"

PanelWindow {
    id: root
    property var screenRef
    property bool isOpen: false

    readonly property var history: NotificationService.history
    readonly property var groupedHistory: NotificationService.groupedHistory

    screen: screenRef
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notif-center"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    property bool _animVisible: false
    visible: _animVisible

    Timer {
        id: closeTimer
        interval: 260
        repeat: false
        onTriggered: root._animVisible = false
    }

    // dismiss area (click anywhere outside the panel closes it)
    MouseArea {
        anchors.fill: parent
        visible: root.isOpen
        z: 0
        onClicked: root.isOpen = false
    }

    // keyboard dismiss: escape closes
    Item {
        id: focusGrabber
        anchors.fill: parent
        focus: root.isOpen
        Keys.onEscapePressed: root.isOpen = false
    }

    onIsOpenChanged: {
        if (isOpen) {
            _animVisible = true
            focusGrabber.forceActiveFocus()
            NotificationService.markAllRead()
        } else {
            closeTimer.start()
        }
    }

    // main popup container
    Rectangle {
        id: bgRect
        z: 10
        anchors {
            bottom: parent.bottom; right: parent.right
            bottomMargin: 64; rightMargin: 16
        }
        width: 380
        height: Math.min(620, headerSection.height + contentArea.implicitHeight + 24)
        color: Qt.rgba(0.18, 0.18, 0.22, 0.95)
        radius: 16
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        clip: true

        // Block click-through
        MouseArea { anchors.fill: parent; onClicked: {} }

        scale: root.isOpen ? 1.0 : 0.95
        opacity: root.isOpen ? 1.0 : 0.0
        transformOrigin: Item.BottomRight

        transform: Translate {
            y: root.isOpen ? 0 : 24
            Behavior on y {
                NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
            }
        }

        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        // header
        Item {
            id: headerSection
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 12; leftMargin: 16; rightMargin: 16
            }
            height: 40

            Text {
                id: titleText
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Notifications"
                color: Qt.rgba(1, 1, 1, 0.92)
                font { family: "Google Sans"; pixelSize: 15; weight: Font.Medium }
            }

            // clear all button
            Rectangle {
                id: clearBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 12 + 14 + 6 + clearLbl.implicitWidth + 12 // leftMargin + icon + spacing + text + rightMargin
                height: 28
                radius: 14
                color: clearArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                Behavior on color { ColorAnimation { duration: 120 } }
                visible: root.history.length > 0

                Item {
                    id: clearIconContainer
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 14; height: 14

                    Image {
                        id: clearIcon
                        anchors.fill: parent
                        sourceSize: Qt.size(14, 14)
                        source: "assets/icons/clear-all.svg"
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: parent
                        source: clearIcon
                        color: Theme.colorOnSurfaceVariant
                    }
                }

                Text {
                    id: clearLbl
                    anchors { left: clearIconContainer.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    text: "Clear all"
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearAll()
                }
            }
        }

        // content (list or empty state)
        Item {
            id: contentArea
            anchors {
                top: headerSection.bottom; topMargin: 8
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 12; rightMargin: 12; bottomMargin: 12
            }
            implicitHeight: root.groupedHistory.length === 0
                ? 80
                : Math.min(540, notifList.contentHeight + 4)

            // empty state
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: root.groupedHistory.length === 0

                Item {
                    width: 32; height: 32
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                        id: emptyIcon
                        anchors.fill: parent
                        sourceSize: Qt.size(32, 32)
                        source: "assets/icons/notifications-off.svg"
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: emptyIcon
                        source: emptyIcon
                        color: Qt.rgba(1, 1, 1, 0.3)
                        visible: root.groupedHistory.length === 0
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No notifications"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font { family: "Google Sans"; pixelSize: 13 }
                }
            }

            ListView {
                id: notifList
                anchors.fill: parent
                model: root.groupedHistory
                spacing: 8
                clip: true
                visible: root.groupedHistory.length > 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: NotificationGroupCard {
                    width: notifList.width
                    group: modelData
                }
            }
        }
    }
}
