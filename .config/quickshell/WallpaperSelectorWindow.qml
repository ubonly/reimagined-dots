import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import "Theme"
import "services"

PanelWindow {
    id: wallpaperRoot

    property bool selectorVisible: false
    property string homePath: "/home/ubonly"
    property string picturesPath: homePath + "/Pictures"
    property string downloadedPath: picturesPath + "/Wallpapers"
    property string savedPath: picturesPath + "/Saved_Wallpapers"
    property string selectedPath: ""
    property bool applying: false

    readonly property string activeWallpaperPath: ConfigService.ready ? ConfigService.values.wallpaperPath : ""
    readonly property string startPath: downloadedPath

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:wallpaperSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }
    margins.top: 8

    implicitHeight: 660
    visible: selectorVisible

    onSelectorVisibleChanged: {
        if (selectorVisible && selectedPath === "") {
            selectedPath = activeWallpaperPath
        }
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

    FolderListModel {
        id: folderModel
        folder: "file://" + wallpaperRoot.startPath
        showDirs: true
        showFiles: true
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif", "*.bmp", "*.gif"]
    }

    Process {
        id: applyProc
        command: ["bash", ConfigService.configDir + "/set_wallpaper.sh", wallpaperRoot.selectedPath]
        running: false
        onRunningChanged: {
            if (!running && wallpaperRoot.applying) {
                wallpaperRoot.applying = false
                wallpaperRoot.selectorVisible = false
            }
        }
    }

    function isImage(name) {
        let ext = name.split(".").pop().toLowerCase()
        return ["png", "jpg", "jpeg", "webp", "avif", "bmp", "gif"].indexOf(ext) !== -1
    }

    function setFolder(path) {
        if (!path || path.length === 0)
            return
        folderModel.folder = "file://" + path
    }

    function currentPath() {
        return folderModel.folder.toString().replace("file://", "")
    }

    function currentFolderName() {
        let parts = currentPath().split("/")
        return parts.length > 0 ? parts[parts.length - 1] : currentPath()
    }

    function navigateTo(path) {
        setFolder(path)
    }

    function navigateUp() {
        let current = currentPath()
        let parent = current.replace(/\/[^\/]+\/?$/, "")
        if (parent.length === 0)
            parent = "/"
        setFolder(parent)
    }

    function selectPath(path) {
        selectedPath = path
    }

    function openBrowser(path) {
        setFolder(path && path.length > 0 ? path : startPath)
        selectedPath = activeWallpaperPath
        selectorVisible = true
    }

    function applySelected() {
        if (selectedPath === "" || applying)
            return
        applying = true
        applyProc.command = ["bash", ConfigService.configDir + "/set_wallpaper.sh", selectedPath]
        applyProc.running = true
    }

    property var quickDirs: [
        { icon: "assets/icons/image-fill.svg", name: "Downloaded", path: downloadedPath },
        { icon: "assets/icons/wallpaper.svg", name: "Saved", path: savedPath },
        { icon: "assets/icons/wallpaper.svg", name: "Pictures", path: picturesPath },
        { icon: "assets/icons/apps.svg", name: "Home", path: homePath }
    ]

    MouseArea {
        z: 0
        anchors.fill: parent
        onClicked: wallpaperRoot.selectorVisible = false
    }

    Rectangle {
        id: mainBg
        z: 1
        anchors {
            fill: parent
            leftMargin: 180
            rightMargin: 180
        }
        radius: 24
        color: Theme.surface
        border.color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.14 : 0.10)
        border.width: 1
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 190
                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.04 : 0.025)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text {
                        text: "Wallpaper"
                        font.pixelSize: 18
                        font.family: "Google Sans"
                        font.weight: Font.DemiBold
                        color: Theme.colorOnSurface
                        Layout.bottomMargin: 8
                    }

                    Repeater {
                        model: wallpaperRoot.quickDirs

                        delegate: Rectangle {
                            id: quickDir
                            property bool selected: wallpaperRoot.currentPath() === modelData.path

                            Layout.fillWidth: true
                            height: 44
                            radius: 22
                            color: selected
                                ? Theme.primaryContainer
                                : quickDirMouse.containsMouse
                                    ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.08 : 0.07)
                                    : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                spacing: 10

                                SvgIcon {
                                    iconSource: modelData.icon
                                    iconSize: 20
                                    iconColor: quickDir.selected ? Theme.colorOnPrimaryContainer : Theme.colorOnSurface
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.pixelSize: 13
                                    font.family: "Google Sans"
                                    font.weight: Font.Medium
                                    color: quickDir.selected ? Theme.colorOnPrimaryContainer : Theme.colorOnSurface
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: quickDirMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wallpaperRoot.navigateTo(modelData.path)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        text: "Images are applied through the existing wallpaper pipeline, so Matugen and upscale settings stay active."
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        font.family: "Google Sans"
                        color: Theme.colorOnSurfaceVariant
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 12
                        spacing: 10

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 18
                            color: upMouse.containsMouse
                                ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.10)
                                : Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06)

                            SvgIcon {
                                anchors.centerIn: parent
                                iconSource: "assets/icons/arrow-back.svg"
                                iconSize: 18
                                iconColor: Theme.colorOnSurface
                                rotation: 90
                            }

                            MouseArea {
                                id: upMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wallpaperRoot.navigateUp()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: wallpaperRoot.currentFolderName()
                                font.pixelSize: 15
                                font.family: "Google Sans"
                                font.weight: Font.DemiBold
                                color: Theme.colorOnSurface
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: wallpaperRoot.currentPath()
                                font.pixelSize: 11
                                font.family: "Google Sans"
                                color: Theme.colorOnSurfaceVariant
                                elide: Text.ElideMiddle
                            }
                        }

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 18
                            color: closeMouse.containsMouse ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.10) : "transparent"

                            SvgIcon {
                                anchors.centerIn: parent
                                iconSource: "assets/icons/close.svg"
                                iconSize: 18
                                iconColor: Theme.colorOnSurface
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wallpaperRoot.selectorVisible = false
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.dividerColor
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 14
                    clip: true
                    cellWidth: Math.max(180, Math.floor(grid.width / Math.max(1, Math.floor(grid.width / 210))))
                    cellHeight: Math.round(cellWidth * 0.62)
                    model: folderModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: delegateItem
                        width: grid.cellWidth
                        height: grid.cellHeight

                        property bool isDir: model.fileIsDir
                        property string itemFileName: model.fileName
                        property string itemFilePath: model.filePath
                        property bool itemIsImage: !model.fileIsDir && wallpaperRoot.isImage(model.fileName)
                        property bool selected: wallpaperRoot.selectedPath === itemFilePath
                        property bool active: wallpaperRoot.activeWallpaperPath === itemFilePath
                        property url itemFileURL: itemIsImage ? ("file://" + model.filePath) : ""

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 16
                            color: delegateItem.selected
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, Theme.isLight ? 0.18 : 0.24)
                                : cellMouse.containsMouse
                                    ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.07 : 0.08)
                                    : Theme.surfaceVariant
                            border.width: delegateItem.selected || delegateItem.active ? 2 : 1
                            border.color: delegateItem.selected
                                ? Theme.primary
                                : delegateItem.active
                                    ? Theme.secondary
                                    : Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.08)
                            clip: true
                            Behavior on color { ColorAnimation { duration: 130 } }
                            Behavior on border.color { ColorAnimation { duration: 130 } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: delegateItem.itemIsImage ? 0 : 20
                                visible: delegateItem.itemIsImage
                                source: delegateItem.itemFileURL
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize: Qt.size(360, 220)
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                visible: delegateItem.isDir
                                spacing: 8

                                SvgIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    iconSource: "assets/icons/wallpaper.svg"
                                    iconSize: 38
                                    iconColor: Theme.colorOnSurfaceVariant
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: delegateItem.itemFileName
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
                                    font.family: "Google Sans"
                                    color: Theme.colorOnSurface
                                }
                            }

                            Rectangle {
                                visible: delegateItem.itemIsImage
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 34
                                color: Qt.rgba(0, 0, 0, 0.48)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: delegateItem.itemFileName
                                        font.pixelSize: 11
                                        font.family: "Google Sans"
                                        color: "white"
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: delegateItem.active
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: Theme.secondary
                                    }
                                }
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (delegateItem.isDir) {
                                        wallpaperRoot.navigateTo(delegateItem.itemFilePath)
                                    } else if (delegateItem.itemIsImage) {
                                        wallpaperRoot.selectPath(delegateItem.itemFilePath)
                                    }
                                }
                                onDoubleClicked: {
                                    if (delegateItem.itemIsImage) {
                                        wallpaperRoot.selectPath(delegateItem.itemFilePath)
                                        wallpaperRoot.applySelected()
                                    }
                                }
                            }
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
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 260
                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, Theme.isLight ? 0.035 : 0.025)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        radius: 18
                        color: Theme.surfaceVariant
                        border.width: 1
                        border.color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.08)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: wallpaperRoot.selectedPath !== "" ? ("file://" + wallpaperRoot.selectedPath) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: wallpaperRoot.selectedPath === ""
                            text: "Select wallpaper"
                            font.pixelSize: 13
                            font.family: "Google Sans"
                            color: Theme.colorOnSurfaceVariant
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: wallpaperRoot.selectedPath !== "" ? wallpaperRoot.selectedPath.split("/").pop() : "No wallpaper selected"
                        font.pixelSize: 14
                        font.family: "Google Sans"
                        font.weight: Font.Medium
                        color: Theme.colorOnSurface
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: wallpaperRoot.selectedPath !== "" ? wallpaperRoot.selectedPath : "Choose an image from the grid."
                        font.pixelSize: 11
                        font.family: "Google Sans"
                        color: Theme.colorOnSurfaceVariant
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 22
                        color: wallpaperRoot.selectedPath === ""
                            ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.10)
                            : applyMouse.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.86)
                                : Theme.primary
                        opacity: wallpaperRoot.selectedPath === "" ? 0.55 : 1.0
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: wallpaperRoot.applying ? "Applying..." : "Set wallpaper"
                            font.pixelSize: 13
                            font.family: "Google Sans"
                            font.weight: Font.DemiBold
                            color: Theme.colorOnPrimary
                        }

                        MouseArea {
                            id: applyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: wallpaperRoot.selectedPath === "" ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: wallpaperRoot.selectedPath !== "" && !wallpaperRoot.applying
                            onClicked: wallpaperRoot.applySelected()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.dividerColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: wallpaperRoot.activeWallpaperPath !== "" ? "Current wallpaper" : "Current wallpaper is not set"
                        font.pixelSize: 11
                        font.family: "Google Sans"
                        color: Theme.colorOnSurfaceVariant
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: wallpaperRoot.activeWallpaperPath !== ""
                        text: wallpaperRoot.activeWallpaperPath.split("/").pop()
                        font.pixelSize: 12
                        font.family: "Google Sans"
                        color: Theme.colorOnSurface
                        elide: Text.ElideMiddle
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: wallpaperRoot.selectorVisible = false
    }
}
