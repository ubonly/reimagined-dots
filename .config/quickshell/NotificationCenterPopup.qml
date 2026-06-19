// NotificationCenterPopup.qml — ChromeOS Material You notification center
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "Theme"

PanelWindow {
    id: root
    property var screenRef
    property bool isOpen: false

    // Plain-JS history of notifications: [{ id, appName, summary, body, appIcon, time }]
    property var history: []

    function pushNotification(notif) {
        var copy = {
            id: notif.id,
            appName: notif.appName || "Notification",
            summary: notif.summary || "",
            body: notif.body || "",
            appIcon: notif.appIcon || "",
            time: notif.time ? notif.time : new Date()
        }
        var list = history.slice()
        list.unshift(copy)
        if (list.length > 50) list = list.slice(0, 50)
        history = list
    }

    function removeAt(idx) {
        var list = history.slice()
        list.splice(idx, 1)
        history = list
    }

    function clearAll() {
        history = []
    }

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
                    onClicked: root.clearAll()
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
            implicitHeight: root.history.length === 0
                ? 80
                : Math.min(540, notifList.contentHeight + 4)

            // empty state
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: root.history.length === 0

                Image {
                    id: emptyIcon
                    width: 32; height: 32
                    sourceSize: Qt.size(32, 32)
                    source: "assets/icons/notifications-off.svg"
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: emptyIcon
                    source: emptyIcon
                    color: Qt.rgba(1, 1, 1, 0.3)
                    visible: root.history.length === 0
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
                model: root.history
                spacing: 6
                clip: true
                visible: root.history.length > 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: notifItem
                    property var notif: root.history[index]

                    width: notifList.width
                    height: textCol.implicitHeight + 22
                    radius: 12
                    color: itemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // app icon
                    Rectangle {
                        id: appIconBg
                        anchors { left: parent.left; leftMargin: 10; top: parent.top; topMargin: 11 }
                        width: 24; height: 24; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.10)
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: {
                                if (!notifItem.notif) return "";
                                var icon = notifItem.notif.appIcon;
                                if (!icon) return "";
                                if (icon.indexOf("/") === 0 || icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0) {
                                    return icon;
                                }
                                return "image://icon/" + icon;
                            }
                            sourceSize.width: 32; sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: source.toString().length > 0 && status === Image.Ready
                        }
                    }

                    // close (x) button
                    Rectangle {
                        id: closeBtn
                        anchors { right: parent.right; rightMargin: 8; top: parent.top; topMargin: 8 }
                        width: 22; height: 22; radius: 11
                        color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Image {
                            id: closeIcon
                            anchors.centerIn: parent
                            width: 12; height: 12
                            sourceSize: Qt.size(12, 12)
                            source: "assets/icons/close.svg"
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: closeIcon
                            source: closeIcon
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeAt(index)
                        }
                    }

                    // text column
                    Column {
                        id: textCol
                        anchors {
                            left: appIconBg.right; leftMargin: 10
                            right: closeBtn.left; rightMargin: 6
                            top: parent.top; topMargin: 10
                        }
                        spacing: 2

                        Row {
                            spacing: 6
                            Text {
                                text: notifItem.notif ? notifItem.notif.appName : ""
                                color: Qt.rgba(1, 1, 1, 0.55)
                                font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "•"
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font.pixelSize: 11
                            }
                            Text {
                                text: notifItem.notif ? root._formatTime(notifItem.notif.time) : ""
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font { family: "Google Sans"; pixelSize: 11 }
                            }
                        }

                        Text {
                            width: parent.width
                            text: notifItem.notif ? notifItem.notif.summary : ""
                            color: Qt.rgba(1, 1, 1, 0.95)
                            font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }

                        Text {
                            width: parent.width
                            text: notifItem.notif ? notifItem.notif.body : ""
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font { family: "Google Sans"; pixelSize: 12 }
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            visible: text.length > 0
                        }
                    }

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                    }
                }
            }
        }
    }

    function _formatTime(t) {
        if (!t) return "now"
        var when = (t instanceof Date) ? t : new Date(t)
        var now = new Date()
        var diffSec = Math.floor((now.getTime() - when.getTime()) / 1000)
        if (diffSec < 60)    return "now"
        if (diffSec < 3600)  return Math.floor(diffSec / 60) + "m"
        if (diffSec < 86400) return Math.floor(diffSec / 3600) + "h"
        return Qt.formatDateTime(when, "HH:mm")
    }
}
