// ClipboardPopup.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "Theme"

PanelWindow {
    id: clipboardPopup
    property var screenRef
    property bool isOpen: false

    screen: screenRef
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    property bool _animVisible: false
    visible: _animVisible
    color: "transparent"

    onIsOpenChanged: {
        if (isOpen) {
            _animVisible = true
        } else {
            closeTimer.start()
        }
    }

    Timer {
        id: closeTimer
        interval: 260
        repeat: false
        onTriggered: clipboardPopup._animVisible = false
    }

    readonly property color bgSolid:       Theme.surface
    readonly property color bgItem:        "transparent"
    readonly property color bgItemHover:   Theme.surfaceVariant
    readonly property color bgItemSelected:Theme.surfaceVariant
    readonly property color textPrimary:   Theme.colorOnSurface
    readonly property color textSecondary: Theme.colorOnSurfaceVariant
    readonly property color borderColor:   Theme.outline
    readonly property color accentColor:   Theme.primary

    property var historyData: []
    property int selectedIndex: 0

    function toggle() {
        isOpen = !isOpen
        if (isOpen) {
            selectedIndex = 0
            refreshProc.running = true
        }
    }

    Process {
        id: refreshProc
        command: ["python3", "/home/ubonly/.config/quickshell/cliphist.py"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    clipboardPopup.historyData = JSON.parse(line)
                    clipboardPopup.selectedIndex = 0
                } catch(e) {}
            }
        }
    }

    function restoreItem(item) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup)
        if (item.pinned) {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "restore", item.key]
        } else {
            proc.command = item.type === "file"
                ? ["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy --type text/uri-list", "--", item.line]
                : ["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "--", item.line]
        }
        proc.running = true
        clipboardPopup.isOpen = false
    }

    function deleteItem(item) {
        if (item.pinned) {
            var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup)
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "remove", item.key]
            proc.running = true
        } else {
            var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup)
            proc.command = ["bash", "-c", "printf '%s' \"$1\" | cliphist delete", "--", item.line]
            proc.running = true
        }
        Qt.createQmlObject('import QtQuick; Timer { interval: 100; running: true; onTriggered: refreshProc.running = true }', clipboardPopup)
    }

    function togglePin(item) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup)
        if (item.pinned) {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "remove", item.key]
        } else {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "toggle", item.line]
        }
        proc.running = true
        Qt.createQmlObject('import QtQuick; Timer { interval: 120; running: true; onTriggered: refreshProc.running = true }', clipboardPopup)
    }

    Item {
        id: focusCatcher
        focus: clipboardPopup.isOpen
        Keys.onEscapePressed: clipboardPopup.isOpen = false
        Keys.onUpPressed: {
            if (clipboardPopup.selectedIndex > 0)
                clipboardPopup.selectedIndex--
            listView.positionViewAtIndex(clipboardPopup.selectedIndex, ListView.Contain)
        }
        Keys.onDownPressed: {
            if (clipboardPopup.selectedIndex < clipboardPopup.historyData.length - 1)
                clipboardPopup.selectedIndex++
            listView.positionViewAtIndex(clipboardPopup.selectedIndex, ListView.Contain)
        }
        Keys.onReturnPressed: {
            var item = clipboardPopup.historyData[clipboardPopup.selectedIndex]
            if (item) clipboardPopup.restoreItem(item)
        }
        Keys.onDeletePressed: {
            var item = clipboardPopup.historyData[clipboardPopup.selectedIndex]
            if (item) clipboardPopup.deleteItem(item)
        }
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_P) {
                var item = clipboardPopup.historyData[clipboardPopup.selectedIndex]
                if (item) clipboardPopup.togglePin(item)
                event.accepted = true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: clipboardPopup.isOpen = false
        z: -1
    }

    Rectangle {
        id: container
        anchors.centerIn: parent
        width: 360
        height: Math.min(520, headerItem.height + listContainer.implicitHeight + footerItem.height + 2)
        radius: 14
        color: clipboardPopup.bgSolid
        border.color: clipboardPopup.borderColor
        border.width: 1

        scale: clipboardPopup.isOpen ? 1.0 : 0.95
        opacity: clipboardPopup.isOpen ? 1.0 : 0.0
        transformOrigin: Item.Center

        transform: Translate {
            y: clipboardPopup.isOpen ? 0 : 24
            Behavior on y {
                NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
            }
        }

        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // header
            Item {
                id: headerItem
                Layout.fillWidth: true
                height: 50

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    text: "Clipboard"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: clipboardPopup.textPrimary
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: clipboardPopup.borderColor
            }

            // list
            ScrollView {
                id: listContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ListView {
                    id: listView
                    anchors.fill: parent
                    spacing: 0
                    model: clipboardPopup.historyData
                    clip: true
                    topMargin: 6
                    bottomMargin: 6

                    delegate: Item {
                        width: listView.width
                        property bool isSelected: index === clipboardPopup.selectedIndex
                        // image items are taller to show thumbnail
                        height: modelData.type === "image" ? 110 : 52

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            radius: 8
                            color: isSelected || mouseArea.containsMouse
                                   ? clipboardPopup.bgItemSelected
                                   : clipboardPopup.bgItem
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            spacing: 10

                            // type icon
                            Item {
                                Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                                Layout.topMargin: 2
                                width: 20; height: 20

                                Image {
                                    id: typeIconImg
                                    anchors.fill: parent
                                    source: modelData.type === "image"
                                        ? "assets/icons/image-fill.svg"
                                        : "assets/icons/match-case.svg"
                                    sourceSize: Qt.size(40, 40)
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: typeIconImg
                                    source: typeIconImg
                                    color: clipboardPopup.textPrimary
                                }
                            }
                            // content area
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Image thumbnail
                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    visible: false
                                    source: modelData.type === "image" ? modelData.imagePath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Rectangle {
                                    id: thumbMask
                                    anchors.fill: parent
                                    radius: 8
                                    visible: false
                                    layer.enabled: true
                                }
                                OpacityMask {
                                    anchors.fill: parent
                                    visible: modelData.type === "image"
                                    source: thumbImg
                                    maskSource: thumbMask
                                }

                                // text content
                                ColumnLayout {
                                    anchors.fill: parent
                                    visible: modelData.type !== "image"
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.type === "file" ? modelData.filename : modelData.preview
                                        font.pixelSize: 13
                                        color: modelData.preview && modelData.preview.startsWith("http")
                                               ? clipboardPopup.accentColor
                                               : clipboardPopup.textPrimary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        visible: isSelected
                                        text: "Ctrl+V"
                                        font.pixelSize: 11
                                        color: clipboardPopup.textSecondary
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: clipboardPopup.selectedIndex = index
                            onClicked: clipboardPopup.restoreItem(modelData)
                        }

                        // pin toggle button (top-right)
                        Item {
                            id: pinButton
                            width: 24; height: 24
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 8
                            anchors.rightMargin: 14
                            z: 2
                            visible: modelData.pinned || isSelected || mouseArea.containsMouse || pinHover.containsMouse

                            Image {
                                id: pinImg
                                anchors.centerIn: parent
                                width: 18; height: 18
                                source: modelData.pinned
                                    ? "assets/icons/keep-fill.svg"
                                    : "assets/icons/keep.svg"
                                sourceSize: Qt.size(36, 36)
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: pinImg
                                source: pinImg
                                color: modelData.pinned
                                    ? clipboardPopup.accentColor
                                    : clipboardPopup.textSecondary
                            }

                            MouseArea {
                                id: pinHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clipboardPopup.togglePin(modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: clipboardPopup.borderColor
            }

            // footer
            Item {
                id: footerItem
                Layout.fillWidth: true
                height: 52

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.04)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            width: 18; height: 18

                            Image {
                                id: footerIconImg
                                anchors.fill: parent
                                source: "assets/icons/help.svg"
                                sourceSize: Qt.size(36, 36)
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: footerIconImg
                                source: footerIconImg
                                color: clipboardPopup.textPrimary
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: clipboardPopup.historyData.length === 0
                                  ? "No items in clipboard history."
                                  : "Select an item to paste it. You can see the clipboard by pressing Launcher ⊞ + v."
                            font.pixelSize: 12
                            color: clipboardPopup.textSecondary
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                        }
                    }
                }
            }
        }
    }
}
