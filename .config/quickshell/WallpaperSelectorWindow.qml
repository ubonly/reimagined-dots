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

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:wallpaperSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"

    // Attach to the top center
    anchors {
        top: true
        left: true
        right: true
    }
    margins.top: 8

    implicitHeight: 620

    visible: selectorVisible

    // ── Folder model (shows both dirs and images) ──────────────────────────
    FolderListModel {
        id: folderModel
        folder: "file:///home/ubonly/Pictures/Wallpapers"
        showDirs: true
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        // No nameFilters here — filtering in delegate so dirs are still shown
    }

    function isImage(name) {
        let ext = name.split(".").pop().toLowerCase();
        return ["png", "jpg", "jpeg", "webp", "avif", "bmp", "gif"].indexOf(ext) !== -1;
    }

    // ── Navigate into directory ────────────────────────────────────────────
    function navigateTo(path) {
        folderModel.folder = "file://" + path;
    }
    function navigateUp() {
        let current = folderModel.folder.toString().replace("file://", "");
        let parent = current.replace(/\/[^\/]+\/?$/, "");
        if (parent.length === 0) parent = "/";
        folderModel.folder = "file://" + parent;
    }
    function currentPath() {
        return folderModel.folder.toString().replace("file://", "");
    }

    // ── Quick‐dirs for sidebar ─────────────────────────────────────────────
    property var quickDirs: [
        { icon: "🏠", name: "Home",       path: "/home/ubonly" },
        { icon: "🖼️", name: "Pictures",   path: "/home/ubonly/Pictures" },
        { icon: "📥", name: "Downloads",  path: "/home/ubonly/Downloads" },
        { icon: "🎨", name: "Wallpapers", path: "/home/ubonly/Pictures/Wallpapers" },
    ]

    // ─── CLICK OUTSIDE TO CLOSE ───────────────────────────────────────────
    MouseArea {
        z: 0
        anchors.fill: parent
        onClicked: wallpaperRoot.selectorVisible = false
    }

    // ─── MAIN CONTENT ─────────────────────────────────────────────────────
    Rectangle {
        id: mainBg
        z: 1
        anchors {
            fill: parent
            leftMargin: 200
            rightMargin: 200
            topMargin: 0
            bottomMargin: 0
        }
        color: Theme.surface
        radius: 20
        border.color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.12)
        border.width: 1
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── LEFT SIDEBAR: Quick dirs ──────────────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 170
                Layout.margins: 6
                radius: 14
                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.04)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        text: "Pick a wallpaper"
                        font { pixelSize: 14; family: "Google Sans"; weight: Font.Medium }
                        color: Theme.colorOnSurface
                        Layout.leftMargin: 8
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                    }

                    Repeater {
                        model: wallpaperRoot.quickDirs
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 18
                            color: wallpaperRoot.currentPath() === modelData.path
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                   : mouseAreaSidebar.containsMouse
                                     ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06)
                                     : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8
                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 16
                                }
                                Text {
                                    text: modelData.name
                                    font { pixelSize: 13; family: "Google Sans" }
                                    color: wallpaperRoot.currentPath() === modelData.path
                                           ? Theme.primary
                                           : Theme.colorOnSurface
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: mouseAreaSidebar
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wallpaperRoot.navigateTo(modelData.path)
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // ── RIGHT PANEL: Address bar + Grid ──────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ── Address bar ─────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.margins: 6
                    Layout.bottomMargin: 0
                    radius: 12
                    color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.04)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 4

                        // Back (up) button
                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: upBtnMa.containsMouse ? Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.08) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "⬆"
                                font.pixelSize: 14
                                color: Theme.colorOnSurface
                            }
                            MouseArea {
                                id: upBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wallpaperRoot.navigateUp()
                            }
                        }

                        // Breadcrumb path
                        Text {
                            Layout.fillWidth: true
                            text: wallpaperRoot.currentPath()
                            font { pixelSize: 13; family: "Google Sans" }
                            color: Theme.colorOnSurfaceVariant
                            elide: Text.ElideMiddle
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Close button
                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: closeBtnMa.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.15) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 14
                                color: Theme.colorOnSurface
                            }
                            MouseArea {
                                id: closeBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wallpaperRoot.selectorVisible = false
                            }
                        }
                    }
                }

                // ── Image / Folder Grid ─────────────────────────────────
                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 6
                    clip: true
                    cellWidth: (grid.width) / 4
                    cellHeight: cellWidth * 0.75

                    model: folderModel

                    delegate: Item {
                        id: delegateItem
                        width: grid.cellWidth

                        // Expose model properties at delegate level
                        property bool isDir: model.fileIsDir
                        property string itemFileName: model.fileName
                        property string itemFilePath: model.filePath
                        property bool itemIsImage: !model.fileIsDir && wallpaperRoot.isImage(model.fileName)
                        property url itemFileURL: itemIsImage ? ("file://" + model.filePath) : ""

                        // Show only dirs and image files; hide other files
                        visible: isDir || itemIsImage
                        height: grid.cellHeight

                        Rectangle {
                            id: cellBg
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 12
                            color: cellMa.containsMouse
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                   : Theme.surfaceVariant
                            border.color: cellMa.containsMouse
                                          ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                          : Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.06)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            clip: true

                            // ── Folder icon (visible when isDir) ──────────
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                visible: delegateItem.isDir
                                Text {
                                    text: "📁"
                                    font.pixelSize: 40
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: delegateItem.itemFileName
                                    font { pixelSize: 12; family: "Google Sans" }
                                    color: Theme.colorOnSurface
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.maximumWidth: grid.cellWidth - 30
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            // ── Image preview (visible when NOT isDir) ────
                            Image {
                                anchors.fill: parent
                                visible: delegateItem.itemIsImage
                                source: delegateItem.itemFileURL
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize: Qt.size(480, 360)
                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        console.log("[WP] Failed to load:", source);
                                    }
                                }
                            }

                            // Filename label at bottom (for images)
                            Rectangle {
                                visible: !delegateItem.isDir
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 24
                                color: Qt.rgba(0, 0, 0, 0.55)
                                Text {
                                    anchors.centerIn: parent
                                    text: delegateItem.itemFileName
                                    font { pixelSize: 11; family: "Google Sans" }
                                    color: "white"
                                    elide: Text.ElideRight
                                    width: parent.width - 12
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (delegateItem.isDir) {
                                        wallpaperRoot.navigateTo(delegateItem.itemFilePath);
                                    } else {
                                        Quickshell.execDetached(["bash", ConfigService.configDir + "/set_wallpaper.sh", delegateItem.itemFilePath]);
                                        wallpaperRoot.selectorVisible = false;
                                    }
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        width: 6
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.3)
                        }
                    }
                }
            }
        }
    }

    // ── Escape to close ───────────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        onActivated: wallpaperRoot.selectorVisible = false
    }
}
