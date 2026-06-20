import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Theme"
import "services"

PanelWindow {
    id: osdRoot

    // Target the currently focused monitor dynamically
    property var focusedScreen: {
        var mon = Hyprland.focusedMonitor;
        if (mon) {
            var found = Quickshell.screens.find(s => s.name === mon.name);
            if (found) return found;
        }
        return Quickshell.screens[0];
    }
    screen: focusedScreen

    // Window configuration
    color: "transparent"
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    
    // Position: Center bottom. Under Wayland LayerShell, leaving left/right false
    // and specifying a width centers the window horizontally.
    anchors {
        bottom: true
    }
    margins {
        bottom: 100
    }

    implicitWidth: 240
    implicitHeight: 56
    
    // Only make the window active/visible when content has opacity > 0
    visible: osdContent.opacity > 0.0

    // State management
    QtObject {
        id: root
        property string activeType: "volume" // "volume" | "brightness"
        property bool ready: false

        // Delay activation on startup to avoid displaying OSD during initial services loading
        property var initTimer: Timer {
            interval: 1500
            running: true
            repeat: false
            onTriggered: root.ready = true
        }

        function show(type) {
            if (!ready) return;
            activeType = type;
            osdContent.opacity = 0.95;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: {
            osdContent.opacity = 0.0;
        }
    }

    // Connect to services state changes
    Connections {
        target: AudioService
        function onVolumeChanged() {
            root.show("volume");
        }
        function onMutedChanged() {
            root.show("volume");
        }
    }

    Connections {
        target: BrightnessService
        function onBrightnessChanged() {
            root.show("brightness");
        }
    }

    // Visual layout container - Opacity applied here
    Rectangle {
        id: osdContent
        anchors.fill: parent
        color: Theme.surfaceVariant
        border.color: Theme.outlineVariant
        border.width: 1
        radius: 24
        opacity: 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            // Icon Wrapper
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)

                Image {
                    id: osdIconImg
                    anchors.centerIn: parent
                    width: 18; height: 18
                    source: {
                        if (root.activeType === "volume") {
                            if (AudioService.muted || AudioService.volume === 0) 
                                return "assets/icons/notifications-off.svg";
                            return "assets/icons/volume-up.svg";
                        } else {
                            return "assets/icons/wb-sunny.svg";
                        }
                    }
                    sourceSize: Qt.size(18, 18)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: osdIconImg
                    source: osdIconImg
                    color: Theme.primary
                }
            }

            // Slider / Progress track
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Qt.rgba(Theme.colorOnSurface.r, Theme.colorOnSurface.g, Theme.colorOnSurface.b, 0.12)

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                    width: {
                        var val = (root.activeType === "volume") ? AudioService.volume : BrightnessService.brightness;
                        return parent.width * (Math.max(0, Math.min(100, val)) / 100.0);
                    }

                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }
            }

            // Numeric percentage representation
            Text {
                text: {
                    var val = (root.activeType === "volume") ? AudioService.volume : BrightnessService.brightness;
                    return Math.max(0, Math.min(100, val)) + "%";
                }
                font.pixelSize: 13
                font.family: "Google Sans"
                font.weight: Font.Bold
                color: Theme.colorOnSurface
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
