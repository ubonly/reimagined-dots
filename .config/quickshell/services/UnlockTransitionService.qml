pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool active: false
    property real dockYOffset: 0
    property real dockOpacity: 1
    property real dockScale: 1
    property real topYOffset: 0
    property real topOpacity: 1
    property real desktopWidgetsProgress: 1

    function reset() {
        active = false;
        dockYOffset = 0;
        dockOpacity = 1;
        dockScale = 1;
        topYOffset = 0;
        topOpacity = 1;
        desktopWidgetsProgress = 1;
    }

    function prepareDesktopReveal() {
        active = true;
        dockYOffset = 34;
        dockOpacity = 0;
        dockScale = 0.985;
        topYOffset = -18;
        topOpacity = 0;
        desktopWidgetsProgress = 0;
    }
}
