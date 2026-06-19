// WifiWidget.qml
// Показывает иконку WiFi: полоски белые если есть сеть, серые если нет.
// Опрашивает nmcli каждые 5 секунд.
//
// Зависимость: networkmanager (обычно уже установлен)

import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    implicitWidth:  28
    implicitHeight: 22

    // -1 = нет соединения, 0-100 = сила сигнала
    property int signal: -1

    // ── Опрос nmcli ───────────────────────────────────────────────────────
    Process {
        id: wifiProc
        command: ["bash", "-c",
            "nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '/^yes/{print $2; exit}' || echo '-1'"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var v = parseInt(line.trim())
                root.signal = isNaN(v) ? -1 : v
            }
        }
    }

    // Первый запрос сразу при старте
    Component.onCompleted: wifiProc.running = true

    Timer {
        interval: 5000
        repeat:   true
        running:  true
        onTriggered: wifiProc.running = true
    }

    // ── Сила сигнала в полосках 0-4 ──────────────────────────────────────
    readonly property int bars: {
        if (signal < 0)   return 0
        if (signal < 25)  return 1
        if (signal < 50)  return 2
        if (signal < 75)  return 3
        return 4
    }

    readonly property color activeColor:   Qt.rgba(1.0, 1.0, 1.0, 0.92)
    readonly property color inactiveColor: Qt.rgba(0.4, 0.4, 0.5, 0.45)

    // ── WiFi-дуги (4 штуки снизу-вверх, больший радиус = выше) ──────────
    // Рисуем как вертикальные скруглённые полоски (mobile-style)
    Row {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom:           parent.bottom
        }
        spacing: 3

        // Полоска 1 (самая низкая, всегда есть при любом сигнале)
        Rectangle {
            width:  3; height: 5; radius: 1.5
            anchors.bottom: parent.bottom
            color: root.bars >= 1 ? root.activeColor : root.inactiveColor
        }
        // Полоска 2
        Rectangle {
            width:  3; height: 9; radius: 1.5
            anchors.bottom: parent.bottom
            color: root.bars >= 2 ? root.activeColor : root.inactiveColor
        }
        // Полоска 3
        Rectangle {
            width:  3; height: 13; radius: 1.5
            anchors.bottom: parent.bottom
            color: root.bars >= 3 ? root.activeColor : root.inactiveColor
        }
        // Полоска 4 (самая высокая)
        Rectangle {
            width:  3; height: 17; radius: 1.5
            anchors.bottom: parent.bottom
            color: root.bars >= 4 ? root.activeColor : root.inactiveColor
        }
    }
}
