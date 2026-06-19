import Quickshell
import Quickshell.Services.Mpris

PanelWindow {
    color: "transparent"
    Component.onCompleted: {
        console.log("Mpris players:", Mpris.players.length)
        if (Mpris.players.length > 0) {
            let p = Mpris.players[0]
            console.log(p.trackName, p.playbackStatus)
        }
        Qt.quit()
    }
}
