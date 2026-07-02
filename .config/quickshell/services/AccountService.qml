pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string backendPath: ConfigService.configDir + "/accounts/accountctl.sh"

    property bool ready: false
    property bool busy: false
    property string error: ""
    property var google: ({
        provider: "google",
        status: "not_connected",
        displayName: "",
        email: "",
        avatar: "",
        message: "",
        error: "",
        configured: false,
        loggedIn: false,
        busy: false
    })

    readonly property bool googleLoggedIn: google.loggedIn === true
    readonly property bool useGoogleAvatar: ConfigService.ready && ConfigService.values.accountUseGoogleAvatar
    readonly property bool useGoogleDisplayName: ConfigService.ready && ConfigService.values.accountUseGoogleDisplayName

    function run(action) {
        if (accountProc.running)
            return
        accountProc.action = action
        accountProc.running = true
    }

    function refresh() {
        run("status")
    }

    function loginGoogle() {
        run("login")
    }

    function logoutGoogle() {
        run("logout")
    }

    function refreshGoogleProfile() {
        run("refresh")
    }

    function setUseGoogleAvatar(enabled) {
        if (ConfigService.ready)
            ConfigService.values.accountUseGoogleAvatar = enabled
    }

    function setUseGoogleDisplayName(enabled) {
        if (ConfigService.ready)
            ConfigService.values.accountUseGoogleDisplayName = enabled
    }

    function displayName(fallbackName) {
        if (googleLoggedIn && useGoogleDisplayName && google.displayName !== "")
            return google.displayName
        return fallbackName
    }

    function avatar() {
        if (googleLoggedIn && useGoogleAvatar && google.avatar !== "")
            return google.avatar.startsWith("/") ? "file://" + google.avatar : google.avatar
        return ""
    }

    function applyPayload(payload) {
        if (payload.provider !== "google")
            return

        root.google = {
            provider: payload.provider || "google",
            status: payload.status || "not_connected",
            displayName: payload.displayName || "",
            email: payload.email || "",
            avatar: payload.avatar || "",
            message: payload.message || "",
            error: payload.error || "",
            configured: payload.configured === true,
            loggedIn: payload.loggedIn === true,
            busy: payload.busy === true
        }
        root.error = root.google.error || ""
        root.ready = true
    }

    Component.onCompleted: refresh()

    Process {
        id: accountProc
        property string action: "status"

        command: [root.backendPath, action]
        running: false
        onRunningChanged: root.busy = running
        onExited: function(exitCode, exitStatus) {
            root.busy = false
            if (exitCode !== 0 && root.error === "") {
                root.error = exitCode === 127
                    ? "Account helper is not built."
                    : "Account helper exited with code " + exitCode + "."
            }
            root.ready = true
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
}
