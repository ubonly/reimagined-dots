pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string backendPath: ConfigService.configDir + "/google_syncctl.py"
    readonly property bool connected: ConfigService.ready && ConfigService.values.googleSyncState === "connected"
    readonly property bool connecting: ConfigService.ready && (ConfigService.values.googleSyncState === "connecting" || oauthProcess.running)
    readonly property string state: ConfigService.ready ? ConfigService.values.googleSyncState : "not_connected"
    readonly property string oauthClientId: ConfigService.ready ? ConfigService.values.googleOAuthClientId : ""
    readonly property string displayName: ConfigService.ready ? ConfigService.values.googleSyncName : ""
    readonly property string email: ConfigService.ready ? ConfigService.values.googleSyncEmail : ""
    readonly property string avatar: ConfigService.ready ? ConfigService.values.googleSyncAvatar : ""
    readonly property string lastSync: ConfigService.ready ? ConfigService.values.googleSyncLastSync : ""
    readonly property string tokenExpiresAt: ConfigService.ready ? ConfigService.values.googleSyncTokenExpiresAt : ""
    readonly property bool useProfilePicture: ConfigService.ready && ConfigService.values.googleSyncUseProfilePicture
    readonly property bool useDisplayName: ConfigService.ready && ConfigService.values.googleSyncUseDisplayName
    readonly property string message: ConfigService.ready ? ConfigService.values.googleSyncMessage : ""
    readonly property bool hasOAuthClientId: oauthClientId.trim() !== ""
    readonly property bool canStartAuth: ConfigService.ready && hasOAuthClientId && !oauthProcess.running

    property string authUrl: ""
    property string pendingClientId: ""
    property string pendingLoginHint: ""

    function beginConnect() {
        if (!ConfigService.ready)
            return

        if (!hasOAuthClientId) {
            ConfigService.values.googleSyncState = "not_connected"
            ConfigService.values.googleSyncMessage = "Google OAuth Client ID is required. Create a Desktop OAuth client in Google Cloud and paste its Client ID below."
            return
        }

        ConfigService.values.googleSyncState = "connecting"
        ConfigService.values.googleSyncMessage = "Opening Google sign-in in the browser..."
        pendingClientId = oauthClientId.trim()
        pendingLoginHint = email
        oauthProcess.running = true
    }

    function openAuthUrl() {
        if (authUrl !== "")
            Quickshell.execDetached(["xdg-open", authUrl])
    }

    function saveOAuthClientId(clientId) {
        if (!ConfigService.ready)
            return

        ConfigService.values.googleOAuthClientId = String(clientId || "").trim()
        if (ConfigService.values.googleSyncState === "connecting" && !oauthProcess.running)
            ConfigService.values.googleSyncState = "not_connected"
        if (ConfigService.values.googleOAuthClientId !== "" && ConfigService.values.googleSyncMessage.indexOf("Client ID is required") !== -1)
            ConfigService.values.googleSyncMessage = ""
    }

    function resetStaleConnecting() {
        if (!ConfigService.ready || oauthProcess.running)
            return

        if (ConfigService.values.googleSyncState === "connecting") {
            ConfigService.values.googleSyncState = "not_connected"
            ConfigService.values.googleSyncMessage = "Previous Google sign-in session was interrupted. Start sign-in again."
            authUrl = ""
        }
    }

    function saveLocalAccount(name, emailAddress, avatarUrl) {
        if (!ConfigService.ready)
            return

        ConfigService.values.googleSyncName = String(name || "").trim()
        ConfigService.values.googleSyncEmail = String(emailAddress || "").trim()
        ConfigService.values.googleSyncAvatar = String(avatarUrl || "").trim()
        ConfigService.values.googleSyncState = ConfigService.values.googleSyncName !== "" ? "connected" : "not_connected"
        ConfigService.values.googleSyncMessage = ConfigService.values.googleSyncName !== "" ? "" : "Google name is required for the manual fallback account."
        ConfigService.values.googleSyncTokenExpiresAt = ""
        syncNow()
    }

    function syncNow() {
        if (!ConfigService.ready || ConfigService.values.googleSyncState !== "connected")
            return
        ConfigService.values.googleSyncLastSync = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm")
        ConfigService.values.googleSyncMessage = ""
    }

    function disconnect() {
        if (!ConfigService.ready)
            return

        if (oauthProcess.running)
            oauthProcess.running = false

        ConfigService.values.googleSyncState = "not_connected"
        ConfigService.values.googleSyncName = ""
        ConfigService.values.googleSyncEmail = ""
        ConfigService.values.googleSyncAvatar = ""
        ConfigService.values.googleSyncLastSync = ""
        ConfigService.values.googleSyncMessage = ""
        ConfigService.values.googleSyncTokenExpiresAt = ""
        ConfigService.values.googleSyncUseProfilePicture = false
        ConfigService.values.googleSyncUseDisplayName = false
        authUrl = ""
    }

    function applyBackendPayload(payload) {
        if (!ConfigService.ready)
            return

        if (payload.authUrl !== undefined)
            authUrl = String(payload.authUrl)

        if (payload.state !== undefined)
            ConfigService.values.googleSyncState = String(payload.state)

        if (payload.message !== undefined)
            ConfigService.values.googleSyncMessage = String(payload.message)

        if (payload.event === "connected") {
            ConfigService.values.googleSyncName = String(payload.displayName || "").trim()
            ConfigService.values.googleSyncEmail = String(payload.email || "").trim()
            ConfigService.values.googleSyncAvatar = String(payload.avatar || "").trim()
            ConfigService.values.googleSyncLastSync = String(payload.lastSync || Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm"))
            ConfigService.values.googleSyncTokenExpiresAt = String(payload.tokenExpiresAt || "")
            ConfigService.values.googleSyncState = ConfigService.values.googleSyncName !== "" ? "connected" : "not_connected"
            ConfigService.values.googleSyncMessage = ConfigService.values.googleSyncName !== "" ? "" : "Google profile response did not include a display name."
        }
    }

    function setUseProfilePicture(enabled) {
        if (ConfigService.ready && connected)
            ConfigService.values.googleSyncUseProfilePicture = enabled
    }

    function setUseDisplayName(enabled) {
        if (ConfigService.ready && connected)
            ConfigService.values.googleSyncUseDisplayName = enabled
    }

    function lockScreenName(fallbackName) {
        if (connected && useDisplayName && displayName !== "")
            return displayName
        return fallbackName
    }

    function lockScreenAvatar() {
        if (connected && useProfilePicture && avatar !== "")
            return avatar.startsWith("/") ? "file://" + avatar : avatar
        return ""
    }

    Component.onCompleted: resetStaleConnecting()

    Connections {
        target: ConfigService
        function onReadyChanged() {
            root.resetStaleConnecting()
        }
    }

    Process {
        id: oauthProcess
        command: ["python3", "-B", root.backendPath, "connect", root.pendingClientId, root.pendingLoginHint]
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim().length === 0)
                    return

                try {
                    root.applyBackendPayload(JSON.parse(line.trim()))
                } catch (e) {
                    if (ConfigService.ready)
                        ConfigService.values.googleSyncMessage = String(e)
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (!ConfigService.ready)
                return

            if (exitCode !== 0 && ConfigService.values.googleSyncState === "connecting") {
                ConfigService.values.googleSyncState = "not_connected"
                if (ConfigService.values.googleSyncMessage === "")
                    ConfigService.values.googleSyncMessage = "Google sign-in failed with exit code " + exitCode + "."
            }
        }
    }
}
