import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "Theme"
import "services"

Scope {
    id: root

    property bool running: false
    property bool overlayVisible: false
    property string wallpaperSource: ""

    property real lockWidgetsOpacity: 1
    property real lockWidgetsY: 0
    property real lockWidgetScale: 1
    property real lockClockScale: 1
    property real lockWallpaperScale: 1.045
    property real lockBlurOpacity: 1
    property real lockDimOpacity: 1

    property real coverOpacity: 1
    property real coverY: 0
    property real coverScale: 1

    signal releaseLockRequested()
    signal finished()

    function start() {
        unlockSequence.stop();
        running = true;
        overlayVisible = true;

        lockWidgetsOpacity = 1;
        lockWidgetsY = 0;
        lockWidgetScale = 1;
        lockClockScale = 1;
        lockWallpaperScale = 1.045;
        lockBlurOpacity = 1;
        lockDimOpacity = 1;

        coverOpacity = 1;
        coverY = 0;
        coverScale = 1;
        UnlockTransitionService.prepareDesktopReveal();

        unlockSequence.restart();
    }

    function reset() {
        unlockSequence.stop();
        running = false;
        overlayVisible = false;

        lockWidgetsOpacity = 1;
        lockWidgetsY = 0;
        lockWidgetScale = 1;
        lockClockScale = 1;
        lockWallpaperScale = 1.045;
        lockBlurOpacity = 1;
        lockDimOpacity = 1;

        coverOpacity = 1;
        coverY = 0;
        coverScale = 1;
        UnlockTransitionService.reset();
    }

    SequentialAnimation {
        id: unlockSequence

        ParallelAnimation {
            NumberAnimation { target: root; property: "lockWidgetsOpacity"; to: 0; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "lockDimOpacity"; to: 0.18; duration: 330; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "lockBlurOpacity"; to: 0; duration: 340; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "lockWallpaperScale"; to: 1; duration: 360; easing.type: Easing.OutCubic }
            SpringAnimation { target: root; property: "lockWidgetsY"; to: -42; spring: 5.4; damping: 0.42; epsilon: 0.04 }
            SpringAnimation { target: root; property: "lockWidgetScale"; to: 0.965; spring: 5.2; damping: 0.44; epsilon: 0.01 }
            SpringAnimation { target: root; property: "lockClockScale"; to: 0.955; spring: 5.2; damping: 0.44; epsilon: 0.01 }
        }

        ScriptAction {
            script: root.releaseLockRequested()
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "coverOpacity"; to: 0; duration: 560; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "coverY"; to: -30; duration: 620; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "coverScale"; to: 0.972; duration: 620; easing.type: Easing.OutCubic }

            NumberAnimation { target: UnlockTransitionService; property: "dockOpacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
            SpringAnimation { target: UnlockTransitionService; property: "dockYOffset"; to: 0; spring: 4.6; damping: 0.30; epsilon: 0.02 }
            SpringAnimation { target: UnlockTransitionService; property: "dockScale"; to: 1; spring: 4.8; damping: 0.32; epsilon: 0.002 }

            NumberAnimation { target: UnlockTransitionService; property: "topOpacity"; to: 1; duration: 360; easing.type: Easing.OutCubic }
            SpringAnimation { target: UnlockTransitionService; property: "topYOffset"; to: 0; spring: 4.4; damping: 0.34; epsilon: 0.02 }

            NumberAnimation { target: UnlockTransitionService; property: "desktopWidgetsProgress"; to: 1; duration: 560; easing.type: Easing.OutCubic }
        }

        ScriptAction {
            script: {
                root.overlayVisible = false;
                root.running = false;
                UnlockTransitionService.reset();
                root.finished();
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            property var modelData

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-unlock-transition"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            visible: root.overlayVisible

            Item {
                id: cover
                anchors.fill: parent
                opacity: root.coverOpacity
                y: root.coverY
                scale: root.coverScale
                transformOrigin: Item.Center

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bgColor
                }

                Image {
                    id: coverWallpaper
                    anchors.fill: parent
                    source: root.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: false
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(0, 0, 0, 0.22)
                }
            }

        }
    }
}
