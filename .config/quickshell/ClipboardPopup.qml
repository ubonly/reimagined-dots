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
    property string searchQuery: ""
    property string filterMode: "all"
    property var filteredData: filterHistory(historyData, searchQuery, filterMode)

    readonly property color bgSolid: Theme.surface
    readonly property color bgCard: Theme.surfaceVariant
    readonly property color bgCardHover: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.08 : 0.10)
    readonly property color bgCardSelected: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, Theme.isLight ? 0.16 : 0.24)
    readonly property color textPrimary: Theme.colorOnSurface
    readonly property color textSecondary: Theme.colorOnSurfaceVariant
    readonly property color borderColor: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.12 : 0.10)
    readonly property color accentColor: Theme.primary

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
            _animVisible = true
            selectedIndex = 0
            refreshProc.running = true
            focusDelay.restart()
        } else {
            closeTimer.start()
        }
    }

    onFilteredDataChanged: {
        if (selectedIndex >= filteredData.length)
            selectedIndex = Math.max(0, filteredData.length - 1)
    }

    Timer {
        id: closeTimer
        interval: 220
        repeat: false
        onTriggered: clipboardPopup._animVisible = false
    }

    Timer {
        id: focusDelay
        interval: 35
        repeat: false
        onTriggered: searchField.forceActiveFocus()
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

    function toggle() {
        isOpen = !isOpen
    }

    function normalizedText(item) {
        if (!item)
            return ""
        return ((item.preview || "") + " " + (item.filename || "") + " " + (item.raw || "")).toLowerCase()
    }

    function itemTitle(item) {
        if (!item)
            return ""
        if (item.type === "image")
            return item.pinned ? "Pinned image" : "Image"
        if (item.type === "file")
            return item.filename || "File"
        return item.preview || "Text"
    }

    function itemSubtitle(item) {
        if (!item)
            return ""
        if (item.type === "image")
            return item.raw || "Image from clipboard"
        if (item.type === "file")
            return item.preview || "File"
        return item.raw && item.raw.length > item.preview.length ? item.raw : ""
    }

    function itemIcon(item) {
        if (!item)
            return "assets/icons/match-case.svg"
        if (item.type === "image")
            return "assets/icons/image-fill.svg"
        if (item.type === "file")
            return "assets/icons/link-off.svg"
        return "assets/icons/match-case.svg"
    }

    function filterHistory(items, query, mode) {
        var out = []
        var q = (query || "").trim().toLowerCase()
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            if (mode === "pinned" && !item.pinned)
                continue
            if (mode === "images" && item.type !== "image")
                continue
            if (q.length > 0 && normalizedText(item).indexOf(q) === -1)
                continue
            out.push(item)
        }
        return out
    }

    function selectedItem() {
        return filteredData.length > 0 ? filteredData[Math.max(0, Math.min(selectedIndex, filteredData.length - 1))] : null
    }

    function moveSelection(delta) {
        if (filteredData.length === 0)
            return
        selectedIndex = Math.max(0, Math.min(filteredData.length - 1, selectedIndex + delta))
        listView.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function setFilter(mode) {
        filterMode = mode
        selectedIndex = 0
        listView.positionViewAtBeginning()
    }

    function restoreItem(item) {
        if (!item)
            return
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
        if (!item)
            return
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup)
        if (item.pinned) {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "remove", item.key]
        } else {
            proc.command = ["bash", "-c", "printf '%s' \"$1\" | cliphist delete", "--", item.line]
        }
        proc.running = true
        Qt.createQmlObject('import QtQuick; Timer { interval: 120; running: true; onTriggered: refreshProc.running = true }', clipboardPopup)
    }

    function togglePin(item) {
        if (!item)
            return
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup)
        if (item.pinned) {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "remove", item.key]
        } else {
            proc.command = ["python3", "/home/ubonly/.config/quickshell/clipboard_pin.py", "toggle", item.line]
        }
        proc.running = true
        Qt.createQmlObject('import QtQuick; Timer { interval: 140; running: true; onTriggered: refreshProc.running = true }', clipboardPopup)
    }

    component SvgIcon: Item {
        id: iconRoot
        property string iconSource: ""
        property color iconColor: Theme.colorOnSurface
        property int iconSize: 20

        width: iconSize
        height: iconSize

        Image {
            id: svgImage
            anchors.fill: parent
            source: iconRoot.iconSource
            sourceSize: Qt.size(parent.width, parent.height)
            visible: false
        }

        ColorOverlay {
            anchors.fill: svgImage
            source: svgImage
            color: iconRoot.iconColor
        }
    }

    component FilterChip: Rectangle {
        id: chip
        property string label: ""
        property string mode: "all"
        property bool active: clipboardPopup.filterMode === mode

        Layout.preferredWidth: Math.max(74, chipText.implicitWidth + 28)
        height: 34
        radius: 17
        color: active
            ? Theme.primaryContainer
            : chipMouse.containsMouse
                ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.08 : 0.10)
                : Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.05 : 0.07)
        border.width: active ? 0 : 1
        border.color: clipboardPopup.borderColor
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.pixelSize: 12
            font.family: "Google Sans"
            font.weight: Font.Medium
            color: chip.active ? Theme.colorOnPrimaryContainer : clipboardPopup.textPrimary
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: clipboardPopup.setFilter(chip.mode)
        }
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
        anchors.bottomMargin: 86
        width: Math.min(620, parent.width - 48)
        height: Math.min(620, parent.height - 132)
        radius: 28
        color: clipboardPopup.bgSolid
        border.color: clipboardPopup.borderColor
        border.width: 1
        clip: true

        scale: clipboardPopup.isOpen ? 1.0 : 0.96
        opacity: clipboardPopup.isOpen ? 1.0 : 0.0
        transformOrigin: Item.Bottom

        transform: Translate {
            y: clipboardPopup.isOpen ? 0 : 28
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        }

        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, Theme.isLight ? 0.18 : 0.24)

                    SvgIcon {
                        anchors.centerIn: parent
                        iconSource: "assets/icons/match-case.svg"
                        iconSize: 20
                        iconColor: Theme.colorOnSurface
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Clipboard"
                    font.pixelSize: 19
                    font.family: "Google Sans"
                    font.weight: Font.DemiBold
                    color: clipboardPopup.textPrimary
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: closeMouse.containsMouse
                        ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.10)
                        : "transparent"

                    SvgIcon {
                        anchors.centerIn: parent
                        iconSource: "assets/icons/close.svg"
                        iconSize: 18
                        iconColor: clipboardPopup.textPrimary
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardPopup.isOpen = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 24
                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.06 : 0.08)
                border.width: 1
                border.color: searchField.activeFocus ? Theme.primary : "transparent"
                Behavior on border.color { ColorAnimation { duration: 130 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        iconSource: "assets/icons/search.svg"
                        iconSize: 20
                        iconColor: clipboardPopup.textSecondary
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            text: clipboardPopup.searchQuery
                            color: clipboardPopup.textPrimary
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.colorOnPrimary
                            font.pixelSize: 14
                            font.family: "Google Sans"
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: {
                                clipboardPopup.searchQuery = text
                                clipboardPopup.selectedIndex = 0
                            }
                            Keys.onEscapePressed: clipboardPopup.isOpen = false
                            Keys.onUpPressed: clipboardPopup.moveSelection(-1)
                            Keys.onDownPressed: clipboardPopup.moveSelection(1)
                            Keys.onReturnPressed: clipboardPopup.restoreItem(clipboardPopup.selectedItem())
                        }

                        Text {
                            anchors.fill: parent
                            visible: searchField.text.length === 0
                            text: "Search"
                            font.pixelSize: 14
                            font.family: "Google Sans"
                            color: clipboardPopup.textSecondary
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle {
                        visible: clipboardPopup.searchQuery.length > 0
                        width: 28
                        height: 28
                        radius: 14
                        color: clearSearchMouse.containsMouse
                            ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.10)
                            : "transparent"

                        SvgIcon {
                            anchors.centerIn: parent
                            iconSource: "assets/icons/close.svg"
                            iconSize: 16
                            iconColor: clipboardPopup.textSecondary
                        }

                        MouseArea {
                            id: clearSearchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchField.text = ""
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                FilterChip { label: "All"; mode: "all" }
                FilterChip { label: "Pinned"; mode: "pinned" }
                FilterChip { label: "Images"; mode: "images" }

                Item { Layout.fillWidth: true }

                Text {
                    text: clipboardPopup.filteredData.length + "/" + clipboardPopup.historyData.length
                    font.pixelSize: 12
                    font.family: "Google Sans"
                    color: clipboardPopup.textSecondary
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: clipboardPopup.borderColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    spacing: 10
                    model: clipboardPopup.filteredData
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    topMargin: 2
                    bottomMargin: 2

                    delegate: Rectangle {
                        id: itemCard
                        width: listView.width
                        height: modelData.type === "image" ? 128 : 76
                        radius: 18
                        property bool isSelected: index === clipboardPopup.selectedIndex

                        color: itemCard.isSelected
                            ? clipboardPopup.bgCardSelected
                            : itemMouse.containsMouse
                                ? clipboardPopup.bgCardHover
                                : clipboardPopup.bgCard
                        border.width: itemCard.isSelected ? 1 : 0
                        border.color: itemCard.isSelected ? Theme.primary : "transparent"
                        clip: true
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: modelData.type === "image" ? 128 : 44
                                Layout.preferredHeight: modelData.type === "image" ? 104 : 44
                                radius: modelData.type === "image" ? 14 : 22
                                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.08 : 0.10)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    visible: modelData.type === "image"
                                    source: modelData.type === "image" ? modelData.imagePath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    visible: modelData.type !== "image"
                                    iconSource: clipboardPopup.itemIcon(modelData)
                                    iconSize: 22
                                    iconColor: clipboardPopup.textPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: clipboardPopup.itemTitle(modelData)
                                        font.pixelSize: 14
                                        font.family: "Google Sans"
                                        font.weight: Font.Medium
                                        color: modelData.preview && modelData.preview.startsWith("http")
                                            ? clipboardPopup.accentColor
                                            : clipboardPopup.textPrimary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Rectangle {
                                        visible: modelData.pinned
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 24
                                        radius: 12
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, Theme.isLight ? 0.20 : 0.26)

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            iconSource: "assets/icons/keep-fill.svg"
                                            iconSize: 15
                                            iconColor: Theme.primary
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: clipboardPopup.itemSubtitle(modelData)
                                    visible: text.length > 0
                                    font.pixelSize: 12
                                    font.family: "Google Sans"
                                    color: clipboardPopup.textSecondary
                                    wrapMode: Text.Wrap
                                    maximumLineCount: modelData.type === "image" ? 3 : 2
                                    elide: Text.ElideRight
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 36
                                Layout.fillHeight: true
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 17
                                    color: pinMouse.containsMouse
                                        ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.12)
                                        : Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06)

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        iconSource: modelData.pinned ? "assets/icons/keep-fill.svg" : "assets/icons/keep.svg"
                                        iconSize: 18
                                        iconColor: modelData.pinned ? Theme.primary : clipboardPopup.textPrimary
                                    }

                                    MouseArea {
                                        id: pinMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clipboardPopup.togglePin(modelData)
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 17
                                    color: deleteMouse.containsMouse
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                                        : Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06)

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        iconSource: "assets/icons/close.svg"
                                        iconSize: 18
                                        iconColor: deleteMouse.containsMouse ? Theme.error : clipboardPopup.textPrimary
                                    }

                                    MouseArea {
                                        id: deleteMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clipboardPopup.deleteItem(modelData)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: clipboardPopup.selectedIndex = index
                            onClicked: clipboardPopup.restoreItem(modelData)
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        width: 8
                        contentItem: Rectangle {
                            implicitWidth: 8
                            radius: 4
                            color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.28)
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 64
                    visible: clipboardPopup.filteredData.length === 0
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        radius: 27
                        color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.08 : 0.10)

                        SvgIcon {
                            anchors.centerIn: parent
                            iconSource: "assets/icons/match-case.svg"
                            iconSize: 26
                            iconColor: clipboardPopup.textSecondary
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: clipboardPopup.historyData.length === 0 ? "Clipboard is empty" : "No matching items"
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 15
                        font.family: "Google Sans"
                        font.weight: Font.Medium
                        color: clipboardPopup.textPrimary
                    }
                }
            }
        }
    }
}
