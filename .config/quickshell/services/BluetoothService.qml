pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property bool available: Bluetooth.adapters.values.length > 0
    readonly property bool btOn: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property bool isScanning: Bluetooth.defaultAdapter?.discovering ?? false

    // Sorting helper
    function sortFunction(a, b) {
        // Connected devices first
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;

        // Paired devices next
        if (a.paired !== b.paired)
            return a.paired ? -1 : 1;

        // Real names before raw MAC addresses
        const macRegex = /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/;
        const aIsMac = macRegex.test(a.name || "");
        const bIsMac = macRegex.test(b.name || "");
        if (aIsMac !== bIsMac)
            return aIsMac ? 1 : -1;

        // Alphabetical by name
        return (a.name || "").localeCompare(b.name || "");
    }

    // List of all devices, sorted
    property var devices: {
        var list = [];
        var values = Bluetooth.devices.values;
        for (var i = 0; i < values.length; i++) {
            var dev = values[i];
            if (dev.name || dev.address) {
                list.push(dev);
            }
        }
        return list.sort(sortFunction);
    }

    function togglePower() {
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
        }
    }

    function startDiscovery() {
        if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) {
            Bluetooth.defaultAdapter.discovering = true;
        }
    }

    function stopDiscovery() {
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = false;
        }
    }

    function toggleConnect(device) {
        if (device) {
            if (device.connected) {
                device.disconnect();
            } else {
                device.connect();
            }
        }
    }

    function pairDevice(device) {
        if (device) {
            device.pair();
        }
    }

    function forgetDevice(device) {
        if (device) {
            device.forget();
        }
    }
}
