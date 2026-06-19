// ClockWidget.qml — time + date
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    implicitWidth:  clockCol.implicitWidth + 16
    implicitHeight: 44

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    ColumnLayout {
        id: clockCol
        anchors.centerIn: parent
        spacing: 1

        Text {
            Layout.alignment: Qt.AlignHCenter
            text:  Qt.formatDateTime(clock.date, "hh:mm")
            color: Qt.rgba(1, 1, 1, 0.92)
            font.pixelSize: 14
            font.family:    "Google Sans"
            font.weight:    Font.Medium
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text:  Qt.formatDateTime(clock.date, "ddd, d MMM")
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 9
            font.family:    "Google Sans"
        }
    }
}
