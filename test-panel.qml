import QtQuick
import Quickshell

ShellRoot {
    PanelWindow {
        anchors { bottom: true; left: true; right: true }
        height: 100
        color: "#222222"
        
        Row {
            anchors.centerIn: parent
            spacing: 20
            
            Image { width: 48; height: 48; source: "image://icon/preferences-system" }
            Image { width: 48; height: 48; source: "image://icon/media-record" }
            Image { width: 48; height: 48; source: "image://icon/camera-photo" }
            Image { width: 48; height: 48; source: "image://icon/window-close" }
            Image { width: 48; height: 48; source: "image://icon/go-previous" }
            Image { width: 48; height: 48; source: "image://icon/system-lock-screen" }
            Image { width: 48; height: 48; source: "image://icon/system-shutdown" }
            Image { width: 48; height: 48; source: "image://icon/bluetooth" }
            Image { width: 48; height: 48; source: "image://icon/list-add" }
            Image { width: 48; height: 48; source: "image://icon/view-fullscreen" }
            Image { width: 48; height: 48; source: "image://icon/edit-select" } // crop region
            Image { width: 48; height: 48; source: "image://icon/applications-system" }
        }
    }
}
