// WorkspaceButton.qml — кнопка воркспейса
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "Theme"

Item {
    id: root
    property int wsId: 1

    // Определяем состояние воркспейса
    property var hyprWs: {
        var found = null
        for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
            if (Hyprland.workspaces.values[i].id === wsId) {
                found = Hyprland.workspaces.values[i]
                break
            }
        }
        return found
    }
    property bool isFocused: hyprWs !== null && Hyprland.focusedWorkspace !== null &&
                             Hyprland.focusedWorkspace.id === wsId
    property bool hasWindows: hyprWs !== null && hyprWs.windowCount > 0

    implicitWidth:  30
    implicitHeight: 30

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width:  isFocused ? 28 : (hasWindows ? 22 : 16)
        height: width
        radius: width / 2

        color: isFocused
               ? Theme.primary
               : (hasWindows ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08))

        border.color: isFocused ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Behavior on width  { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on color  { ColorAnimation  { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text:  root.wsId
            color: root.isFocused ? "white" : Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: root.isFocused ? 11 : 9
            font.bold: root.isFocused
            visible: root.isFocused || root.hasWindows

            Behavior on font.pixelSize { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor

        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + root.wsId + " })")

        onEntered: bg.scale = 1.15
        onExited:  bg.scale = 1.0
    }

    Behavior on implicitWidth { NumberAnimation { duration: 150 } }
}
