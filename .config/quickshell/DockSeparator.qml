// DockSeparator.qml — vertical diveder
import QtQuick

Item {
    implicitWidth:  16
    implicitHeight: 44

    Rectangle {
        anchors.centerIn: parent
        width:  1
        height: 24
        color:  Qt.rgba(1, 1, 1, 0.10)
        radius: 1
    }
}
