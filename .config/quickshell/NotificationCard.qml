// NotificationCard.qml — ChromeOS / Material You notification card
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "Theme"
import "services"

Rectangle {
    id: card

    property var    notification: null
    property bool   isPopup: false
    property bool   showActions: false
    property bool   showDismiss: false
    property string appName:      notification ? (notification.appName  || "Notification") : "Notification"
    property string summary:      notification ? (notification.summary  || "")             : ""
    property string bodyText:     notification ? (notification.body     || "")             : ""
    property string appIcon:      notification ? (notification.appIcon  || "")             : ""
    property string imagePath:    notification ? (notification.image    || "")             : ""
    property var    notifTime:    notification ? notification.time : new Date()
    property var    actions:      notification ? (notification.actions || []) : []
    property bool expanded: false

    readonly property color cBg:        Theme.notificationCardBg
    readonly property color cBgHover:   Theme.notificationHover
    readonly property color cIconBg:    Theme.notificationIconBg
    readonly property color cTextDim:   Theme.colorOnSurfaceVariant
    readonly property color cTextBody:  Theme.colorOnSurface
    readonly property color cTextTitle: Theme.colorOnSurface
    readonly property bool hasImage: imagePath.length > 0
    readonly property bool hasExpandableContent: bodyText.length > 0 || hasImage || (showActions && actions.length > 0)

    implicitHeight: cardLayout.implicitHeight + 28
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    radius: 20
    color: cBg
    border.color: Theme.notificationBorder
    border.width: 1
    clip: true

    opacity: 0
    transform: Translate { id: slideIn; y: -12 }
    Component.onCompleted: {
        opacity = 1
        slideIn.y = 0
        if (isPopup)
            dismissTimer.start()
    }
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Timer {
        id: dismissTimer
        interval: 5500
        repeat: false
        onTriggered: {
            if (card.notification)
                NotificationService.timeoutNotification(card.notification.id)
        }
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hovered) {
                dismissTimer.stop()
            } else if (isPopup) {
                dismissTimer.interval = 2500
                dismissTimer.restart()
            }
        }
    }

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                radius: 9
                color: card.cIconBg
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: {
                        if (!card.appIcon)
                            return ""
                        if (card.appIcon.indexOf("/") === 0 || card.appIcon.indexOf("file://") === 0 || card.appIcon.indexOf("image://") === 0)
                            return card.appIcon
                        return "image://icon/" + card.appIcon
                    }
                    sourceSize.width:  32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source.toString().length > 0 && status === Image.Ready
                }
            }

            Text {
                text: card.appName
                color: card.cTextDim
                font { pixelSize: 12; family: "Google Sans"; weight: Font.Medium }
                elide: Text.ElideRight
                Layout.maximumWidth: 160
            }

            Text { text: "•"; color: card.cTextDim; font.pixelSize: 12 }

            Text {
                text: card._formatTime(card.notifTime)
                color: card.cTextDim
                font { pixelSize: 12; family: "Google Sans" }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: chevArea.containsMouse ? card.cBgHover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                visible: card.hasExpandableContent

                Image {
                    id: chevIcon
                    anchors.centerIn: parent
                    width: 14; height: 14
                    sourceSize: Qt.size(14, 14)
                    source: "assets/icons/expand-less.svg"
                    smooth: true
                    visible: false
                    rotation: card.expanded ? 0 : 180
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                ColorOverlay {
                    anchors.fill: chevIcon
                    source: chevIcon
                    color: card.cTextDim
                    rotation: card.expanded ? 0 : 180
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: chevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.expanded = !card.expanded
                }
            }

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: dismissArea.containsMouse ? card.cBgHover : "transparent"
                visible: showDismiss

                Image {
                    id: dismissIcon
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    sourceSize: Qt.size(12, 12)
                    source: "assets/icons/close.svg"
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: dismissIcon
                    source: dismissIcon
                    color: card.cTextDim
                }

                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.notification)
                            NotificationService.removeNotification(card.notification.id)
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: card.summary
                color: card.cTextTitle
                font { pixelSize: 14; family: "Google Sans"; weight: Font.Bold }
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                visible: text.length > 0
            }

            Text {
                Layout.fillWidth: true
                text: card.bodyText
                color: card.cTextBody
                font { pixelSize: 13; family: "Google Sans" }
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                visible: card.expanded && text.length > 0
                opacity: card.expanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                Layout.topMargin: 8
                radius: 14
                color: Theme.notificationIconBg
                clip: true
                visible: card.expanded && card.hasImage
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Image {
                    anchors.fill: parent
                    source: card._imageSource(card.imagePath)
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: card.expanded && showActions && actions.length > 0

                Repeater {
                    model: actions

                    delegate: Rectangle {
                        required property var modelData
                        Layout.topMargin: 6
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: Math.min(160, actionLabel.implicitWidth + 24)
                        radius: 15
                        color: actionArea.containsMouse
                            ? Theme.notificationPressed
                            : Theme.notificationHover
                        opacity: notification && notification.live ? 1.0 : 0.5

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.colorOnSurface
                            font { pixelSize: 12; family: "Google Sans"; weight: Font.Medium }
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: notification && notification.live
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: NotificationService.invokeAction(notification.id, modelData.identifier)
                        }
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
        if (diffSec < 3600)  return Math.floor(diffSec / 60)   + "m"
        if (diffSec < 86400) return Math.floor(diffSec / 3600) + "h"
        return Qt.formatDateTime(when, "HH:mm")
    }

    function _imageSource(path) {
        if (!path)
            return ""
        if (path.indexOf("image://qsimage/") === 0 && (!card.notification || !card.notification.live))
            return ""
        if (path.indexOf("/") === 0)
            return "file://" + path
        return path
    }
}
