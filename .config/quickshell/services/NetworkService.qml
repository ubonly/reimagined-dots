pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string wifiName: "Wi-Fi"
    property int wifiSignal: -1
    property bool wifiRadioOn: false
    property bool wifiConnected: false
    property bool wifiHasInternet: true
    property string wifiStatus: "disconnected"
    property bool ethConnected: false
    property string ethName: ""
    property var knownNetworks: []
    property var unknownNetworks: []
    property string passwordError: ""
    property string _statusBuf: ""
    property string _scanBuf: ""
    property string _passwordBuf: ""
    property bool _passwordAttemptActive: false

    readonly property bool wifiOn: wifiRadioOn
    readonly property bool scanning: scanProc.running
    readonly property bool connecting: connectProc.running || passwordProc.running
    readonly property int statusBars: ethConnected ? 100
        : (!wifiRadioOn || !wifiConnected ? 0
            : (wifiSignal < 25 ? 1
                : (wifiSignal < 50 ? 2
                    : (wifiSignal < 75 ? 3 : 4))))

    signal passwordFinished(bool ok, string message)

    function sigLabel(signal) {
        if (signal < 0)
            return "Off"
        if (signal < 30)
            return "Weak"
        if (signal < 65)
            return "Medium"
        return "Strong"
    }

    function wifiIcon() {
        if (!wifiRadioOn)
            return "assets/icons/wifi-off.svg"
        if (!wifiConnected || !wifiHasInternet)
            return "assets/icons/signal-wifi-statusbar-not-connected.svg"
        if (wifiSignal >= 75)
            return "assets/icons/signal-wifi-4-bar.svg"
        if (wifiSignal >= 50)
            return "assets/icons/network-wifi-3-bar.svg"
        if (wifiSignal >= 25)
            return "assets/icons/network-wifi-2-bar.svg"
        return "assets/icons/network-wifi-1-bar.svg"
    }

    function wifiSubtitle() {
        if (!wifiRadioOn)
            return "Off"
        if (!wifiConnected)
            return "Not connected"
        if (!wifiHasInternet)
            return "No internet"
        return sigLabel(wifiSignal)
    }

    function update() {
        statusProc.running = false
        statusProc.running = true
    }

    function scan() {
        scanProc.running = false
        scanProc.running = true
    }

    function toggleWifi() {
        radioProc.command = wifiRadioOn
            ? ["nmcli", "radio", "wifi", "off"]
            : ["nmcli", "radio", "wifi", "on"]
        radioProc.running = false
        radioProc.running = true
    }

    function connectKnown(ssid) {
        if (!ssid || ssid.length === 0)
            return
        connectProc.command = ["nmcli", "con", "up", ssid]
        connectProc.running = false
        connectProc.running = true
    }

    function connectWithPassword(ssid, password) {
        if (!ssid || ssid.length === 0)
            return
        if (passwordProc.running)
            return
        passwordError = ""
        _passwordBuf = ""
        passwordProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
        _passwordAttemptActive = true
        passwordProc.running = true
    }

    Component.onCompleted: {
        update()
        scan()
    }

    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: function(_) {
                root.update()
                root.scan()
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.update()
    }

    Process {
        id: statusProc
        running: false
        command: ["bash", "-c",
            "eth=$(nmcli -t -f TYPE,STATE,NAME con show --active 2>/dev/null | awk -F: '/^802-3-ethernet:activated/{print $3; exit}'); " +
            "radio=$(nmcli -t -f WIFI general 2>/dev/null); " +
            "conn=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '/^yes/{print $2\"|\"$3;exit}'); " +
            "inet=$(nmcli -t -f CONNECTIVITY general 2>/dev/null); " +
            "echo \"ETH:${eth}|${radio}|${conn}|${inet}\""
        ]
        stdout: SplitParser {
            onRead: function(line) {
                root._statusBuf += line + "\n"
            }
        }
        onRunningChanged: {
            if (running) {
                root._statusBuf = ""
                return
            }

            var raw = root._statusBuf.trim().split("\n").pop() || ""
            var ethEnd = raw.indexOf("|")
            if (ethEnd < 0)
                return

            var ethPart = raw.substring(0, ethEnd)
            var rest = raw.substring(ethEnd + 1)
            var activeEthName = ethPart.indexOf("ETH:") === 0 ? ethPart.substring(4) : ""
            root.ethConnected = activeEthName.length > 0
            root.ethName = activeEthName

            var firstPipe = rest.indexOf("|")
            var lastPipe = rest.lastIndexOf("|")
            if (firstPipe < 0)
                return

            var radio = rest.substring(0, firstPipe)
            var connPart = rest.substring(firstPipe + 1, lastPipe)
            var inet = rest.substring(lastPipe + 1)

            root.wifiRadioOn = radio === "enabled"
            if (connPart && connPart.indexOf("|") >= 0) {
                var cp = connPart.split("|")
                root.wifiName = cp[0] || "Wi-Fi"
                root.wifiSignal = parseInt(cp[1]) || 0
                root.wifiConnected = true
            } else {
                root.wifiName = "Wi-Fi"
                root.wifiSignal = -1
                root.wifiConnected = false
            }
            root.wifiHasInternet = inet === "full"
            root.wifiStatus = !root.wifiRadioOn ? "disabled"
                : (root.wifiConnected ? (root.wifiHasInternet ? "connected" : "limited") : "disconnected")
        }
    }

    Process {
        id: scanProc
        running: false
        command: ["bash", "-c",
            "known=$(nmcli -t -f NAME con show 2>/dev/null | sort -u); " +
            "nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list --rescan no 2>/dev/null | " +
            "while IFS=: read ssid sig sec used; do " +
            "[ -z \"$ssid\" ] && continue; " +
            "is_known=$(echo \"$known\" | grep -qxF \"$ssid\" && echo 1 || echo 0); " +
            "echo \"${ssid}|${sig}|${sec}|${used}|${is_known}\"; " +
            "done | awk -F'|' '!seen[$1]++' | sort -t'|' -k5,5rn -k2,2rn"
        ]
        stdout: SplitParser {
            onRead: function(line) {
                root._scanBuf += line + "\n"
            }
        }
        onRunningChanged: {
            if (running) {
                root._scanBuf = ""
                return
            }

            var lines = root._scanBuf.trim().split("\n")
            var known = []
            var unknown = []
            for (var i = 0; i < lines.length; i++) {
                var p = lines[i].split("|")
                if (p.length < 5)
                    continue
                var entry = {
                    ssid: p[0],
                    signal: parseInt(p[1]) || 0,
                    security: p[2] || "",
                    inUse: p[3] === "*",
                    isKnown: p[4] === "1"
                }
                if (entry.isKnown)
                    known.push(entry)
                else
                    unknown.push(entry)
            }

            known.sort(function(a, b) {
                var aConn = root.wifiConnected && a.ssid === root.wifiName
                var bConn = root.wifiConnected && b.ssid === root.wifiName
                if (aConn !== bConn)
                    return aConn ? -1 : 1
                return b.signal - a.signal
            })
            root.knownNetworks = known
            root.unknownNetworks = unknown
        }
    }

    Process {
        id: radioProc
        command: []
        running: false
        onRunningChanged: {
            if (!running) {
                root.update()
                root.scan()
            }
        }
    }

    Process {
        id: connectProc
        command: []
        running: false
        onRunningChanged: {
            if (!running) {
                root.update()
                root.scan()
            }
        }
    }

    Process {
        id: passwordProc
        command: []
        running: false
        stdout: SplitParser { onRead: function(line) { root._passwordBuf += line + "\n" } }
        stderr: SplitParser { onRead: function(line) { root._passwordBuf += line + "\n" } }
        onRunningChanged: {
            if (running)
                return
            if (!root._passwordAttemptActive)
                return
            root._passwordAttemptActive = false

            var output = root._passwordBuf.toLowerCase()
            root._passwordBuf = ""
            var failed = output.indexOf("error") !== -1
                || output.indexOf("failed") !== -1
                || output.indexOf("secrets") !== -1
                || output.indexOf("wrong") !== -1
            if (failed) {
                root.passwordError = "Неверный пароль или ошибка подключения"
                root.passwordFinished(false, root.passwordError)
            } else {
                root.passwordError = ""
                root.passwordFinished(true, "")
                root.update()
                root.scan()
            }
        }
    }
}
