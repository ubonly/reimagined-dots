// CalendarPopup.qml - ChromeOS-style calendar bubble
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "Theme"

PanelWindow {
    id: root

    property var screenRef
    property bool isOpen: false
    property date today: new Date()
    property date selectedDate: new Date(today.getFullYear(), today.getMonth(), today.getDate())
    property int monthOffset: 0

    screen: screenRef
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-calendar"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    property bool _animVisible: false
    visible: _animVisible

    Timer {
        id: closeTimer
        interval: 220
        repeat: false
        onTriggered: root._animVisible = false
    }

    MouseArea {
        anchors.fill: parent
        visible: root.isOpen
        z: 0
        onClicked: root.isOpen = false
    }

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
            today = new Date()
            selectedDate = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        } else {
            closeTimer.start()
        }
    }

    Rectangle {
        id: panel
        z: 10
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 16
            bottomMargin: 64
        }
        width: 400
        height: Math.min(560, content.implicitHeight + 28)
        radius: 22
        color: Theme.notificationCenterBg
        border.color: Theme.notificationBorder
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        scale: root.isOpen ? 1.0 : 0.96
        opacity: root.isOpen ? 1.0 : 0.0
        transformOrigin: Item.BottomRight

        transform: Translate {
            y: root.isOpen ? 0 : 22
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: tasksColumn.implicitHeight + 26
                radius: 20
                color: Theme.notificationGroupBg
                border.color: Theme.notificationBorder
                border.width: 1

                ColumnLayout {
                    id: tasksColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "✓"
                            color: Theme.colorOnSurface
                            font { family: "Google Sans"; pixelSize: 18; weight: Font.Medium }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Мои задачи"
                            color: Theme.colorOnSurface
                            font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "⌄"
                            color: Theme.colorOnSurfaceVariant
                            font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "⊕"
                            color: Theme.primary
                            font { family: "Google Sans"; pixelSize: 18 }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Add a task"
                            color: Theme.primary
                            font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            radius: 8
                            color: "transparent"
                            border.color: Theme.primary
                            border.width: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Нет задач на выбранный день"
                            color: Theme.colorOnSurface
                            opacity: 0.86
                            font { family: "Google Sans"; pixelSize: 13 }
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: calendarColumn.implicitHeight + 26
                radius: 20
                color: Theme.notificationGroupBg
                border.color: Theme.notificationBorder
                border.width: 1

                ColumnLayout {
                    id: calendarColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: root.monthTitle(root.monthOffset)
                            color: Theme.colorOnSurface
                            font { family: "Google Sans"; pixelSize: 18; weight: Font.Medium }
                            elide: Text.ElideRight
                        }

                        CalendarIconButton {
                            label: "▣"
                            onClicked: root.monthOffset = 0
                        }

                        CalendarIconButton {
                            label: "⌃"
                            onClicked: root.monthOffset--
                        }

                        CalendarIconButton {
                            label: "⌄"
                            onClicked: root.monthOffset++
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["S", "M", "T", "W", "T", "F", "S"]
                            Text {
                                required property string modelData
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Theme.colorOnSurface
                                opacity: 0.78
                                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        rowSpacing: 7
                        columnSpacing: 0

                        Repeater {
                            model: root.monthCells(root.monthOffset)

                            Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 33
                                radius: 17
                                color: modelData.isSelected
                                    ? Theme.primary
                                    : (dayArea.containsMouse ? Theme.notificationHover : "transparent")
                                opacity: modelData.inMonth ? 1.0 : 0.42

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    color: modelData.isSelected ? Theme.colorOnPrimary : Theme.colorOnSurface
                                    font {
                                        family: "Google Sans"
                                        pixelSize: 13
                                        weight: modelData.isToday || modelData.isSelected ? Font.Bold : Font.Normal
                                    }
                                }

                                Rectangle {
                                    visible: modelData.isToday && !modelData.isSelected
                                    width: 4
                                    height: 4
                                    radius: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    color: Theme.primary
                                }

                                MouseArea {
                                    id: dayArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedDate = modelData.date
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.notificationDivider
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.monthTitle(root.monthOffset + 1)
                        color: Theme.colorOnSurface
                        opacity: 0.9
                        font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: root.weekCells(root.monthOffset + 1)

                            Text {
                                required property var modelData
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.day
                                color: Theme.colorOnSurface
                                opacity: modelData.inMonth ? 0.84 : 0.36
                                font { family: "Google Sans"; pixelSize: 13 }
                            }
                        }
                    }
                }
            }
        }
    }

    component CalendarIconButton: Rectangle {
        signal clicked()
        property string label: ""

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        radius: 15
        color: iconArea.containsMouse ? Theme.notificationHover : "transparent"

        Text {
            anchors.centerIn: parent
            text: label
            color: Theme.colorOnSurfaceVariant
            font { family: "Google Sans"; pixelSize: 15; weight: Font.Medium }
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    function monthDate(offset) {
        var base = new Date(today.getFullYear(), today.getMonth(), 1)
        return new Date(base.getFullYear(), base.getMonth() + offset, 1)
    }

    function monthTitle(offset) {
        return Qt.formatDateTime(monthDate(offset), "MMMM yyyy")
    }

    function key(date) {
        return date.getFullYear() + "-" + date.getMonth() + "-" + date.getDate()
    }

    function monthCells(offset) {
        var first = monthDate(offset)
        var start = new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay())
        var cells = []
        var selectedKey = key(selectedDate)
        var todayKey = key(today)

        for (var i = 0; i < 35; i++) {
            var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            cells.push({
                day: d.getDate(),
                date: d,
                inMonth: d.getMonth() === first.getMonth(),
                isToday: key(d) === todayKey,
                isSelected: key(d) === selectedKey
            })
        }
        return cells
    }

    function weekCells(offset) {
        var first = monthDate(offset)
        var start = new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay())
        var cells = []
        for (var i = 0; i < 7; i++) {
            var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            cells.push({
                day: d.getDate(),
                date: d,
                inMonth: d.getMonth() === first.getMonth()
            })
        }
        return cells
    }
}
