// AppButton.qml — кнопка приложения с настоящей иконкой из системной темы
// iconName — freedesktop icon name (e.g. "firefox", "org.telegram.desktop")
// appCmd   — command to launch
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "Theme"

Item {
    id: root
    property string iconName: "application-x-executable"
    property string appName:  "App"
    property string appCmd:   ""

    implicitWidth:  46
    implicitHeight: 46

    // backrgound when touch/aimed
    Rectangle {
        id: bg
        anchors.centerIn: parent
        width:  40
        height: 40
        radius: 12

        color: mouseArea.containsPress
               ? Qt.rgba(1, 1, 1, 0.15)
               : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")



        // icons from system theme
        Image {
            id: icon
            anchors.centerIn: parent
            width:  26
            height: 26

            // Qt automaticly find icon in current icon theme (hicolor / papirus / etc.)
            source: "image://icon/" + root.iconName

            smooth:       true
            antialiasing: true
            mipmap:       true
            fillMode:     Image.PreserveAspectFit




        }

        // dot "app launched"
        Rectangle {
            id: runDot
            anchors {
                bottom:           parent.bottom
                bottomMargin:     -5
                horizontalCenter: parent.horizontalCenter
            }
            width:  4
            height: 4
            radius: 2
            color:  Theme.primary
            visible: false   // включи через свойство root.running если нужно
        }
    }

    // tooltip thing
    Rectangle {
        id: tooltip
        anchors {
            bottom:           bg.top
            bottomMargin:     7
            horizontalCenter: parent.horizontalCenter
        }
        width:  tooltipText.implicitWidth + 18
        height: 22
        radius: 7

        color:  Qt.rgba(0.04, 0.06, 0.12, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.09)
        border.width: 1

        opacity: mouseArea.containsMouse ? 1.0 : 0.0


        // Не перекрываем соседние элементы
        z: 10

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text:    root.appName
            color:   Qt.rgba(1, 1, 1, 0.82)
            font {
                pixelSize: 11
                family:    "Google Sans"
                weight:    Font.Medium
            }
        }
    }

    // mouse
    MouseArea {
        id:           mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor

        onClicked: {
            if (root.appCmd !== "")
                Hyprland.dispatch("exec [float] " + root.appCmd)
        }
    }
}
