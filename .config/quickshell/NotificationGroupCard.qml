// NotificationGroupCard.qml - grouped ChromeOS-style notification section
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "Theme"
import "services"

Rectangle {
    id: groupCard

    property var group: null
    property bool expanded: false
    property bool scrolling: false

    readonly property var notifications: group ? (group.notifications || []) : []
    readonly property string appName: group ? (group.appName || "Notification") : "Notification"
    readonly property string appIcon: group ? (group.appIcon || "") : ""
    readonly property int count: notifications.length
    readonly property var visibleNotifications: expanded ? notifications : notifications.slice(0, 1)

    implicitHeight: content.implicitHeight + 24
    radius: 20
    color: Theme.notificationGroupBg
    border.color: Theme.notificationBorder
    border.width: 1

    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                color: Theme.notificationIconBg
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: groupCard._iconSource(groupCard.appIcon)
                    sourceSize: Qt.size(36, 36)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source.toString().length > 0 && status === Image.Ready
                }
            }

            Text {
                Layout.fillWidth: true
                text: groupCard.appName
                color: Theme.colorOnSurface
                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: countLabel.implicitWidth + 14
                Layout.preferredHeight: 22
                radius: 11
                color: Theme.notificationHover
                visible: groupCard.count > 1

                Text {
                    id: countLabel
                    anchors.centerIn: parent
                    text: groupCard.count
                    color: Theme.colorOnSurface
                    font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                }
            }

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 13
                color: (!groupCard.scrolling && expandArea.containsMouse) ? Theme.notificationHover : "transparent"
                visible: groupCard.count > 1

                Image {
                    id: expandIcon
                    anchors.centerIn: parent
                    width: 16; height: 16
                    sourceSize: Qt.size(16, 16)
                    source: "assets/icons/expand-less.svg"
                    visible: false
                    rotation: groupCard.expanded ? 0 : 180
                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
                ColorOverlay {
                    anchors.fill: expandIcon
                    source: expandIcon
                    color: Theme.colorOnSurfaceVariant
                    rotation: expandIcon.rotation
                }

                MouseArea {
                    id: expandArea
                    anchors.fill: parent
                    hoverEnabled: !groupCard.scrolling
                    cursorShape: Qt.PointingHandCursor
                    onClicked: groupCard.expanded = !groupCard.expanded
                }
            }

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 13
                color: (!groupCard.scrolling && dismissArea.containsMouse) ? Theme.notificationHover : "transparent"

                Image {
                    id: dismissIcon
                    anchors.centerIn: parent
                    width: 13; height: 13
                    sourceSize: Qt.size(13, 13)
                    source: "assets/icons/close.svg"
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: dismissIcon
                    source: dismissIcon
                    color: Theme.colorOnSurfaceVariant
                }

                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    hoverEnabled: !groupCard.scrolling
                    cursorShape: Qt.PointingHandCursor
                    onClicked: groupCard.dismissGroup()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: groupCard.visibleNotifications

                delegate: NotificationCard {
                    required property var modelData
                    Layout.fillWidth: true
                    notification: modelData
                    isPopup: false
                    showActions: true
                    showDismiss: true
                    scrolling: groupCard.scrolling
                }
            }
        }
    }

    function dismissGroup() {
        var ids = []
        for (var i = 0; i < notifications.length; i++)
            ids.push(notifications[i].id)
        NotificationService.removeNotifications(ids)
    }

    function _iconSource(icon) {
        if (!icon)
            return ""
        if (icon.indexOf("/") === 0 || icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0)
            return icon
        return "image://icon/" + icon
    }
}
