pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool connected: ConfigService.ready && ConfigService.values.googleSyncState === "connected"
    readonly property bool connecting: ConfigService.ready && ConfigService.values.googleSyncState === "connecting"
    readonly property string state: ConfigService.ready ? ConfigService.values.googleSyncState : "not_connected"
    readonly property string displayName: ConfigService.ready ? ConfigService.values.googleSyncName : ""
    readonly property string email: ConfigService.ready ? ConfigService.values.googleSyncEmail : ""
    readonly property string avatar: ConfigService.ready ? ConfigService.values.googleSyncAvatar : ""
    readonly property string lastSync: ConfigService.ready ? ConfigService.values.googleSyncLastSync : ""
    readonly property bool useProfilePicture: ConfigService.ready && ConfigService.values.googleSyncUseProfilePicture
    readonly property bool useDisplayName: ConfigService.ready && ConfigService.values.googleSyncUseDisplayName
    readonly property string message: connecting
        ? "Google OAuth is not implemented yet. Save account details locally to test shell integration."
        : ""

    function beginConnect() {
        if (!ConfigService.ready)
            return
        ConfigService.values.googleSyncState = "connecting"
    }

    function saveLocalAccount(name, emailAddress, avatarUrl) {
        if (!ConfigService.ready)
            return

        ConfigService.values.googleSyncName = String(name || "").trim()
        ConfigService.values.googleSyncEmail = String(emailAddress || "").trim()
        ConfigService.values.googleSyncAvatar = String(avatarUrl || "").trim()
        ConfigService.values.googleSyncState = ConfigService.values.googleSyncName !== "" ? "connected" : "not_connected"
        syncNow()
    }

    function syncNow() {
        if (!ConfigService.ready || ConfigService.values.googleSyncState !== "connected")
            return
        ConfigService.values.googleSyncLastSync = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm")
    }

    function disconnect() {
        if (!ConfigService.ready)
            return

        ConfigService.values.googleSyncState = "not_connected"
        ConfigService.values.googleSyncName = ""
        ConfigService.values.googleSyncEmail = ""
        ConfigService.values.googleSyncAvatar = ""
        ConfigService.values.googleSyncLastSync = ""
        ConfigService.values.googleSyncUseProfilePicture = false
        ConfigService.values.googleSyncUseDisplayName = false
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
}
