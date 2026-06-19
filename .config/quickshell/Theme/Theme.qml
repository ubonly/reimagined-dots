pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root

    // Core Material Colors
    property color surface: "#0d0d14"
    property color surfaceVariant: "#1e1e2e"
    property color colorOnSurface: "#cdd6f4"
    property color colorOnSurfaceVariant: "#6c7086"
    
    property color primary: "#cba6f7"
    property color colorOnPrimary: "#11111b"
    property color primaryContainer: "#3b2d5e"
    property color colorOnPrimaryContainer: "#cdd6f4"

    property color secondary: "#b4befe"
    property color tertiary: "#f5c2e7"
    property color error: "#f38ba8"
    
    property color outline: "#313244"
    property color outlineVariant: "#45475a"
    property bool isLight: false

    // Quickshell Specific Aliases (to ease refactoring)
    property color bgColor: surface
    property color cardBg: surfaceVariant
    property color activeItem: primary
    property color activeBg: primaryContainer
    property color textPrimary: colorOnSurface
    property color textSecondary: colorOnSurfaceVariant
    property color searchBg: outline
    property color switchOnColor: primary
    property color switchOffColor: outlineVariant
    property color switchKnob: colorOnSurface
    property color dividerColor: Qt.rgba(colorOnSurface.r, colorOnSurface.g, colorOnSurface.b, 0.1)
    property color dockBg: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, isLight ? 0.92 : 0.95)
    property color dockBorder: Qt.rgba(colorOnSurface.r, colorOnSurface.g, colorOnSurface.b, isLight ? 0.14 : 0.08)
    property color dockPill: Qt.rgba(colorOnSurface.r, colorOnSurface.g, colorOnSurface.b, isLight ? 0.08 : 0.10)
    property color dockPillHover: Qt.rgba(colorOnSurface.r, colorOnSurface.g, colorOnSurface.b, isLight ? 0.14 : 0.16)
    property color dockText: Qt.rgba(colorOnSurface.r, colorOnSurface.g, colorOnSurface.b, 0.92)
    property color dockTextStrong: Qt.rgba(colorOnSurface.r, colorOnSurface.g, colorOnSurface.b, 0.96)
    property color dockDivider: Qt.rgba(colorOnSurface.r, colorOnSurface.g, colorOnSurface.b, isLight ? 0.18 : 0.20)
    property color dockActive: Qt.rgba(primary.r, primary.g, primary.b, isLight ? 0.24 : 0.80)
    property color dockActiveText: isLight ? colorOnSurface : colorOnPrimary

    property string lastColorsContent: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: colorProc.running = true
    }

    Process {
        id: colorProc
        command: ["jq", "-c", ".", "/home/ubonly/.config/quickshell/colors.json"]
        running: false
        stdout: SplitParser {
            onRead: text => {
                if (text.length > 0 && text !== root.lastColorsContent) {
                    root.lastColorsContent = text;
                    try {
                        let data = JSON.parse(text);
                        if (data && data.colors) {
                            let c = data.colors;
                            root.isLight = data.mode === "light";
                            root.surface = root.isLight ? c.surface_container_low.default.color : c.surface_container_lowest.default.color;
                            root.surfaceVariant = root.isLight ? c.surface_container_high.default.color : c.surface_container_high.default.color;
                            root.colorOnSurface = c.on_surface.default.color;
                            root.colorOnSurfaceVariant = c.on_surface_variant.default.color;
                            root.primary = c.primary.default.color;
                            root.colorOnPrimary = c.on_primary.default.color;
                            root.primaryContainer = c.primary_container.default.color;
                            root.colorOnPrimaryContainer = c.on_primary_container.default.color;
                            root.secondary = c.secondary.default.color;
                            root.tertiary = c.tertiary.default.color;
                            root.error = c.error.default.color;
                            root.outline = c.outline.default.color;
                            root.outlineVariant = c.outline_variant.default.color;
                        }
                    } catch(e) {
                        console.log("[Theme] Failed to parse colors.json: " + e);
                    }
                }
            }
        }
    }
}
