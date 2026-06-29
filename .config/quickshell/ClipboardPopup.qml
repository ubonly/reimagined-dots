// ClipboardPopup.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "Theme"
import "services"

PanelWindow {
    id: clipboardPopup

    property var screenRef
    property bool isOpen: false
    property bool _animVisible: false
    property var historyData: []
    property int selectedIndex: 0
    property real windowX: -1
    property real windowY: -1
    readonly property real screenWidth: screenRef ? screenRef.width : width
    readonly property real screenHeight: screenRef ? screenRef.height : height
    readonly property real windowWidth: Math.min(340, Math.max(300, screenWidth - 32))
    readonly property real windowHeight: Math.min(440, Math.max(330, screenHeight - 112))

    readonly property color popupBg: Theme.isLight
        ? Theme.surface
        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.98)
    readonly property color headerBg: Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, Theme.isLight ? 0.28 : 0.34)
    readonly property color rowHover: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.07 : 0.08)
    readonly property color rowSelected: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, Theme.isLight ? 0.16 : 0.22)
    readonly property color footerBg: Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, Theme.isLight ? 0.24 : 0.30)
    readonly property color textPrimary: Theme.colorOnSurface
    readonly property color textSecondary: Theme.colorOnSurfaceVariant
    readonly property color iconColor: Theme.colorOnSurface
    readonly property color borderColor: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, Theme.isLight ? 0.40 : 0.34)

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
            restoreWindowPosition();
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

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value));
    }

    function defaultWindowX() {
        return Math.round((screenWidth - windowWidth) / 2);
    }

    function defaultWindowY() {
        return Math.round(Math.max(24, screenHeight - windowHeight - 72));
    }

    function restoreWindowPosition() {
        var savedX = ConfigService.ready ? ConfigService.values.clipboardWindowX : -1;
        var savedY = ConfigService.ready ? ConfigService.values.clipboardWindowY : -1;
        windowX = savedX >= 0 ? savedX : defaultWindowX();
        windowY = savedY >= 0 ? savedY : defaultWindowY();
        clampWindowPosition();
    }

    function clampWindowPosition() {
        windowX = clamp(windowX, 8, Math.max(8, screenWidth - windowWidth - 8));
        windowY = clamp(windowY, 8, Math.max(8, screenHeight - windowHeight - 56));
    }

    function saveWindowPosition() {
        clampWindowPosition();
        if (!ConfigService.ready)
            return;
        ConfigService.values.clipboardWindowX = Math.round(windowX);
        ConfigService.values.clipboardWindowY = Math.round(windowY);
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
        x: clipboardPopup.windowX
        y: clipboardPopup.windowY
        width: clipboardPopup.windowWidth
        height: clipboardPopup.windowHeight
        radius: 14
        color: clipboardPopup.popupBg
        border.width: 1
        border.color: clipboardPopup.borderColor
        clip: true
        focus: clipboardPopup.isOpen

        scale: clipboardPopup.isOpen ? 1.0 : 0.96
        opacity: clipboardPopup.isOpen ? 1.0 : 0.0
        transformOrigin: Item.Center

        transform: Translate {
            y: clipboardPopup.isOpen ? 0 : 14
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
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
            spacing: 0

            Rectangle {
                id: titlebar
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: clipboardPopup.headerBg

                MouseArea {
                    id: dragArea
                    property real startMouseX: 0
                    property real startMouseY: 0
                    property real startWindowX: 0
                    property real startWindowY: 0

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: function(mouse) {
                        startMouseX = mouse.x;
                        startMouseY = mouse.y;
                        startWindowX = clipboardPopup.windowX;
                        startWindowY = clipboardPopup.windowY;
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed)
                            return;
                        clipboardPopup.windowX = clipboardPopup.clamp(startWindowX + mouse.x - startMouseX, 8, Math.max(8, clipboardPopup.screenWidth - container.width - 8));
                        clipboardPopup.windowY = clipboardPopup.clamp(startWindowY + mouse.y - startMouseY, 8, Math.max(8, clipboardPopup.screenHeight - container.height - 56));
                    }
                    onReleased: {
                        clipboardPopup.saveWindowPosition();
                    }
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Clipboard"
                    color: clipboardPopup.textPrimary
                    font.family: "Google Sans"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                ToolIconButton {
                    anchors {
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    iconSource: "assets/icons/close.svg"
                    visibleButton: true
                    onClicked: clipboardPopup.isOpen = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: clipboardPopup.borderColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 10

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
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 10

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
            ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.08 : 0.10)
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
