// NotificationsPopup.qml — top-right notification stream (ChromeOS / Material You)
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "services"

PanelWindow {
    id: root
    property var screenRef
    screen: screenRef

    anchors { top: true; right: true }
    margins { top: 12; right: 12 }

    implicitWidth: 400
    implicitHeight: Math.min(Math.max(notifList.contentHeight + 4, 80), 720)
    visible: notifList.count > 0

    WlrLayershell.layer:     WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    color: "transparent"

    ListView {
        id: notifList
        anchors.fill: parent
        spacing: 8
        clip: true
        interactive: true
        verticalLayoutDirection: ListView.TopToBottom
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: 520
        flickDeceleration: 8500
        maximumFlickVelocity: 4200

        model: NotificationService.popupNotifications

        delegate: NotificationCard {
            width: notifList.width
            notification: modelData
            isPopup: true
            showActions: true
            showDismiss: true
        }

        // fade + slide-in for new items
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y";       from: -16; duration: 260; easing.type: Easing.OutCubic }
            }
        }

        // shift remaining items smoothly when one is removed
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
        }

        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 180 }
        }
    }
}
