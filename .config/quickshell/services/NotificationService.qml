pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property string historyPath: ConfigService.configDir + "/notification_history.json"
    readonly property var popupNotifications: history.filter(function(notif) { return notif.popup })

    property var history: []
    property int unread: 0
    property int maxHistory: 80
    property bool ready: false
    property int _idOffset: 0

    signal notificationAdded(var notification)

    function _serialize(notification) {
        return {
            id: notification.id,
            actions: notification.actions || [],
            appIcon: notification.appIcon || "",
            appName: notification.appName || "Notification",
            body: notification.body || "",
            image: notification.image || "",
            live: !!notification.live,
            popup: !!notification.popup,
            summary: notification.summary || "",
            time: notification.time || Date.now()
        }
    }

    function _normalizeAction(action) {
        return {
            identifier: action.identifier,
            text: action.text || action.identifier
        }
    }

    function _trackedForId(id) {
        var tracked = notifServer.trackedNotifications.values
        for (var i = 0; i < tracked.length; i++) {
            var notif = tracked[i]
            if (notif.id + root._idOffset === id)
                return notif
        }
        return null
    }

    function _persist() {
        if (!root.ready)
            return
        persistTimer.restart()
    }

    function _replaceHistory(list) {
        root.history = list
        _persist()
    }

    function markAllRead() {
        root.unread = 0
    }

    function addNotification(notif) {
        var rawActions = notif.actions || []
        var actions = []
        for (var i = 0; i < rawActions.length; i++)
            actions.push(_normalizeAction(rawActions[i]))

        var entry = {
            id: notif.id + root._idOffset,
            appIcon: notif.appIcon || "",
            appName: notif.appName || "Notification",
            body: notif.body || "",
            image: notif.image || "",
            live: true,
            popup: true,
            summary: notif.summary || "",
            time: Date.now(),
            actions: actions
        }

        var list = root.history.slice()
        list.unshift(entry)
        if (list.length > root.maxHistory)
            list = list.slice(0, root.maxHistory)
        root.history = list
        root.unread += 1
        _persist()
        notificationAdded(entry)
    }

    function timeoutNotification(id) {
        var list = root.history.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                list[i].popup = false
                break
            }
        }
        _replaceHistory(list)
    }

    function removeNotification(id) {
        var tracked = _trackedForId(id)
        if (tracked)
            tracked.dismiss()

        var list = []
        for (var i = 0; i < root.history.length; i++) {
            if (root.history[i].id !== id)
                list.push(root.history[i])
        }
        _replaceHistory(list)
    }

    function clearAll() {
        var tracked = notifServer.trackedNotifications.values
        for (var i = 0; i < tracked.length; i++)
            tracked[i].dismiss()
        _replaceHistory([])
        root.unread = 0
    }

    function invokeAction(id, identifier) {
        var tracked = _trackedForId(id)
        if (!tracked)
            return

        for (var i = 0; i < tracked.actions.length; i++) {
            if (tracked.actions[i].identifier === identifier) {
                tracked.actions[i].invoke()
                removeNotification(id)
                return
            }
        }
    }

    Component.onCompleted: historyFile.reload()

    Timer {
        id: persistTimer
        interval: 80
        repeat: false
        onTriggered: historyFile.setText(JSON.stringify(root.history.map(root._serialize), null, 2))
    }

    FileView {
        id: historyFile
        path: root.historyPath

        onLoaded: {
            var text = historyFile.text().trim()
            var parsed = []
            if (text.length > 0) {
                try {
                    parsed = JSON.parse(text)
                } catch (e) {
                    console.log("Failed to parse notification history:", e)
                }
            }

            var maxId = 0
            root.history = parsed.map(function(notif) {
                var normalized = {
                    id: notif.id || 0,
                    actions: notif.actions || [],
                    appIcon: notif.appIcon || "",
                    appName: notif.appName || "Notification",
                    body: notif.body || "",
                    image: notif.image || "",
                    live: false,
                    popup: false,
                    summary: notif.summary || "",
                    time: notif.time || Date.now()
                }
                maxId = Math.max(maxId, normalized.id)
                return normalized
            })
            root._idOffset = maxId
            root.ready = true
        }

        onLoadFailed: function(error) {
            if (error == FileViewError.FileNotFound) {
                root.history = []
                root.ready = true
                historyFile.setText("[]")
            } else {
                console.log("Failed to load notification history:", error)
                root.history = []
                root.ready = true
            }
        }
    }

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyImagesSupported: false
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(notif) {
            notif.tracked = true
            notif.dismissed = false
            root.addNotification(notif)
        }
    }
}
