// AppLauncher.qml — Chrome OS-style full-screen app launcher
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "Theme"

PanelWindow {
    id: launcher
    property var screenRef
    property bool isOpen: false
    property bool _settledOpen: false

    screen: screenRef
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Keep window alive during close animation
    property bool _animVisible: false
    visible: _animVisible
    color: "transparent"

    onIsOpenChanged: {
        if (isOpen) {
            closeTimer.stop()
            _settledOpen = false
            _animVisible = true
            settleTimer.restart()
        } else {
            settleTimer.stop()
            _settledOpen = false
            closeTimer.start()
        }
    }

    Timer {
        id: closeTimer
        interval: 210
        repeat: false
        onTriggered: launcher._animVisible = false
    }

    Timer {
        id: settleTimer
        interval: 220
        repeat: false
        onTriggered: launcher._settledOpen = launcher.isOpen
    }

    Timer {
        id: focusTimer
        interval: 90
        repeat: false
        onTriggered: {
            if (launcher.isOpen)
                searchInput.forceActiveFocus()
            if (launcher.isOpen)
                launcher.resetLauncherScroll()
        }
    }

    // palette
    readonly property color bgTint:       Theme.surfaceVariant
    readonly property color searchBg:     Theme.surface
    readonly property color searchBorder: Theme.outline
    readonly property color textPrimary:  Theme.colorOnSurface
    readonly property color textSecondary:Theme.colorOnSurfaceVariant
    readonly property color hoverBg:      Theme.outlineVariant

    // recent apps
    property var recentApps: []
    property string _recentBuf: ""
    readonly property string recentFile: Qt.resolvedUrl("recent-apps.json").toString().replace("file://", "")

    onRecentAppsChanged: {
        clampRecentIndex()
        if (isOpen && searchText === "") {
            activeSection = recentVisible() ? "recent" : "apps"
            resetLauncherScroll()
        }
    }

    Process {
        id: recentReadProc
        command: ["python3", "-c",
            "import json,sys; f=open('" + launcher.recentFile + "'); print(f.read()); f.close()"]
        running: false
        stdout: SplitParser {
            onRead: function(line) { launcher._recentBuf += line }
        }
        onRunningChanged: {
            if (!running && launcher._recentBuf.length > 1) {
                try { launcher.recentApps = JSON.parse(launcher._recentBuf) } catch(e) {}
                launcher._recentBuf = ""
            } else if (running) {
                launcher._recentBuf = ""
            }
        }
    }

    Process {
        id: saveProc
        property string dataToWrite: ""
        command: ["python3", "-c",
            "import sys; open('" + launcher.recentFile + "','w').write('" + JSON.stringify(launcher.recentApps).replace(/'/g, "\\'") + "')"]
        running: false
    }

    function addToRecent(app) {
        var list = launcher.recentApps.slice()
        // Remove existing entry for same app
        for (var i = list.length - 1; i >= 0; i--) {
            if (list[i].exec === app.exec) list.splice(i, 1)
        }
        list.unshift(app)
        if (list.length > 5) list = list.slice(0, 5)
        launcher.recentApps = list
        // Save to file — rebuild command with fresh data
        var jsonStr = JSON.stringify(list).replace(/\\/g, "\\\\").replace(/'/g, "\\'")
        saveProc.command = ["python3", "-c",
            "open('" + launcher.recentFile + "','w').write('" + jsonStr + "')"]
        saveProc.running = true
    }

    Process {
        id: hyprSocketProc
        command: [
            "python3", "-c",
            "import socket, os, sys\n" +
            "path = f\"{os.environ.get('XDG_RUNTIME_DIR','')}/hypr/{os.environ.get('HYPRLAND_INSTANCE_SIGNATURE','')}/.socket2.sock\"\n" +
            "try:\n" +
            "  with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:\n" +
            "    s.connect(path)\n" +
            "    while True:\n" +
            "      data = s.recv(4096)\n" +
            "      if not data: break\n" +
            "      for line in data.decode().split('\\n'):\n" +
            "        if line.startswith('activewindow>>'):\n" +
            "          print(line.split('>>')[1].split(',')[0], flush=True)\n" +
            "except Exception as e: pass"
        ]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.length > 0) {
                    launcher.trackExternalLaunch(line)
                }
            }
        }
    }

    function trackExternalLaunch(cls) {
        if (!cls || launcher.allApps.length === 0) return;
        var low = cls.toLowerCase();
        var shr = cls.split('.').pop().toLowerCase();
        
        var aliases = {
            "zen": "zen-browser",
            "navigator": "firefox",
            "code": "code-oss",
            "nautilus": "org.gnome.nautilus"
        };
        var target = aliases[low] || aliases[cls] || shr;
        
        // Find best match
        for (var i = 0; i < launcher.allApps.length; i++) {
            var app = launcher.allApps[i];
            var appIcon = (app.icon || "").toLowerCase();
            var appName = (app.name || "").toLowerCase();
            var execBase = app.exec.split(' ')[0].split('/').pop().toLowerCase();
            
            if (appIcon === target || appIcon === low || 
                execBase === target || execBase === low || 
                appName === target || appName === low) {
                
                // Only add if it's not already the very first recent app
                // (prevents rapid firing on focus changes)
                if (launcher.recentApps.length > 0 && launcher.recentApps[0].exec === app.exec) {
                    return;
                }
                launcher.addToRecent(app);
                break;
            }
        }
    }

    // app loading
    property var allApps: []
    property var filteredApps: []
    property string searchText: ""
    property int activeIndex: 0
    property string activeSection: "apps"
    property int recentIndex: 0
    property string _buf: ""
    readonly property int maxSearchResults: 10
    readonly property var searchAliases: ({
        "vsc": ["visual studio code", "code-oss", "vscode", "code"],
        "vscode": ["visual studio code", "code-oss", "code"],
        "code": ["visual studio code", "code-oss", "vscode"],
        "ff": ["firefox"],
        "tg": ["telegram"],
        "dc": ["discord"],
        "disc": ["discord"],
        "term": ["terminal", "kitty", "foot", "konsole"],
        "fm": ["file manager", "files", "nautilus", "dolphin", "thunar"]
    })

    function recentVisible() {
        return searchText === "" && recentApps.length > 0
    }

    function clampRecentIndex() {
        recentIndex = Math.max(0, Math.min(recentIndex, recentApps.length - 1))
    }

    function lastRowIndexForColumn(column) {
        if (filteredApps.length === 0)
            return 0

        var cols = appScroll.columns
        var last = filteredApps.length - 1
        var lastRowStart = Math.floor(last / cols) * cols
        return Math.min(lastRowStart + Math.max(0, column), last)
    }

    function selectRecent(column) {
        if (!recentVisible())
            return false

        activeSection = "recent"
        recentIndex = Math.min(Math.max(0, column), recentApps.length - 1)
        appScroll.scrollToTop()
        return true
    }

    function selectApp(index, animated) {
        if (filteredApps.length === 0)
            return false

        activeSection = "apps"
        activeIndex = Math.max(0, Math.min(index, filteredApps.length - 1))
        if (animated)
            appScroll.scrollToIndex(activeIndex)
        else
            appScroll.ensureActiveVisible()
        return true
    }

    function selectBottomFromColumn(column) {
        if (filteredApps.length === 0)
            return false

        activeSection = "apps"
        activeIndex = lastRowIndexForColumn(column)
        appScroll.scrollToBottom()
        return true
    }

    function moveSelection(key) {
        var cols = appScroll.columns
        var maxIdx = filteredApps.length - 1

        if (key === Qt.Key_Right) {
            if (activeSection === "recent" && recentVisible())
                recentIndex = Math.min(recentIndex + 1, recentApps.length - 1)
            else
                selectApp(Math.min(activeIndex + 1, maxIdx), false)
            return true
        }

        if (key === Qt.Key_Left) {
            if (activeSection === "recent" && recentVisible())
                recentIndex = Math.max(recentIndex - 1, 0)
            else
                selectApp(Math.max(activeIndex - 1, 0), false)
            return true
        }

        if (key === Qt.Key_Down) {
            if (activeSection === "recent" && recentVisible())
                return selectApp(Math.min(recentIndex, maxIdx), false)

            if (activeIndex + cols <= maxIdx)
                return selectApp(activeIndex + cols, false)

            var downColumn = activeIndex % cols
            if (selectRecent(downColumn))
                return true
            return selectApp(Math.min(downColumn, maxIdx), true)
        }

        if (key === Qt.Key_Up) {
            if (activeSection === "recent" && recentVisible())
                return selectBottomFromColumn(recentIndex)

            if (activeIndex - cols >= 0)
                return selectApp(activeIndex - cols, false)

            var upColumn = activeIndex % cols
            if (selectRecent(upColumn))
                return true
            return selectBottomFromColumn(upColumn)
        }

        return false
    }

    function resetSelectionForEmptySearch() {
        activeIndex = 0
        recentIndex = 0
        activeSection = recentVisible() ? "recent" : "apps"
    }

    function resetLauncherScroll() {
        if (!appScroll)
            return

        appScroll.stopScrollAnimation()
        appScroll.contentY = appScroll.topContentY()
    }

    Process {
        id: listProc
        command: ["python3", Qt.resolvedUrl("list-apps.py").toString().replace("file://", "")]
        running: false
        stdout: SplitParser {
            onRead: function(line) { launcher._buf += line }
        }
        onRunningChanged: {
            if (!running && launcher._buf.length > 2) {
                try {
                    var arr = JSON.parse(launcher._buf)
                    arr.sort(function(a, b) { return a.name.localeCompare(b.name) })
                    launcher.allApps = arr
                    launcher.filterApps()
                } catch(e) { console.log("parse error:", e) }
                launcher._buf = ""
            } else if (running) {
                launcher._buf = ""
            }
        }
    }

    Component.onCompleted: {
        listProc.running = true
        recentReadProc.running = true
    }

    function normalizeSearchText(value) {
        return (value || "").toLowerCase().replace(/[^a-z0-9а-яё]+/g, " ").trim()
    }

    function compactSearchText(value) {
        return launcher.normalizeSearchText(value).replace(/\s+/g, "")
    }

    function addUnique(list, value) {
        var normalized = launcher.normalizeSearchText(value)
        if (normalized.length > 0 && list.indexOf(normalized) < 0)
            list.push(normalized)
    }

    function ruKeyboardToEn(value) {
        var map = {
            "й": "q", "ц": "w", "у": "e", "к": "r", "е": "t", "н": "y", "г": "u", "ш": "i", "щ": "o", "з": "p", "х": "[", "ъ": "]",
            "ф": "a", "ы": "s", "в": "d", "а": "f", "п": "g", "р": "h", "о": "j", "л": "k", "д": "l", "ж": ";", "э": "'",
            "я": "z", "ч": "x", "с": "c", "м": "v", "и": "b", "т": "n", "ь": "m", "б": ",", "ю": "."
        }
        var out = ""
        var lower = (value || "").toLowerCase()
        for (var i = 0; i < lower.length; i++)
            out += map[lower[i]] || lower[i]
        return out
    }

    function transliterateRuToLatin(value) {
        var map = {
            "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z", "и": "i", "й": "y",
            "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f",
            "х": "h", "ц": "c", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya"
        }
        var out = ""
        var lower = (value || "").toLowerCase()
        for (var i = 0; i < lower.length; i++)
            out += map[lower[i]] !== undefined ? map[lower[i]] : lower[i]
        return out
    }

    function phoneticVariants(value) {
        var variants = []
        launcher.addUnique(variants, value)

        var compact = launcher.compactSearchText(value)
        launcher.addUnique(variants, compact)

        if (compact.indexOf("k") >= 0)
            launcher.addUnique(variants, compact.replace(/k/g, "c"))
        if (compact.indexOf("ds") >= 0)
            launcher.addUnique(variants, compact.replace(/ds/g, "dc"))
        if (compact.indexOf("ks") >= 0)
            launcher.addUnique(variants, compact.replace(/ks/g, "x"))
        if (compact.indexOf("y") >= 0)
            launcher.addUnique(variants, compact.replace(/y/g, "i"))

        return variants
    }

    function queryVariants(rawQuery) {
        var variants = []
        launcher.addUnique(variants, rawQuery)
        launcher.addUnique(variants, launcher.ruKeyboardToEn(rawQuery))

        var translit = launcher.transliterateRuToLatin(rawQuery)
        var phonetic = launcher.phoneticVariants(translit)
        for (var i = 0; i < phonetic.length; i++)
            launcher.addUnique(variants, phonetic[i])

        return variants
    }

    function appSearchParts(app) {
        var execBase = (app.exec || "").split(" ")[0].split("/").pop()
        return [
            app.name || "",
            app.genericName || "",
            app.comment || "",
            app.keywords || "",
            app.categories || "",
            app.icon || "",
            app.desktopId || "",
            execBase || ""
        ]
    }

    function acronymFor(text) {
        var words = launcher.normalizeSearchText(text).split(/\s+/)
        var out = ""
        for (var i = 0; i < words.length; i++) {
            if (words[i].length > 0)
                out += words[i][0]
        }
        return out
    }

    function fuzzySubsequenceScore(query, target) {
        if (query.length === 0)
            return 0

        var qi = 0
        var first = -1
        var last = -1
        for (var i = 0; i < target.length && qi < query.length; i++) {
            if (target[i] === query[qi]) {
                if (first < 0)
                    first = i
                last = i
                qi++
            }
        }

        if (qi !== query.length)
            return -1

        var span = last - first + 1
        return 70 + span - query.length + first
    }

    function scoreApp(app, rawQuery) {
        var variants = launcher.queryVariants(rawQuery)
        if (variants.length === 0)
            return 0

        var expandedQueries = variants.slice()
        for (var vi = 0; vi < variants.length; vi++) {
            var variant = variants[vi]
            var directAliases = launcher.searchAliases[launcher.compactSearchText(variant)] || launcher.searchAliases[variant]
            if (directAliases) {
                for (var a = 0; a < directAliases.length; a++)
                    launcher.addUnique(expandedQueries, directAliases[a])
            }
        }

        var best = 9999
        var parts = launcher.appSearchParts(app)
        for (var qi = 0; qi < expandedQueries.length; qi++) {
            var q = expandedQueries[qi]
            var cq = launcher.compactSearchText(q)
            for (var i = 0; i < parts.length; i++) {
                var normalized = launcher.normalizeSearchText(parts[i])
                var compact = launcher.compactSearchText(parts[i])
                var acronym = launcher.acronymFor(parts[i])

                if (normalized === q || compact === cq)
                    best = Math.min(best, qi === 0 ? 0 : 12)
                else if (normalized.indexOf(q) === 0 || compact.indexOf(cq) === 0)
                    best = Math.min(best, qi === 0 ? 10 : 18)
                else if (acronym === cq)
                    best = Math.min(best, qi === 0 ? 20 : 24)
                else if (acronym.indexOf(cq) === 0)
                    best = Math.min(best, qi === 0 ? 28 : 32)
                else if (normalized.indexOf(q) >= 0 || compact.indexOf(cq) >= 0)
                    best = Math.min(best, qi === 0 ? 40 : 44)
                else if (cq.length >= 4) {
                    var fuzzy = launcher.fuzzySubsequenceScore(cq, compact)
                    if (fuzzy >= 0 && fuzzy < 82)
                        best = Math.min(best, fuzzy + (qi * 8))
                }
            }
        }
        return best
    }

    function sameApp(a, b) {
        if (!a || !b)
            return false

        if ((a.exec || "") !== "" && a.exec === b.exec)
            return true
        if ((a.desktopId || "") !== "" && a.desktopId === b.desktopId)
            return true
        return (a.name || "") !== "" && a.name === b.name
    }

    function recentRank(app) {
        for (var i = 0; i < recentApps.length; i++) {
            if (launcher.sameApp(app, recentApps[i]))
                return i
        }
        return -1
    }

    function filterApps() {
        if (searchText === "") {
            filteredApps = allApps
            return
        }

        var ranked = []
        for (var i = 0; i < allApps.length; i++) {
            var score = launcher.scoreApp(allApps[i], searchText)
            if (score < 9999) {
                var rank = launcher.recentRank(allApps[i])
                ranked.push({
                    app: allApps[i],
                    score: score,
                    recentRank: rank,
                    effectiveScore: rank >= 0 ? score - Math.max(8, 36 - rank * 5) : score
                })
            }
        }

        ranked.sort(function(a, b) {
            if (a.effectiveScore !== b.effectiveScore)
                return a.effectiveScore - b.effectiveScore
            if (a.score !== b.score)
                return a.score - b.score
            if (a.recentRank !== b.recentRank) {
                if (a.recentRank < 0) return 1
                if (b.recentRank < 0) return -1
                return a.recentRank - b.recentRank
            }
            return a.app.name.localeCompare(b.app.name)
        })

        var out = []
        var limit = Math.min(ranked.length, launcher.maxSearchResults)
        for (var j = 0; j < limit; j++)
            out.push(ranked[j].app)
        filteredApps = out
    }

    function toggle() {
        if (!isOpen) {
            searchText = ""
            filterApps()
            resetSelectionForEmptySearch()
            searchInput.text = ""
            resetLauncherScroll()
            if (allApps.length === 0 && !listProc.running)
                listProc.running = true
            focusTimer.restart()
            isOpen = true
        } else {
            isOpen = false
        }
    }

    function launchApp(cmd) {
        // Find app by exec and add to recent
        for (var i = 0; i < launcher.allApps.length; i++) {
            if (launcher.allApps[i].exec === cmd) {
                launcher.addToRecent(launcher.allApps[i])
                break
            }
        }
        Hyprland.dispatch("hl.dsp.exec_cmd(" + launcher.luaQuote(cmd) + ")")
        isOpen = false
    }

    function luaQuote(value) {
        var text = String(value || "")
        return "\"" + text
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "\\r") + "\""
    }

    // full-screen background (transparent)
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.isOpen = false
        }
    }

    // popup Window Container
    Rectangle {
        id: popupWindow
        width: 640
        height: Math.min(760, parent.height - 120)

        anchors {
            left: parent.left
            leftMargin: 16
            bottom: parent.bottom
            bottomMargin: 64
        }
        color: launcher.bgTint
        radius: 24
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        transformOrigin: Item.BottomLeft

        transform: Translate {
            id: launcherTranslate
            y: 30
        }

        opacity: 0

        states: [
            State {
                name: "visible"
                when: launcher.isOpen
                PropertyChanges { target: popupWindow;       opacity: 1.0 }
                PropertyChanges { target: launcherTranslate; y: 0 }
            },
            State {
                name: "hidden"
                when: !launcher.isOpen
                PropertyChanges { target: popupWindow;       opacity: 0 }
                PropertyChanges { target: launcherTranslate; y: 30 }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"; to: "visible"
                ParallelAnimation {
                    NumberAnimation {
                        target: popupWindow
                        property: "opacity"
                        duration: 240
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: launcherTranslate
                        property: "y"
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            },
            Transition {
                from: "visible"; to: "hidden"
                ParallelAnimation {
                    NumberAnimation {
                        target: popupWindow
                        property: "opacity"
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: launcherTranslate
                        property: "y"
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                }
            }
        ]

        // block clicks from dismissing
        MouseArea { anchors.fill: parent; onClicked: {} }

        // Search stays fixed; Recently used is an inline GridView header,
        // so it appears at the top of the app list and scrolls away with it.

            // search bar
            Rectangle {
                id: searchBar
                anchors {
                    top: parent.top; topMargin: 24
                    left: parent.left; leftMargin: 24
                    right: parent.right; rightMargin: 24
                }
                height: 48
                radius: 24
                color: launcher.searchBg
                border.color: launcher.searchBorder
                border.width: 1

                Row {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left; leftMargin: 16
                    }
                    spacing: 12

                    // Google-style "G" circle
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: Qt.rgba(0.26, 0.52, 0.96, 1.0)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "G"
                            font { pixelSize: 16; family: "Google Sans"; weight: Font.Bold }
                            color: "white"
                        }
                    }

                    TextInput {
                        id: searchInput
                        width: popupWindow.width - 120
                        anchors.verticalCenter: parent.verticalCenter
                        color: launcher.textPrimary
                        font { pixelSize: 15; family: "Google Sans" }
                        clip: true
                        selectByMouse: true
                        selectionColor: Qt.rgba(0.40, 0.60, 1.0, 0.30)

                        onTextChanged: {
                            launcher.searchText = text
                            launcher.activeIndex = 0
                            launcher.recentIndex = 0
                            launcher.filterApps()
                            launcher.activeSection = text === "" && launcher.recentVisible() ? "recent" : "apps"
                        }

                        Keys.onEscapePressed: launcher.isOpen = false
                        
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Right || event.key === Qt.Key_Left
                                    || event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                                event.accepted = launcher.moveSelection(event.key)
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (launcher.activeSection === "recent" && launcher.recentVisible())
                                    launcher.launchApp(launcher.recentApps[launcher.recentIndex].exec)
                                else if (launcher.filteredApps.length > 0)
                                    launcher.launchApp(launcher.filteredApps[launcher.activeIndex].exec)
                                event.accepted = true
                            }
                        }
                    }
                }

                // Placeholder
                Text {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left; leftMargin: 62
                    }
                    text: "Search your images, files, apps, and more..."
                    color: launcher.textSecondary
                    font { pixelSize: 15; family: "Google Sans" }
                    visible: searchInput.text === ""
                }
            }

            // Main app grid. This is the only scrollable launcher area.
            GridView {
                id: appScroll
                z: 1
                anchors {
                    top: searchBar.bottom
                    topMargin: 12
                    left: parent.left; leftMargin: 24
                    right: parent.right; rightMargin: 24
                    bottom: parent.bottom; bottomMargin: 24
                }
                clip: true
                model: launcher.filteredApps
                cellWidth: width / columns
                cellHeight: 110
                currentIndex: launcher.activeSection === "apps" ? launcher.activeIndex : -1
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                boundsMovement: Flickable.StopAtBounds
                flickDeceleration: 3600
                maximumFlickVelocity: 5200
                cacheBuffer: cellHeight * 2
                highlightMoveDuration: 110
                highlightRangeMode: GridView.NoHighlightRange

                readonly property int columns: 5
                readonly property bool scrolling: moving || dragging || flicking

                NumberAnimation {
                    id: wrapScrollAnimation
                    target: appScroll
                    property: "contentY"
                    duration: 130
                    easing.type: Easing.OutCubic
                }

                function ensureActiveVisible() {
                    if (launcher.filteredApps.length === 0) return
                    if (launcher.activeSection !== "apps") return
                    positionViewAtIndex(launcher.activeIndex, GridView.Contain)
                }

                function topContentY() {
                    return originY
                }

                function bottomContentY() {
                    return Math.max(originY, originY + contentHeight - height)
                }

                function animateContentY(value) {
                    wrapScrollAnimation.stop()
                    wrapScrollAnimation.to = Math.max(topContentY(), Math.min(value, bottomContentY()))
                    wrapScrollAnimation.restart()
                }

                function stopScrollAnimation() {
                    wrapScrollAnimation.stop()
                }

                function scrollToTop() {
                    animateContentY(topContentY())
                }

                function scrollToBottom() {
                    animateContentY(bottomContentY())
                }

                function scrollToIndex(index) {
                    positionViewAtIndex(index, GridView.Contain)
                }

                header: Item {
                    id: recentSection
                    width: appScroll.width
                    height: visible ? 150 : 0
                    visible: launcher.searchText === "" && launcher.recentApps.length > 0

                    Text {
                        id: recentLabel
                        anchors { top: parent.top; left: parent.left }
                        text: "Recently used"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font { pixelSize: 11; family: "Google Sans"; weight: Font.Medium; letterSpacing: 0.5 }
                    }

                    Row {
                        id: recentRow
                        anchors { top: recentLabel.bottom; topMargin: 8; left: parent.left; right: parent.right }
                        spacing: 4

                        Repeater {
                            model: launcher.recentApps

                            Item {
                                id: recentCell
                                property var rapp: launcher.recentApps[index]

                                width: (recentRow.width - 4 * 4) / 5
                                height: 110

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 16
                                    color: ((!appScroll.scrolling && recentMouse.containsMouse)
                                            || (launcher.activeSection === "recent" && index === launcher.recentIndex))
                                           ? launcher.hoverBg : "transparent"
                                    border.color: (launcher.activeSection === "recent" && index === launcher.recentIndex)
                                        ? Qt.rgba(1, 1, 1, 0.15)
                                        : "transparent"
                                    border.width: 1
                                    Behavior on color {
                                        enabled: !appScroll.scrolling
                                        ColorAnimation { duration: 80 }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Item {
                                        width: 56; height: 56
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 28
                                            color: Qt.rgba(1, 1, 1, 0.06)
                                            visible: recentIcon.status !== Image.Ready
                                        }

                                        Image {
                                            id: recentIcon
                                            anchors.centerIn: parent
                                            width: 44; height: 44
                                            sourceSize.width: 44
                                            sourceSize.height: 44
                                            source: {
                                                if (!recentCell.rapp) return "image://icon/application-x-executable";
                                                var path = recentCell.rapp.iconPath;
                                                if (path && path.length > 0) return "file://" + path;
                                                var icon = recentCell.rapp.icon || "application-x-executable";
                                                if (icon.startsWith("/")) return "file://" + icon;
                                                return "image://icon/" + icon;
                                            }
                                            asynchronous: true
                                            cache: true
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    Text {
                                        width: Math.min(100, recentCell.width - 12)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: recentCell.rapp ? recentCell.rapp.name : ""
                                        color: launcher.textPrimary
                                        font { pixelSize: 11; family: "Google Sans" }
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        horizontalAlignment: Text.AlignHCenter
                                        lineHeight: 1.15
                                    }
                                }

                                MouseArea {
                                    id: recentMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: launcher.launchApp(recentCell.rapp.exec)
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors { top: recentRow.bottom; topMargin: 12; left: parent.left; right: parent.right }
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }
                }

                delegate: Item {
                    id: cell
                    width: appScroll.cellWidth
                    height: appScroll.cellHeight

                    property var app: modelData

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: ((!appScroll.scrolling && cellMouse.containsMouse)
                               || (launcher.activeSection === "apps" && index === launcher.activeIndex))
                               ? launcher.hoverBg : "transparent"
                        border.color: (launcher.activeSection === "apps" && index === launcher.activeIndex)
                            ? Qt.rgba(1, 1, 1, 0.15)
                            : "transparent"
                        border.width: 1
                        Behavior on color {
                            enabled: !appScroll.scrolling
                            ColorAnimation { duration: 80 }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Item {
                            width: 56; height: 56
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 28
                                color: Qt.rgba(1, 1, 1, 0.06)
                                visible: appIcon.status !== Image.Ready
                            }

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 44; height: 44
                                sourceSize.width: 44
                                sourceSize.height: 44

                                source: {
                                    if (!cell.app) return "image://icon/application-x-executable";
                                    var path = cell.app.iconPath;
                                    if (path && path.length > 0) return "file://" + path;
                                    var icon = cell.app.icon || "application-x-executable";
                                    if (icon.startsWith("/")) return "file://" + icon;
                                    return "image://icon/" + icon;
                                }

                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Text {
                            width: Math.min(100, cell.width - 12)
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.app ? cell.app.name : ""
                            color: launcher.textPrimary
                            font { pixelSize: 11; family: "Google Sans" }
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.15
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: !appScroll.scrolling
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (cell.app) launcher.launchApp(cell.app.exec)
                    }
                }
            }



        Connections {
            target: launcher
            function onActiveIndexChanged() { appScroll.ensureActiveVisible() }
            function onFilteredAppsChanged() { appScroll.contentY = 0 }
        }
    }
}
