pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string backendPath: ConfigService.configDir + "/integrationctl.py"

    property bool ready: false
    property bool busy: false
    property string error: ""

    property var providers: []
    property string activeProvider: ""
    property var syncStatus: ({
        id: "",
        displayName: "None",
        connected: false,
        connecting: false,
        connectionState: "not_connected",
        username: "",
        avatar: "",
        repository: "",
        lastSync: "",
        message: "",
        authSession: ({})
    })
    property var phoneStatus: ({
        installed: false,
        daemonRunning: false,
        available: false,
        connected: false,
        state: "unavailable",
        devices: [],
        deviceName: "",
        batteryLevel: "",
        deviceType: "",
        message: "",
        canRefresh: false,
        canOpen: false,
        canInstall: true
    })

    function refresh() {
        backendProc.action = "state"
        backendProc.args = []
        backendProc.running = true
    }

    function connectSync(providerId) {
        backendProc.action = "sync-connect"
        backendProc.args = [providerId]
        backendProc.running = true
    }

    function selectSyncProvider(providerId) {
        backendProc.action = "sync-select"
        backendProc.args = [providerId]
        backendProc.running = true
    }

    function syncNow() {
        backendProc.action = "sync"
        backendProc.args = []
        backendProc.running = true
    }

    function disconnectSync() {
        backendProc.action = "sync-disconnect"
        backendProc.args = []
        backendProc.running = true
    }

    function connectPhone() {
        backendProc.action = "phone-refresh"
        backendProc.args = []
        backendProc.running = true
    }

    function refreshPhone() {
        backendProc.action = "phone-refresh"
        backendProc.args = []
        backendProc.running = true
    }

    function openKdeConnect() {
        backendProc.action = "phone-open"
        backendProc.args = []
        backendProc.running = true
    }

    function installKdeConnect() {
        backendProc.action = "phone-install"
        backendProc.args = []
        backendProc.running = true
    }

    function pairPhone(deviceId) {
        backendProc.action = "phone-pair"
        backendProc.args = [deviceId]
        backendProc.running = true
    }

    function unpairPhone(deviceId) {
        backendProc.action = "phone-unpair"
        backendProc.args = [deviceId]
        backendProc.running = true
    }

    function pingPhone(deviceId) {
        backendProc.action = "phone-ping"
        backendProc.args = [deviceId]
        backendProc.running = true
    }

    function sendFilePhone(deviceId) {
        backendProc.action = "phone-send-file"
        backendProc.args = [deviceId]
        backendProc.running = true
    }

    function disconnectPhone(deviceId) {
        backendProc.action = "phone-disconnect"
        backendProc.args = [deviceId]
        backendProc.running = true
    }

    function applyPayload(payload) {
        if (payload.error)
            root.error = payload.error
        else
            root.error = ""

        if (payload.sync) {
            root.providers = payload.sync.providers || []
            root.activeProvider = payload.sync.activeProvider || ""
            root.syncStatus = payload.sync.status || root.syncStatus
        }
        if (payload.phone)
            root.phoneStatus = payload.phone
        root.ready = true
    }

    Component.onCompleted: refresh()

    Process {
        id: backendProc
        property string action: "state"
        property var args: []

        command: ["python3", "-B", root.backendPath, action].concat(args)
        running: false
        onRunningChanged: root.busy = running
        onExited: function(exitCode, exitStatus) {
            root.busy = false
            if (exitCode !== 0 && root.error === "")
                root.error = "Integration backend exited with code " + exitCode
        }

        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim().length === 0)
                    return
                try {
                    root.applyPayload(JSON.parse(line.trim()))
                } catch (e) {
                    root.error = String(e)
                }
            }
        }
    }

    Process {
        id: phoneWatchProc
        command: ["python3", "-B", root.backendPath, "watch-phone"]
        running: true

        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim().length === 0)
                    return
                try {
                    root.applyPayload(JSON.parse(line.trim()))
                } catch (e) {
                    root.error = String(e)
                }
            }
        }

        onExited: phoneWatchRestart.start()
    }

    Timer {
        id: phoneWatchRestart
        interval: 3000
        repeat: false
        onTriggered: {
            if (!phoneWatchProc.running)
                phoneWatchProc.running = true
        }
    }
}
