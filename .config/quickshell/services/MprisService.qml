pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    // List of active players after duplicate filtering
    readonly property var players: Mpris.players.values.filter(player => isRealPlayer(player))
    
    // Explicitly tracked/selected player, fallback to first available
    property MprisPlayer trackedPlayer: null
    readonly property MprisPlayer activePlayer: trackedPlayer ?? (players.length > 0 ? players[0] : null)

    readonly property bool hasActivePlasmaIntegration: Mpris.players.values.some(function(p) {
        return p.dbusName && p.dbusName.indexOf('org.mpris.MediaPlayer2.plasma-browser-integration') >= 0;
    })

    function isRealPlayer(player) {
        if (!player || !player.dbusName) return false;
        
        // Remove native browser buses only if plasma-browser-integration is actually active on D-Bus
        var name = player.dbusName;
        if (hasActivePlasmaIntegration && (name.indexOf('org.mpris.MediaPlayer2.firefox') >= 0 || name.indexOf('org.mpris.MediaPlayer2.chromium') >= 0)) {
            return false;
        }
        
        // playerctld just copies other buses and we don't need duplicates
        if (name.indexOf('org.mpris.MediaPlayer2.playerctld') >= 0) {
            return false;
        }
        
        // Non-instance mpd bus duplicates
        if (name.indexOf('.mpd') >= 0 && name.indexOf('MediaPlayer2.mpd') < 0) {
            return false;
        }

        // Must have some identity or track title to be useful
        if (!player.identity) return false;

        return true;
    }

    // Keep track of player instantiation to select the playing one automatically
    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: {
                if (root.trackedPlayer === null || modelData.isPlaying) {
                    root.trackedPlayer = modelData;
                }
            }

            Component.onDestruction: {
                if (root.trackedPlayer === modelData) {
                    root.trackedPlayer = null;
                    var activeList = root.players;
                    for (var i = 0; i < activeList.length; i++) {
                        if (activeList[i].isPlaying) {
                            root.trackedPlayer = activeList[i];
                            break;
                        }
                    }
                    if (root.trackedPlayer === null && activeList.length > 0) {
                        root.trackedPlayer = activeList[0];
                    }
                }
            }

            function onPlaybackStateChanged() {
                if (modelData.isPlaying && root.trackedPlayer !== modelData) {
                    root.trackedPlayer = modelData;
                }
            }
        }
    }

    // Media Control Functions
    function togglePlaying() {
        if (activePlayer && activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
        }
    }

    function previous() {
        if (activePlayer && activePlayer.canGoPrevious) {
            activePlayer.previous();
        }
    }

    function next() {
        if (activePlayer && activePlayer.canGoNext) {
            activePlayer.next();
        }
    }

    function setLoopState(loopState) {
        if (activePlayer && activePlayer.loopSupported && activePlayer.canControl) {
            activePlayer.loopState = loopState;
        }
    }

    function setShuffle(shuffle) {
        if (activePlayer && activePlayer.shuffleSupported && activePlayer.canControl) {
            activePlayer.shuffle = shuffle;
        }
    }

    function setActivePlayer(player) {
        root.trackedPlayer = player;
    }

    IpcHandler {
        target: "mpris"

        function pauseAll() {
            var activeList = root.players;
            for (var i = 0; i < activeList.length; i++) {
                if (activeList[i].canPause) {
                    activeList[i].pause();
                }
            }
        }

        // Global keybind hooks
        function playPause() { root.togglePlaying(); }
        function previous() { root.previous(); }
        function next() { root.next(); }
    }
}
