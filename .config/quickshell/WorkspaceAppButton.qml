// WorkspaceAppButton.qml
// Чисто динамический воркспейс:
//   пусто → точка
//   открыто окно → иконка этого окна (из class)

import Quickshell
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import QtQuick
import "Theme"

Item {
    id: root

    property int wsId: 1
    property var clientsByWs: ({})
    property var clientIconsByWs: ({})
    property bool dockIconFillEnabled: false
    property color dockIconFillColor: Theme.secondary

    readonly property bool   isFocused:   Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace !== undefined && Hyprland.focusedWorkspace.id === wsId
    readonly property string windowClass: (clientsByWs && clientsByWs[wsId]) ? clientsByWs[wsId] : ""
    readonly property string iconPath:    (clientIconsByWs && clientIconsByWs[wsId]) ? clientIconsByWs[wsId] : ""
    readonly property bool   hasWindows:  windowClass !== ""
    readonly property bool   hasResolvedIcon: iconPath.length > 0

    implicitWidth:  50
    implicitHeight: 50

    // ── ПУСТО: точка ─────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        visible: !root.hasWindows
        width:  root.isFocused ? 10 : 6
        height: width
        radius: width / 2
        color:  root.isFocused
                ? Theme.primary
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.38)
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation  { duration: 180 } }
    }

    // ── ЕСТЬ ОКНО: иконка ────────────────────────────────────────────────
    Item {
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        visible: root.hasWindows

        Rectangle {
            anchors.centerIn: parent
            width:  mouse.containsMouse ? 38 : 36
            height: width
            radius: width / 2
            color: "transparent"
            border.color: "transparent"
            border.width: 0
            Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color  { ColorAnimation  { duration: 160 } }
        }

        Image {
            id: iconImg
            anchors.centerIn: parent
            width:  root.isFocused ? 29 : 27
            height: width

            source: root.hasResolvedIcon ? ("file://" + root.iconPath) : "assets/icons/apps.svg"

            smooth: true; mipmap: true
            cache: false
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            visible: !root.dockIconFillEnabled
            opacity: root.isFocused ? 1.0 : 0.88
            scale:   mouse.containsMouse ? 1.08 : 1.0
            Behavior on width   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        ColorOverlay {
            id: iconTintSource
            anchors.centerIn: iconImg
            width:  iconImg.width
            height: iconImg.height
            source: iconImg
            color: root.dockIconFillColor
            visible: false
        }

        Blend {
            anchors.centerIn: iconImg
            width:  iconImg.width
            height: iconImg.height
            source: iconImg
            foregroundSource: iconTintSource
            mode: "color"
            opacity: root.dockIconFillEnabled ? (root.isFocused ? 1.0 : 0.84) : 0.0
            visible: opacity > 0.0
            scale: iconImg.scale
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Rectangle {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 1
            }
            width: root.isFocused ? 18 : 0
            height: 3
            radius: 2
            color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.96)
            opacity: root.isFocused ? 1.0 : 0.0
            z: 5
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    // ── Тултип ───────────────────────────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.top; bottomMargin: 6; horizontalCenter: parent.horizontalCenter }
        width:  ttLabel.implicitWidth + 18; height: 22; radius: 7
        color:  Qt.rgba(0.04, 0.06, 0.14, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.09); border.width: 1
        opacity: mouse.containsMouse ? 1.0 : 0.0; z: 20
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Text {
            id: ttLabel; anchors.centerIn: parent
            text:  root.hasWindows ? root.windowClass : ("Workspace " + root.wsId)
            color: Qt.rgba(1, 1, 1, 0.82)
            font { pixelSize: 11; family: "Google Sans"; weight: Font.Medium }
        }
    }

    // ── Мышь ─────────────────────────────────────────────────────────────
    MouseArea {
        id: mouse; anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + root.wsId + " })")
    }
}
