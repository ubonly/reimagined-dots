import Quickshell 1.0
import Quickshell.Hyprland 1.0
import QtQuick 2.0

Item {
    Component.onCompleted: {
        for (var p in Hyprland) {
            console.log(p);
        }
        Qt.quit()
    }
}
