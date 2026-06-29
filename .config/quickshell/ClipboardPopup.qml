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
    property bool _animVisible: false
    property var historyData: []
    property int selectedIndex: 0

    readonly property color popupBg: Theme.isLight ? Qt.rgba(0.96, 0.95, 0.98, 0.98) : Qt.rgba(0.18, 0.17, 0.22, 0.98)
    readonly property color rowHover: Theme.isLight ? Qt.rgba(0.12, 0.13, 0.16, 0.08) : Qt.rgba(1, 1, 1, 0.07)
    readonly property color rowSelected: Theme.isLight ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.13) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
    readonly property color footerBg: Theme.isLight ? Qt.rgba(0.12, 0.13, 0.16, 0.10) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color textPrimary: Theme.colorOnSurface
    readonly property color textSecondary: Theme.colorOnSurfaceVariant
    readonly property color iconColor: Theme.isLight ? Qt.rgba(0.22, 0.22, 0.26, 0.88) : Qt.rgba(0.92, 0.91, 0.96, 0.88)
    readonly property color borderColor: Theme.isLight ? Qt.rgba(0.12, 0.13, 0.16, 0.16) : Qt.rgba(1, 1, 1, 0.12)

    screen: screenRef
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: _animVisible
    color: "transparent"

    onIsOpenChanged: {
        if (isOpen) {
            _animVisible = true;
            selectedIndex = 0;
            refreshProc.running = true;
            focusDelay.restart();
        } else {
            closeTimer.restart();
        }
    }

    onHistoryDataChanged: {
        if (selectedIndex >= historyData.length)
            selectedIndex = Math.max(0, historyData.length - 1);
    }

    Timer {
        id: closeTimer
        interval: 160
        repeat: false
        onTriggered: clipboardPopup._animVisible = false
    }

    Timer {
        id: focusDelay
        interval: 35
        repeat: false
        onTriggered: container.forceActiveFocus()
    }

    Process {
        id: refreshProc
        command: ["python3", "/home/ubonly/.config/quickshell/cliphist.py"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    clipboardPopup.historyData = JSON.parse(line);
                    clipboardPopup.selectedIndex = 0;
                } catch(e) {}
            }
        }
    }

    function toggle() {
        isOpen = !isOpen;
    }

    function itemText(item) {
        if (!item)
            return "";
        if (item.type === "file")
            return item.filename || "File";
        if (item.type === "image")
            return item.preview || "Image";
        return item.preview || item.raw || "Text";
    }

    function itemDetail(item) {
        if (!item)
            return "";
        if (item.type === "image")
            return "Ctrl+V";
        if (item.type === "file")
            return "Ctrl+V";
        return "";
    }

    function itemIcon(item) {
        if (!item)
            return "assets/icons/match-case.svg";
        if (item.type === "image")
            return "assets/icons/image-fill.svg";
        if (item.type === "file")
            return "assets/icons/link-off.svg";
        return "";
    }

    function selectedItem() {
        return historyData.length > 0 ? historyData[Math.max(0, Math.min(selectedIndex, historyData.length - 1))] : null;
    }

    function moveSelection(delta) {
        if (historyData.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(historyData.length - 1, selectedIndex + delta));
        listView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function restoreItem(item) {
        if (!item)
            return;
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup);
        if (item.pinned) {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "restore", item.key];
        } else {
            proc.command = item.type === "file"
                ? ["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy --type text/uri-list", "--", item.line]
                : ["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "--", item.line];
        }
        proc.running = true;
        clipboardPopup.isOpen = false;
    }

    function deleteItem(item) {
        if (!item)
            return;
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup);
        if (item.pinned) {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "remove", item.key];
        } else {
            proc.command = ["bash", "-c", "printf '%s' \"$1\" | cliphist delete", "--", item.line];
        }
        proc.running = true;
        Qt.createQmlObject('import QtQuick; Timer { interval: 120; running: true; onTriggered: refreshProc.running = true }', clipboardPopup);
    }

    function togglePin(item) {
        if (!item)
            return;
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup);
        if (item.pinned) {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "remove", item.key];
        } else {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "toggle", item.line];
        }
        proc.running = true;
        Qt.createQmlObject('import QtQuick; Timer { interval: 140; running: true; onTriggered: refreshProc.running = true }', clipboardPopup);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: clipboardPopup.isOpen = false
        z: -1
    }

    Rectangle {
        id: container
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        width: Math.min(320, parent.width - 32)
        height: Math.min(422, parent.height - 112)
        radius: 12
        color: clipboardPopup.popupBg
        border.width: 1
        border.color: clipboardPopup.borderColor
        clip: true
        focus: clipboardPopup.isOpen

        scale: clipboardPopup.isOpen ? 1.0 : 0.96
        opacity: clipboardPopup.isOpen ? 1.0 : 0.0
        transformOrigin: Item.Bottom

        transform: Translate {
            y: clipboardPopup.isOpen ? 0 : 22
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: clipboardPopup.isOpen = false
        Keys.onUpPressed: clipboardPopup.moveSelection(-1)
        Keys.onDownPressed: clipboardPopup.moveSelection(1)
        Keys.onReturnPressed: clipboardPopup.restoreItem(clipboardPopup.selectedItem())
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                clipboardPopup.deleteItem(clipboardPopup.selectedItem());
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Clipboard"
                    color: clipboardPopup.textPrimary
                    font.family: "Google Sans"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                ToolIconButton {
                    iconSource: "assets/icons/close.svg"
                    visibleButton: true
                    onClicked: clipboardPopup.isOpen = false
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    model: clipboardPopup.historyData
                    spacing: 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: clipboardPopup.selectedIndex

                    delegate: Rectangle {
                        id: itemRow
                        width: listView.width
                        height: modelData.type === "image" ? 104 : 38
                        radius: 8
                        color: index === clipboardPopup.selectedIndex
                            ? clipboardPopup.rowSelected
                            : rowMouse.containsMouse ? clipboardPopup.rowHover : "transparent"

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Item {
                            id: typeIcon
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: modelData.type === "image" ? 11 : 9
                            width: 24
                            height: 24

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.type === "text"
                                text: "Tt"
                                color: clipboardPopup.iconColor
                                font.family: "Google Sans"
                                font.pixelSize: 15
                                font.weight: Font.Medium
                            }

                            SvgIcon {
                                anchors.centerIn: parent
                                visible: modelData.type !== "text"
                                iconSource: clipboardPopup.itemIcon(modelData)
                                iconSize: 17
                                iconColor: clipboardPopup.iconColor
                            }
                        }

                        Item {
                            anchors {
                                left: typeIcon.right
                                leftMargin: 8
                                right: parent.right
                                top: parent.top
                                bottom: parent.bottom
                            }

                            Item {
                                visible: modelData.type === "image"
                                anchors.fill: parent
                                anchors.topMargin: 2
                                anchors.rightMargin: 2

                                Rectangle {
                                    id: imagePreview
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        topMargin: 0
                                    }
                                    height: 72
                                    radius: 9
                                    color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(0, 0, 0, 0.22)
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.imagePath || ""
                                        sourceSize: Qt.size(width, height)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                        smooth: true
                                    }
                                }

                                Text {
                                    anchors {
                                        left: parent.left
                                        top: imagePreview.bottom
                                        topMargin: 5
                                    }
                                    text: clipboardPopup.itemDetail(modelData)
                                    color: clipboardPopup.textSecondary
                                    font.family: "Google Sans"
                                    font.pixelSize: 10
                                }
                            }

                            RowLayout {
                                visible: modelData.type !== "image"
                                anchors.fill: parent
                                anchors.rightMargin: 6
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: clipboardPopup.itemText(modelData)
                                    color: clipboardPopup.textPrimary
                                    font.family: "Google Sans"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    visible: modelData.pinned
                                    text: "Pinned"
                                    color: clipboardPopup.textSecondary
                                    font.family: "Google Sans"
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Row {
                            z: 2
                            anchors {
                                right: parent.right
                                top: parent.top
                                rightMargin: 4
                                topMargin: 4
                            }
                            spacing: 2
                            opacity: rowMouse.containsMouse ? 1 : 0

                            Behavior on opacity { NumberAnimation { duration: 90 } }

                            ToolIconButton {
                                iconSource: modelData.pinned ? "assets/icons/keep-fill.svg" : "assets/icons/keep.svg"
                                onClicked: clipboardPopup.togglePin(modelData)
                            }

                            ToolIconButton {
                                iconSource: "assets/icons/close.svg"
                                onClicked: clipboardPopup.deleteItem(modelData)
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            z: 1
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: clipboardPopup.selectedIndex = index
                            onClicked: clipboardPopup.restoreItem(modelData)
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        width: 4
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Qt.rgba(clipboardPopup.textPrimary.r, clipboardPopup.textPrimary.g, clipboardPopup.textPrimary.b, 0.24)
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    visible: clipboardPopup.historyData.length === 0
                    spacing: 12

                    SvgIcon {
                        Layout.alignment: Qt.AlignHCenter
                        iconSource: "assets/icons/match-case.svg"
                        iconSize: 26
                        iconColor: clipboardPopup.textSecondary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Clipboard is empty"
                        horizontalAlignment: Text.AlignHCenter
                        color: clipboardPopup.textSecondary
                        font.family: "Google Sans"
                        font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 8
                color: clipboardPopup.footerBg

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 9

                    SvgIcon {
                        iconSource: "assets/icons/help.svg"
                        iconSize: 19
                        iconColor: clipboardPopup.textSecondary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Select an item to paste it. You can see the clipboard by pressing Launcher  G + V."
                        color: clipboardPopup.textSecondary
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    component SvgIcon: Item {
        id: iconRoot
        property string iconSource: ""
        property color iconColor: Theme.colorOnSurface
        property int iconSize: 18

        width: iconSize
        height: iconSize

        Image {
            id: svgImage
            anchors.fill: parent
            source: iconRoot.iconSource
            sourceSize: Qt.size(parent.width, parent.height)
            visible: false
            smooth: true
        }

        ColorOverlay {
            anchors.fill: svgImage
            source: svgImage
            color: iconRoot.iconColor
        }
    }

    component ToolIconButton: Rectangle {
        id: button
        property string iconSource: ""
        property bool visibleButton: false
        signal clicked()

        width: 24
        height: 24
        radius: 12
        color: visibleButton || buttonMouse.containsMouse
            ? (Theme.isLight ? Qt.rgba(0.12, 0.13, 0.16, 0.08) : Qt.rgba(1, 1, 1, 0.09))
            : "transparent"

        SvgIcon {
            anchors.centerIn: parent
            iconSource: button.iconSource
            iconSize: 15
            iconColor: clipboardPopup.iconColor
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                mouse.accepted = true;
                button.clicked();
            }
        }
    }
}
