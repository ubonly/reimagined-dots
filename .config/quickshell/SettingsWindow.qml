// SettingsWindow.qml — ChromeOS-style System Settings
// Two-pane layout: left sidebar navigation + right content area.
// Catppuccin Mocha palette, Material Symbols SVG icons.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "Theme"
import "services"

FloatingWindow {
    id: settingsRoot
    property var  screenRef
    property bool settingsVisible: false
    signal openWallpaperBrowser()

    title: "Settings"
    implicitWidth: 920
    implicitHeight: 620
    color: bgColor
    visible: settingsVisible
    
    // Sync visibility state if closed via WM
    onVisibleChanged: {
        if (!visible && settingsVisible) {
            settingsVisible = false;
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  PALETTE (Mapped from Theme)
    // ══════════════════════════════════════════════════════════════════════
    readonly property color bgColor:       Theme.bgColor
    readonly property color cardBg:        Theme.cardBg
    readonly property color activeItem:    Theme.activeItem
    readonly property color activeBg:      Theme.activeBg
    readonly property color textPrimary:   Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color dividerColor:  Theme.dividerColor
    readonly property color searchBg:      Theme.searchBg
    readonly property color switchOnColor: Theme.switchOnColor
    readonly property color switchOffColor:Theme.switchOffColor
    readonly property color switchKnob:    Theme.switchKnob

    // ══════════════════════════════════════════════════════════════════════
    //  STATE
    // ══════════════════════════════════════════════════════════════════════
    property int    currentPage: 3
    property bool   _settingsPageRestored: false
    readonly property string themeMode: ConfigService.ready ? ConfigService.values.themeMode : "dark"
    readonly property string dockStyle: ConfigService.ready && ConfigService.values.dockStyle === "square" ? "square" : "rounded"
    readonly property bool dockTransparencyEnabled: ConfigService.ready ? ConfigService.values.dockTransparencyEnabled : false
    readonly property real dockOpacity: ConfigService.ready ? ConfigService.values.dockOpacity : 0.85
    readonly property bool dockIconFillEnabled: ConfigService.ready ? ConfigService.values.dockIconFillEnabled : false
    readonly property string dockLauncherIconMode: ConfigService.ready && ConfigService.values.dockLauncherIconMode === "distro" ? "distro" : "google"
    readonly property bool extraFeaturesEnabled: ConfigService.ready ? ConfigService.values.extraFeaturesEnabled : false
    readonly property string matugenScheme: ConfigService.ready ? ConfigService.values.matugenScheme : "auto"

    function updateDockStyle(style) {
        if (ConfigService.ready) ConfigService.values.dockStyle = style;
    }
    function updateDockTransparency(enabled) {
        if (ConfigService.ready) ConfigService.values.dockTransparencyEnabled = enabled;
    }
    function updateDockOpacity(value) {
        if (ConfigService.ready) ConfigService.values.dockOpacity = Math.max(0.2, Math.min(1.0, value));
    }
    function updateDockIconFillEnabled(enabled) {
        if (ConfigService.ready && settingsRoot.extraFeaturesEnabled) ConfigService.values.dockIconFillEnabled = enabled;
    }
    function updateDockLauncherIconMode(mode) {
        if (ConfigService.ready) ConfigService.values.dockLauncherIconMode = mode === "distro" ? "distro" : "google";
    }

    function setThemeMode(mode) {
        if (ConfigService.ready) {
            ConfigService.values.themeMode = mode;
            Quickshell.execDetached(["bash", ConfigService.configDir + "/set_theme_mode.sh", mode, settingsRoot.extraFeaturesEnabled ? settingsRoot.matugenScheme : "auto"]);
        }
    }

    function setMatugenScheme(scheme) {
        if (ConfigService.ready && settingsRoot.extraFeaturesEnabled) {
            ConfigService.values.matugenScheme = scheme;
            Quickshell.execDetached(["bash", ConfigService.configDir + "/set_theme_mode.sh", settingsRoot.themeMode, scheme]);
        }
    }

    function updateExtraFeaturesEnabled(enabled) {
        if (!ConfigService.ready)
            return;

        ConfigService.values.extraFeaturesEnabled = enabled;
        if (!enabled) {
            ConfigService.values.matugenScheme = "auto";
            ConfigService.values.dockIconFillEnabled = false;
            Quickshell.execDetached(["bash", ConfigService.configDir + "/set_theme_mode.sh", settingsRoot.themeMode, "auto"]);
        }
    }

    function openPath(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function clampSettingsPage(page) {
        var parsed = parseInt(page, 10);
        if (isNaN(parsed))
            return 3;
        return Math.max(2, Math.min(7, parsed));
    }

    function restoreSettingsPage() {
        if (!ConfigService.ready || _settingsPageRestored)
            return;

        currentPage = clampSettingsPage(ConfigService.values.settingsPage);
        _settingsPageRestored = true;
    }

    function closeSettings() {
        windowState.saveNow();
        settingsVisible = false;
    }

    Component.onCompleted: restoreSettingsPage()

    onCurrentPageChanged: {
        if (ConfigService.ready) {
            ConfigService.values.settingsPage = clampSettingsPage(currentPage);
        }
        if (currentPage === 2) {
            IntegrationService.refresh();
        }
    }

    Connections {
        target: ConfigService
        function onReadyChanged() {
            settingsRoot.restoreSettingsPage();
        }
    }

    FloatingWindowState {
        id: windowState
        windowTitle: "Settings"
        kind: "settings"
        active: settingsRoot.settingsVisible
    }

    // ══════════════════════════════════════════════════════════════════════
    //  SYSTEM METRICS & PREFERENCES PROCESSES
    // ══════════════════════════════════════════════════════════════════════
    Process {
        id: storageQueryProc
        property string storageUsed: "0 GB"
        property string storageTotal: "0 GB"
        property string storageFree: "0 GB"
        property string storageFs: "Unknown"
        property real storagePercent: 0.0

        command: ["bash", "-c", "df -hT /home | tail -n 1 | awk '{print $4 \"|\" $3 \"|\" $5 \"|\" $6 \"|\" $2}'"]
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 7
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split("|");
                if (parts.length >= 5) {
                    storageQueryProc.storageUsed = parts[0];
                    storageQueryProc.storageTotal = parts[1];
                    storageQueryProc.storageFree = parts[2];
                    var pct = parseFloat(parts[3].replace("%", "")) / 100.0;
                    storageQueryProc.storagePercent = isNaN(pct) ? 0.0 : pct;
                    storageQueryProc.storageFs = parts[4];
                }
            }
        }
    }

    Timer {
        interval: 10000; repeat: true
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 7
        triggeredOnStart: true
        onTriggered: storageQueryProc.running = true
    }

    Process {
        id: powerProfileQuery
        property string currentProfile: "balanced"

        command: ["bash", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl get || echo 'balanced'"]
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 6
        stdout: SplitParser {
            onRead: function(line) {
                powerProfileQuery.currentProfile = line.trim();
            }
        }

        function setProfile(profile) {
            powerProfileSetter.profileToSet = profile;
            powerProfileSetter.running = true;
        }
    }

    Process {
        id: powerProfileSetter
        property string profileToSet: ""
        command: ["bash", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl set " + profileToSet + " || true"]
        running: false
        onRunningChanged: {
            if (!running) {
                powerProfileQuery.running = true; // refresh
            }
        }
    }

    Timer {
        interval: 5000; repeat: true
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 6
        triggeredOnStart: true
        onTriggered: powerProfileQuery.running = true
    }

    Process {
        id: localeQuery
        property string rawLocale: "en_US.UTF-8"
        property string localeName: "English (United States)"

        command: ["bash", "-c", "echo $LANG"]
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 6
        stdout: SplitParser {
            onRead: function(line) {
                var lang = line.trim();
                localeQuery.rawLocale = lang;
                if (lang.indexOf("ru") === 0) {
                    localeQuery.localeName = "Русский (Россия)";
                } else if (lang.indexOf("en_US") === 0) {
                    localeQuery.localeName = "English (United States)";
                } else if (lang.indexOf("en_GB") === 0) {
                    localeQuery.localeName = "English (United Kingdom)";
                } else {
                    localeQuery.localeName = lang;
                }
            }
        }
    }

    Timer {
        interval: 30000; repeat: true
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 6
        triggeredOnStart: true
        onTriggered: localeQuery.running = true
    }

    Process {
        id: layoutQuery
        property string layouts: "us,ru"
        command: ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[0].rules' 2>/dev/null || echo 'us,ru'"]
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 6
        stdout: SplitParser {
            onRead: function(line) {
                layoutQuery.layouts = line.trim();
            }
        }
    }

    Timer {
        interval: 10000; repeat: true
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 6
        triggeredOnStart: true
        onTriggered: layoutQuery.running = true
    }

    Process {
        id: systemInfoQuery
        property string distro: "Unknown Linux"
        property string kernel: "Unknown"
        property string hyprlandVersion: "Unknown"
        property string quickshellVersion: "Unknown"
        property string configVersion: "local"

        command: ["bash", "-lc", "source /etc/os-release 2>/dev/null || true; distro=${PRETTY_NAME:-${NAME:-Unknown Linux}}; kernel=$(uname -r); hypr=$(hyprctl version -j 2>/dev/null | jq -r .version 2>/dev/null || hyprctl version 2>/dev/null | head -n1 || echo Unknown); qsver=$(qs --version 2>/dev/null | head -n1 || quickshell --version 2>/dev/null | head -n1 || echo Unknown); commit=$(git -C /home/ubonly/reimagined-dots rev-parse --short HEAD 2>/dev/null || echo local); printf '%s|%s|%s|%s|%s\\n' \"$distro\" \"$kernel\" \"$hypr\" \"$qsver\" \"$commit\""]
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 7
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split("|");
                if (parts.length >= 5) {
                    systemInfoQuery.distro = parts[0];
                    systemInfoQuery.kernel = parts[1];
                    systemInfoQuery.hyprlandVersion = parts[2];
                    systemInfoQuery.quickshellVersion = parts[3];
                    systemInfoQuery.configVersion = parts[4];
                }
            }
        }
    }

    Timer {
        interval: 30000; repeat: true
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 7
        triggeredOnStart: true
        onTriggered: systemInfoQuery.running = true
    }

    // ══════════════════════════════════════════════════════════════════════
    //  HELPER: SVG icon with color overlay
    // ══════════════════════════════════════════════════════════════════════
    component SvgIcon: Item {
        property string iconSource: ""
        property color  iconColor:  settingsRoot.textPrimary
        property int    iconSize:   20

        implicitWidth: iconSize; implicitHeight: iconSize

        Image {
            id: _svgImg
            anchors.fill: parent
            source: iconSource
            sourceSize: Qt.size(parent.width, parent.height)
            visible: false
        }
        ColorOverlay {
            anchors.fill: _svgImg
            source: _svgImg
            color: parent.iconColor
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  INLINE COMPONENTS
    // ══════════════════════════════════════════════════════════════════════

    // ── SettingsRow ─────────────────────────────────────────────────────
    component SettingsRow: Rectangle {
        id: srow
        property string iconSource: ""
        property string title:     ""
        property string subtitle:  ""
        property bool   hasSwitch: false
        property bool   switchVal: false
        property bool   hasChevron: false
        property bool   showDivider: true
        signal switchToggled()
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 60
        color: rowArea.containsMouse ? Qt.rgba(1,1,1,0.03) : "transparent"
        radius: 12
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 14

            Rectangle {
                visible: srow.iconSource !== ""
                Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20
                color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.05)
                SvgIcon {
                    anchors.centerIn: parent
                    iconSource: srow.iconSource; iconSize: 20
                    iconColor: settingsRoot.textPrimary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text {
                    text: srow.title; font.pixelSize: 13
                    font.family: "Google Sans"; font.weight: Font.Medium
                    color: settingsRoot.textPrimary
                }
                Text {
                    text: srow.subtitle; font.pixelSize: 11
                    font.family: "Google Sans"
                    color: settingsRoot.textSecondary
                    visible: srow.subtitle !== ""
                }
            }

            SvgIcon {
                visible: srow.hasChevron
                iconSource: "assets/icons/chevron-right.svg"
                iconSize: 20; iconColor: settingsRoot.textSecondary
            }

            Rectangle {
                visible: srow.hasSwitch
                implicitWidth: 44; implicitHeight: 24; radius: 12
                color: srow.switchVal ? settingsRoot.switchOnColor : settingsRoot.switchOffColor
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 18; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: srow.switchVal ? parent.width - width - 3 : 3
                    color: settingsRoot.switchKnob
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: srow.switchToggled()
                }
            }
        }

        Rectangle {
            visible: srow.showDivider
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                      leftMargin: 66; rightMargin: 16 }
            height: 1; color: settingsRoot.dividerColor
        }

        MouseArea {
            id: rowArea; anchors.fill: parent; z: -1
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: srow.clicked()
        }
    }

    component InfoRow: RowLayout {
        id: irow
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        implicitHeight: 42
        spacing: 16

        Text {
            text: irow.label
            font.pixelSize: 14
            font.family: "Google Sans"
            font.weight: Font.Medium
            color: settingsRoot.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Text {
            text: irow.value
            font.pixelSize: 12
            font.family: "Google Sans"
            color: settingsRoot.textSecondary
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 360
        }
    }

    component ActionButton: Rectangle {
        id: abtn
        property string label: ""
        property bool primary: false
        property bool enabled: true
        signal clicked()

        implicitWidth: Math.max(96, btnLabel.implicitWidth + 28)
        implicitHeight: 34
        radius: 17
        opacity: enabled ? 1.0 : 0.45
        color: primary
               ? settingsRoot.textPrimary
               : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, btnMouse.containsMouse ? 0.12 : 0.07)
        border.width: primary ? 0 : 1
        border.color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.08)
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            id: btnLabel
            anchors.centerIn: parent
            text: abtn.label
            color: abtn.primary ? Theme.bgColor : settingsRoot.textPrimary
            font.pixelSize: 12
            font.family: "Google Sans"
            font.weight: Font.Medium
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: abtn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: abtn.clicked()
        }
    }

    component StatusPill: Rectangle {
        id: pill
        property string label: ""
        property bool active: false

        implicitWidth: pillText.implicitWidth + 20
        implicitHeight: 26
        radius: 13
        color: active
               ? Qt.rgba(settingsRoot.activeItem.r, settingsRoot.activeItem.g, settingsRoot.activeItem.b, 0.18)
               : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.07)
        border.width: 1
        border.color: active
                      ? Qt.rgba(settingsRoot.activeItem.r, settingsRoot.activeItem.g, settingsRoot.activeItem.b, 0.25)
                      : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.08)

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: active ? settingsRoot.activeItem : settingsRoot.textSecondary
            font.pixelSize: 11
            font.family: "Google Sans"
            font.weight: Font.Medium
        }
    }

    // ── ThemeCard (Cloud) ──────────────────────────────────────────────────
    component ThemeCard: Rectangle {
        id: tCard
        property bool isDark: false
        property bool isActive: false
        property string titleText: ""

        // Derived colors for the preview
        property color previewBg: isDark ? Qt.rgba(0.12, 0.12, 0.14, 1.0) : Qt.rgba(0.96, 0.96, 0.98, 1.0)
        property color previewFg: isDark ? Qt.rgba(0.2, 0.2, 0.25, 1.0) : Qt.rgba(0.85, 0.85, 0.9, 1.0)

        Layout.fillWidth: true
        Layout.minimumHeight: 180
        implicitHeight: 180
        radius: 16
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            // Preview Box (the "cloud")
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: tCard.previewBg
                border.color: tCard.isActive ? Theme.primary : Qt.rgba(1,1,1,0.1)
                border.width: tCard.isActive ? 2 : 1
                clip: true

                // Skeleton items inside
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // App row
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: tCard.previewFg
                        }
                        ColumnLayout {
                            spacing: 4
                            Rectangle {
                                Layout.fillWidth: true; Layout.minimumWidth: 80; height: 12
                                radius: 4; color: tCard.previewFg
                            }
                            Rectangle {
                                width: 50; height: 8
                                radius: 4; color: tCard.previewFg
                            }
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true; height: 8
                        radius: 4; color: tCard.previewFg
                        Rectangle {
                            width: parent.width * 0.7; height: 8
                            radius: 4; color: tCard.isActive ? Theme.primary : Qt.darker(tCard.previewFg, 1.2)
                        }
                    }

                    // Toolbar
                    RowLayout {
                        spacing: 4
                        Rectangle {
                            Layout.fillWidth: true; height: 24
                            radius: 12; color: tCard.isActive ? Theme.primary : tCard.previewFg
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                font.pixelSize: 14; font.bold: true
                                color: tCard.previewBg
                                visible: tCard.isActive
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 24
                            radius: 6; color: tCard.isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : tCard.previewFg
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 24
                            radius: 6; color: tCard.isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : tCard.previewFg
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsRoot.setThemeMode(tCard.isDark ? "dark" : "light")
                }
            }

            // Title
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tCard.titleText
                color: tCard.isActive ? Theme.primary : settingsRoot.textPrimary
                font { pixelSize: 13; family: "Google Sans"; weight: Font.Medium }
            }
        }
    }

    // ── NavItem ─────────────────────────────────────────────────────────
    component NavItem: Rectangle {
        id: navItem
        property string navIconSource: ""
        property string navTitle: ""
        property string navSub:   ""
        property int    navIndex: 0
        property bool   isActive: settingsRoot.currentPage === navIndex

        Layout.fillWidth: true
        implicitHeight: 48
        radius: 14
        color: isActive ? settingsRoot.activeBg
             : (navMA.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent")
        Behavior on color { ColorAnimation { duration: 130 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 10

            SvgIcon {
                iconSource: navItem.navIconSource; iconSize: 20
                iconColor: navItem.isActive ? Theme.colorOnPrimaryContainer : settingsRoot.textPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text {
                    text: navItem.navTitle
                    font.pixelSize: 13; font.family: "Google Sans"
                    font.weight: Font.Medium
                    color: navItem.isActive ? Theme.colorOnPrimaryContainer : settingsRoot.textPrimary
                }
                Text {
                    text: navItem.navSub
                    font.pixelSize: 10; font.family: "Google Sans"
                    color: navItem.isActive
                        ? Qt.rgba(Theme.colorOnPrimaryContainer.r, Theme.colorOnPrimaryContainer.g, Theme.colorOnPrimaryContainer.b, 0.70)
                        : settingsRoot.textSecondary
                    visible: navItem.navSub !== ""
                }
            }
        }

        MouseArea {
            id: navMA; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: settingsRoot.currentPage = navItem.navIndex
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  MAIN LAYOUT
    // ══════════════════════════════════════════════════════════════════════

    // Escape to close
    Shortcut {
        sequence: "Escape"
        onActivated: settingsRoot.closeSettings()
    }

    Rectangle {
        id: mainWindow
        anchors.fill: parent
        color:  "transparent"

        // ── Window close button ──────────────────────────────────────────
        Rectangle {
            z: 10
            anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 12 }
            width: 28; height: 28; radius: 14
            color: closeBtnMA.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            SvgIcon {
                anchors.centerIn: parent
                iconSource: "assets/icons/close.svg"
                iconSize: 16; iconColor: settingsRoot.textPrimary
            }
            MouseArea {
                id: closeBtnMA; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: settingsRoot.closeSettings()
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ══════════════════════════════════════════════════════════════
            //  LEFT SIDEBAR
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: "transparent"

                Flickable {
                    anchors {
                        fill: parent
                        topMargin: 16; leftMargin: 12
                        rightMargin: 8; bottomMargin: 12
                    }
                    contentHeight: sidebarCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: sidebarCol
                        width: parent.width
                        spacing: 2

                        // Title
                        Text {
                            text: "Settings"
                            font.pixelSize: 20; font.family: "Google Sans"
                            font.weight: Font.Bold
                            color: settingsRoot.activeItem
                            Layout.leftMargin: 4
                            Layout.bottomMargin: 10
                        }



                        NavItem { navIconSource: "assets/icons/devices-other.svg";      navTitle: "Integrations";        navSub: "Sync, phone, providers";       navIndex: 2 }
                        NavItem { navIconSource: "assets/icons/wallpaper.svg";          navTitle: "Wallpaper and style"; navSub: "Dark theme, screen saver";     navIndex: 3 }
                        NavItem { navIconSource: "assets/icons/apps.svg";               navTitle: "Dock";                navSub: "Shelf style and behavior";     navIndex: 4 }
                        NavItem { navIconSource: "assets/icons/accessibility.svg";      navTitle: "Accessibility";       navSub: "Screen reader, magnification"; navIndex: 5 }
                        NavItem { navIconSource: "assets/icons/build.svg";              navTitle: "System preferences";  navSub: "Power, language, features";    navIndex: 6 }
                        NavItem { navIconSource: "assets/icons/info.svg";               navTitle: "About your system";   navSub: "Version, storage, config";     navIndex: 7 }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // Vertical separator
            Rectangle {
                Layout.preferredWidth: 1; Layout.fillHeight: true
                Layout.topMargin: 16; Layout.bottomMargin: 16
                color: settingsRoot.dividerColor
            }

            // ══════════════════════════════════════════════════════════════
            //  RIGHT CONTENT AREA
            // ══════════════════════════════════════════════════════════════
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors {
                        fill: parent
                        topMargin: 44; leftMargin: 20
                        rightMargin: 20; bottomMargin: 16
                    }
                    spacing: 14


                    // ── Content card ──────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20
                        color: settingsRoot.cardBg
                        clip: true

                        Flickable {
                            anchors {
                                fill: parent
                                topMargin: 8; bottomMargin: 8
                                leftMargin: 4; rightMargin: 4
                            }
                            contentHeight: contentCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: contentCol
                                width: parent.width
                                spacing: 0





                                // ═══════════════════════════════════════
                                //  PAGES 2+: PLACEHOLDER
                                // ═══════════════════════════════════════
                                ColumnLayout {
                                    visible: settingsRoot.currentPage >= 2
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: {
                                            var titles = ["","","Integrations","Wallpaper and style",
                                                "Dock","Accessibility","System preferences","About your system"]
                                            return titles[settingsRoot.currentPage] || "Settings"
                                        }
                                        font.pixelSize: 15; font.family: "Google Sans"
                                        font.weight: 600
                                        color: settingsRoot.textPrimary
                                        Layout.leftMargin: 16; Layout.topMargin: 8
                                        Layout.bottomMargin: 4
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: 120
                                         visible: settingsRoot.currentPage !== 2 && settingsRoot.currentPage !== 3 && settingsRoot.currentPage !== 4 && settingsRoot.currentPage !== 6 && settingsRoot.currentPage !== 7
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Coming soon"
                                            font.pixelSize: 13; font.family: "Google Sans"
                                            font.italic: true
                                            color: Qt.rgba(1,1,1,0.18)
                                        }
                                    }

                                    // PAGE 2: Integrations
                                    ColumnLayout {
                                        visible: settingsRoot.currentPage === 2
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Text {
                                            text: "Sync"
                                            font.pixelSize: 13; font.family: "Google Sans"; font.weight: Font.Bold
                                            color: settingsRoot.activeItem
                                            Layout.leftMargin: 12; Layout.topMargin: 8
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 10; Layout.rightMargin: 10
                                            implicitHeight: syncCol.implicitHeight + 32
                                            radius: 16
                                            color: Qt.rgba(1,1,1,0.03)
                                            border.color: Qt.rgba(1,1,1,0.05)
                                            border.width: 1

                                            ColumnLayout {
                                                id: syncCol
                                                anchors { fill: parent; margins: 16 }
                                                spacing: 14

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 10

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2
                                                        Text {
                                                            text: "Provider"
                                                            font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                            color: settingsRoot.textPrimary
                                                        }
                                                        Text {
                                                            text: "Only one provider can be active at a time"
                                                            font.pixelSize: 12; font.family: "Google Sans"
                                                            color: settingsRoot.textSecondary
                                                        }
                                                    }

                                                    RowLayout {
                                                        spacing: 8
                                                        Repeater {
                                                            model: IntegrationService.providers
                                                            delegate: Rectangle {
                                                                required property var modelData
                                                                property bool activeProvider: IntegrationService.activeProvider === modelData.id
                                                                property bool controlsLocked: IntegrationService.busy || IntegrationService.syncStatus.connecting || IntegrationService.syncStatus.connected

                                                                implicitWidth: providerLabel.implicitWidth + 26
                                                                implicitHeight: 32
                                                                radius: 16
                                                                color: activeProvider
                                                                       ? settingsRoot.textPrimary
                                                                       : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, providerMouse.containsMouse ? 0.12 : 0.06)
                                                                border.width: activeProvider ? 0 : 1
                                                                border.color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.08)
                                                                Behavior on color { ColorAnimation { duration: 140 } }

                                                                Text {
                                                                    id: providerLabel
                                                                    anchors.centerIn: parent
                                                                    text: modelData.displayName || modelData.id
                                                                    color: parent.activeProvider ? Theme.bgColor : settingsRoot.textPrimary
                                                                    font.pixelSize: 12
                                                                    font.family: "Google Sans"
                                                                    font.weight: Font.Medium
                                                                }

                                                                MouseArea {
                                                                    id: providerMouse
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    enabled: !parent.controlsLocked
                                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                                    onClicked: IntegrationService.selectSyncProvider(modelData.id)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Rectangle { Layout.fillWidth: true; height: 1; color: settingsRoot.dividerColor }

                                                InfoRow {
                                                    label: "Status"
                                                    value: IntegrationService.syncStatus.connecting
                                                           ? "Connecting..."
                                                           : (IntegrationService.syncStatus.connected ? "Connected" : "Not connected")
                                                }
                                                InfoRow {
                                                    visible: IntegrationService.syncStatus.connected
                                                    label: "Username"
                                                    value: IntegrationService.syncStatus.username
                                                }
                                                InfoRow {
                                                    visible: IntegrationService.syncStatus.connected
                                                    label: "Repository"
                                                    value: IntegrationService.syncStatus.repository
                                                }
                                                InfoRow {
                                                    visible: IntegrationService.syncStatus.connected
                                                    label: "Last sync"
                                                    value: IntegrationService.syncStatus.lastSync || "Never"
                                                }

                                                Text {
                                                    visible: IntegrationService.syncStatus.message !== "" || IntegrationService.error !== ""
                                                    Layout.fillWidth: true
                                                    text: IntegrationService.error !== "" ? IntegrationService.error : IntegrationService.syncStatus.message
                                                    font.pixelSize: 12
                                                    font.family: "Google Sans"
                                                    color: settingsRoot.textSecondary
                                                    wrapMode: Text.WordWrap
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Item { Layout.fillWidth: true }
                                                    ActionButton {
                                                        label: "Connect"
                                                        primary: true
                                                        visible: !IntegrationService.syncStatus.connected
                                                        enabled: !IntegrationService.busy && !IntegrationService.syncStatus.connecting && IntegrationService.activeProvider !== ""
                                                        onClicked: IntegrationService.connectSync(IntegrationService.activeProvider)
                                                    }
                                                    ActionButton {
                                                        label: "Sync now"
                                                        primary: true
                                                        visible: IntegrationService.syncStatus.connected
                                                        enabled: IntegrationService.syncStatus.connected && !IntegrationService.busy
                                                        onClicked: IntegrationService.syncNow()
                                                    }
                                                    ActionButton {
                                                        label: "Disconnect"
                                                        visible: IntegrationService.syncStatus.connected
                                                        enabled: IntegrationService.syncStatus.connected && !IntegrationService.busy
                                                        onClicked: IntegrationService.disconnectSync()
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Phone"
                                            font.pixelSize: 13; font.family: "Google Sans"; font.weight: Font.Bold
                                            color: settingsRoot.activeItem
                                            Layout.leftMargin: 12; Layout.topMargin: 8
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 10; Layout.rightMargin: 10
                                            implicitHeight: phoneCol.implicitHeight + 32
                                            radius: 16
                                            color: Qt.rgba(1,1,1,0.03)
                                            border.color: Qt.rgba(1,1,1,0.05)
                                            border.width: 1

                                            ColumnLayout {
                                                id: phoneCol
                                                anchors { fill: parent; margins: 16 }
                                                spacing: 14

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 12

                                                    Rectangle {
                                                        Layout.preferredWidth: 44
                                                        Layout.preferredHeight: 44
                                                        radius: 22
                                                        color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.08)
                                                        border.width: 1
                                                        border.color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.05)
                                                        SvgIcon {
                                                            anchors.centerIn: parent
                                                            iconSource: "assets/icons/devices.svg"
                                                            iconSize: 22
                                                            iconColor: settingsRoot.textPrimary
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2
                                                        Text {
                                                            text: "KDE Connect"
                                                            font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                            color: settingsRoot.textPrimary
                                                        }
                                                        Text {
                                                            text: IntegrationService.phoneStatus.message !== ""
                                                                  ? IntegrationService.phoneStatus.message
                                                                  : "Manage paired and reachable KDE Connect devices"
                                                            font.pixelSize: 12; font.family: "Google Sans"
                                                            color: settingsRoot.textSecondary
                                                            wrapMode: Text.WordWrap
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    StatusPill {
                                                        label: IntegrationService.phoneStatus.state === "unavailable"
                                                               ? "Unavailable"
                                                               : (IntegrationService.phoneStatus.state === "searching"
                                                                  ? "Searching"
                                                                  : (IntegrationService.phoneStatus.connected ? "Connected" : "Ready"))
                                                        active: IntegrationService.phoneStatus.connected
                                                    }
                                                }

                                                Rectangle { Layout.fillWidth: true; height: 1; color: settingsRoot.dividerColor }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Item { Layout.fillWidth: true }
                                                    ActionButton {
                                                        label: "Install KDE Connect"
                                                        primary: true
                                                        visible: !IntegrationService.phoneStatus.installed
                                                        enabled: !IntegrationService.busy
                                                        onClicked: IntegrationService.installKdeConnect()
                                                    }
                                                    ActionButton {
                                                        label: "Open KDE Connect"
                                                        primary: !IntegrationService.phoneStatus.connected
                                                        visible: IntegrationService.phoneStatus.installed
                                                        enabled: !IntegrationService.busy && IntegrationService.phoneStatus.canOpen
                                                        onClicked: IntegrationService.openKdeConnect()
                                                    }
                                                    ActionButton {
                                                        label: "Refresh"
                                                        visible: IntegrationService.phoneStatus.installed
                                                        enabled: !IntegrationService.busy && IntegrationService.phoneStatus.canRefresh
                                                        onClicked: IntegrationService.refreshPhone()
                                                    }
                                                }

                                                Text {
                                                    visible: IntegrationService.phoneStatus.installed
                                                             && IntegrationService.phoneStatus.daemonRunning
                                                             && (!IntegrationService.phoneStatus.devices || IntegrationService.phoneStatus.devices.length === 0)
                                                    Layout.fillWidth: true
                                                    text: "No KDE Connect devices were found."
                                                    font.pixelSize: 12
                                                    font.family: "Google Sans"
                                                    color: settingsRoot.textSecondary
                                                    wrapMode: Text.WordWrap
                                                }

                                                Repeater {
                                                    model: IntegrationService.phoneStatus.devices || []

                                                    delegate: Rectangle {
                                                        required property var modelData

                                                        Layout.fillWidth: true
                                                        implicitHeight: deviceCardCol.implicitHeight + 24
                                                        radius: 14
                                                        color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.04)
                                                        border.width: 1
                                                        border.color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.06)

                                                        ColumnLayout {
                                                            id: deviceCardCol
                                                            anchors { fill: parent; margins: 12 }
                                                            spacing: 10

                                                            RowLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 10

                                                                Rectangle {
                                                                    Layout.preferredWidth: 38
                                                                    Layout.preferredHeight: 38
                                                                    radius: 19
                                                                    color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.08)
                                                                    SvgIcon {
                                                                        anchors.centerIn: parent
                                                                        iconSource: "assets/icons/devices.svg"
                                                                        iconSize: 20
                                                                        iconColor: settingsRoot.textPrimary
                                                                    }
                                                                }

                                                                ColumnLayout {
                                                                    Layout.fillWidth: true
                                                                    spacing: 2
                                                                    Text {
                                                                        text: modelData.name || "Unknown device"
                                                                        font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                                        color: settingsRoot.textPrimary
                                                                        elide: Text.ElideRight
                                                                        Layout.fillWidth: true
                                                                    }
                                                                    Text {
                                                                        text: modelData.deviceType || "Unknown"
                                                                        font.pixelSize: 12; font.family: "Google Sans"
                                                                        color: settingsRoot.textSecondary
                                                                    }
                                                                }

                                                                StatusPill {
                                                                    label: modelData.status || "Device found"
                                                                    active: modelData.state === "connected"
                                                                }
                                                            }

                                                            Text {
                                                                visible: modelData.batteryAvailable === true
                                                                Layout.fillWidth: true
                                                                text: "Battery " + modelData.batteryLevel + "%" + (modelData.charging ? " • Charging" : "")
                                                                font.pixelSize: 12
                                                                font.family: "Google Sans"
                                                                color: settingsRoot.textSecondary
                                                            }

                                                            RowLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 8
                                                                Item { Layout.fillWidth: true }

                                                                ActionButton {
                                                                    label: "Pair"
                                                                    primary: true
                                                                    visible: !modelData.paired
                                                                    enabled: modelData.actions && modelData.actions.pair && !IntegrationService.busy
                                                                    onClicked: IntegrationService.pairPhone(modelData.id)
                                                                }
                                                                ActionButton {
                                                                    label: "Send File"
                                                                    visible: modelData.paired
                                                                    enabled: modelData.actions && modelData.actions.sendFile && !IntegrationService.busy
                                                                    onClicked: IntegrationService.sendFilePhone(modelData.id)
                                                                }
                                                                ActionButton {
                                                                    label: "Ping"
                                                                    visible: modelData.paired
                                                                    enabled: modelData.actions && modelData.actions.ping && !IntegrationService.busy
                                                                    onClicked: IntegrationService.pingPhone(modelData.id)
                                                                }
                                                                ActionButton {
                                                                    label: "Unpair"
                                                                    visible: modelData.paired
                                                                    enabled: modelData.actions && modelData.actions.unpair && !IntegrationService.busy
                                                                    onClicked: IntegrationService.unpairPhone(modelData.id)
                                                                }
                                                                ActionButton {
                                                                    label: "Disconnect"
                                                                    visible: modelData.paired
                                                                    enabled: modelData.actions && modelData.actions.disconnect && !IntegrationService.busy
                                                                    onClicked: IntegrationService.disconnectPhone(modelData.id)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // PAGE 3: Wallpaper and style
                                    ColumnLayout {
                                        visible: settingsRoot.currentPage === 3
                                        Layout.fillWidth: true
                                        spacing: 12
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 10; Layout.rightMargin: 10
                                            Layout.topMargin: 10
                                            implicitHeight: wallCol.implicitHeight
                                            radius: 16
                                            color: Qt.rgba(1,1,1,0.03)
                                            border.color: Qt.rgba(1,1,1,0.05)
                                            border.width: 1

                                            ColumnLayout {
                                                id: wallCol
                                                anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
                                                spacing: 0

                                                SettingsRow {
                                                    iconSource: "assets/icons/wallpaper.svg"
                                                    title: "Pick wallpaper image"
                                                    subtitle: "Browse local wallpaper collections"
                                                    hasChevron: true
                                                    showDivider: true
                                                    onClicked: settingsRoot.openWallpaperBrowser()
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.margins: 16
                                                    spacing: 16
                                                    
                                                    ThemeCard {
                                                        isDark: false
                                                        isActive: settingsRoot.themeMode === "light"
                                                        titleText: "Light"
                                                    }
                                                    
                                                    ThemeCard {
                                                        isDark: true
                                                        isActive: settingsRoot.themeMode === "dark"
                                                        titleText: "Dark"
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.leftMargin: 16; Layout.rightMargin: 16
                                                    height: 1
                                                    color: settingsRoot.dividerColor
                                                    visible: settingsRoot.extraFeaturesEnabled
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.topMargin: 8; Layout.bottomMargin: 16
                                                    spacing: 12
                                                    visible: settingsRoot.extraFeaturesEnabled

                                                    Text {
                                                        text: "Matugen color scheme"
                                                        font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                        color: settingsRoot.textPrimary
                                                    }

                                                    GridLayout {
                                                        columns: 3
                                                        rowSpacing: 8
                                                        columnSpacing: 8
                                                        Layout.fillWidth: true

                                                        Repeater {
                                                            model: [
                                                                { name: "Auto", value: "auto" },
                                                                { name: "Content", value: "scheme-content" },
                                                                { name: "Expressive", value: "scheme-expressive" },
                                                                { name: "Fidelity", value: "scheme-fidelity" },
                                                                { name: "Fruit Salad", value: "scheme-fruit-salad" },
                                                                { name: "Monochrome", value: "scheme-monochrome" },
                                                                { name: "Neutral", value: "scheme-neutral" },
                                                                { name: "Rainbow", value: "scheme-rainbow" },
                                                                { name: "Tonal Spot", value: "scheme-tonal-spot" }
                                                            ]

                                                            delegate: Rectangle {
                                                                property bool isActive: settingsRoot.matugenScheme === modelData.value
                                                                Layout.fillWidth: true
                                                                height: 36
                                                                radius: 18
                                                                color: isActive ? settingsRoot.textPrimary : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.05)
                                                                border.color: isActive ? "transparent" : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.1)
                                                                border.width: 1

                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: modelData.name
                                                                    font.pixelSize: 12; font.family: "Google Sans"; font.weight: 500
                                                                    color: isActive ? settingsRoot.bgColor : settingsRoot.textPrimary
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: settingsRoot.setMatugenScheme(modelData.value)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.leftMargin: 16; Layout.rightMargin: 16
                                                    height: 1
                                                    color: settingsRoot.dividerColor
                                                    visible: settingsRoot.extraFeaturesEnabled
                                                }

                                                SettingsRow {
                                                    iconSource: "assets/icons/image-fill.svg"
                                                    title: "Random Konachan wallpaper"
                                                    subtitle: "Downloads a random anime wallpaper"
                                                    hasChevron: true
                                                    showDivider: true
                                                    visible: settingsRoot.extraFeaturesEnabled
                                                    onClicked: {
                                                        Quickshell.execDetached(["bash", ConfigService.configDir + "/random_konachan.sh"])
                                                    }
                                                }
                                                SettingsRow {
                                                    iconSource: "assets/icons/image-fill.svg"
                                                    title: "Random osu! wallpaper"
                                                    subtitle: "Downloads a random osu! seasonal background"
                                                    hasChevron: true
                                                    showDivider: false
                                                    visible: settingsRoot.extraFeaturesEnabled
                                                    onClicked: {
                                                        Quickshell.execDetached(["bash", ConfigService.configDir + "/random_osu.sh"])
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // PAGE 4: Dock
                                    ColumnLayout {
                                        visible: settingsRoot.currentPage === 4
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 10; Layout.rightMargin: 10
                                            Layout.topMargin: 10
                                            implicitHeight: dockCol.implicitHeight
                                            radius: 16
                                            color: Qt.rgba(1,1,1,0.03)
                                            border.color: Qt.rgba(1,1,1,0.05)
                                            border.width: 1

                                            ColumnLayout {
                                                id: dockCol
                                                anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
                                                spacing: 0

                                                Item {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 80
                                                    RowLayout {
                                                        anchors { fill: parent; leftMargin: 66; rightMargin: 16; topMargin: 16; bottomMargin: 16 }
                                                        spacing: 16

                                                        Text {
                                                            text: "Dock style"
                                                            font.pixelSize: 14; font.family: "Google Sans"
                                                            color: settingsRoot.textPrimary
                                                            Layout.alignment: Qt.AlignVCenter
                                                        }

                                                        Item { Layout.fillWidth: true }

                                                        RowLayout {
                                                            spacing: 8

                                                            Repeater {
                                                                model: [
                                                                    { name: "Rounded", value: "rounded" },
                                                                    { name: "Square", value: "square" }
                                                                    // Floating is intentionally hidden while the dock is matched to ChromeOS.
                                                                ]
                                                                delegate: Rectangle {
                                                                    property bool isActive: settingsRoot.dockStyle === modelData.value
                                                                    width: btnText.implicitWidth + 32
                                                                    height: 36
                                                                    radius: 18
                                                                    color: isActive ? settingsRoot.textPrimary : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.05)

                                                                    Text {
                                                                        id: btnText
                                                                        anchors.centerIn: parent
                                                                        text: modelData.name
                                                                        font.pixelSize: 13; font.family: "Google Sans"; font.weight: 500
                                                                        color: isActive ? settingsRoot.bgColor : settingsRoot.textPrimary
                                                                    }

                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: settingsRoot.updateDockStyle(modelData.value)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                /*
                                                 * Dock transparency is intentionally disabled for now.
                                                 * The ChromeOS-style shelf uses a fixed translucent surface instead.
                                                Item {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 0
                                                    visible: false
                                                    RowLayout {
                                                        anchors { fill: parent; leftMargin: 66; rightMargin: 16; topMargin: 0; bottomMargin: 16 }
                                                        spacing: 16

                                                        ColumnLayout {
                                                            spacing: 2
                                                            Layout.alignment: Qt.AlignVCenter

                                                            Text {
                                                                text: "Dock transparency"
                                                                font.pixelSize: 14; font.family: "Google Sans"
                                                                color: settingsRoot.textPrimary
                                                            }
                                                            Text {
                                                                text: settingsRoot.dockTransparencyEnabled ? "Enabled" : "Disabled"
                                                                font.pixelSize: 12; font.family: "Google Sans"
                                                                color: settingsRoot.textSecondary
                                                            }
                                                        }

                                                        Item { Layout.fillWidth: true }

                                                        Rectangle {
                                                            width: 52; height: 30; radius: 15
                                                            color: settingsRoot.dockTransparencyEnabled ? settingsRoot.switchOnColor : settingsRoot.switchOffColor

                                                            Rectangle {
                                                                width: 24; height: 24; radius: 12
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                x: settingsRoot.dockTransparencyEnabled ? parent.width - width - 3 : 3
                                                                color: settingsRoot.switchKnob
                                                                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: settingsRoot.updateDockTransparency(!settingsRoot.dockTransparencyEnabled)
                                                            }
                                                        }
                                                    }
                                                }
                                                */

                                                SettingsRow {
                                                    iconSource: "assets/icons/palette-outline.svg"
                                                    title: "Fill dock icons"
                                                    subtitle: "Tint dock app icons with the current theme color"
                                                    hasSwitch: true
                                                    switchVal: settingsRoot.dockIconFillEnabled
                                                    showDivider: false
                                                    visible: settingsRoot.extraFeaturesEnabled
                                                    onSwitchToggled: {
                                                        settingsRoot.updateDockIconFillEnabled(!settingsRoot.dockIconFillEnabled)
                                                    }
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 78
                                                    RowLayout {
                                                        anchors { fill: parent; leftMargin: 66; rightMargin: 16; topMargin: 14; bottomMargin: 14 }
                                                        spacing: 16

                                                        ColumnLayout {
                                                            spacing: 2
                                                            Layout.alignment: Qt.AlignVCenter

                                                            Text {
                                                                text: "Launcher icon"
                                                                font.pixelSize: 14; font.family: "Google Sans"
                                                                color: settingsRoot.textPrimary
                                                            }
                                                            Text {
                                                                text: "Choose the shelf launcher symbol"
                                                                font.pixelSize: 12; font.family: "Google Sans"
                                                                color: settingsRoot.textSecondary
                                                            }
                                                        }

                                                        Item { Layout.fillWidth: true }

                                                        RowLayout {
                                                            spacing: 8

                                                            Repeater {
                                                                model: [
                                                                    { name: "G", value: "google" },
                                                                    { name: "Distro", value: "distro" }
                                                                ]
                                                                delegate: Rectangle {
                                                                    property bool isActive: settingsRoot.dockLauncherIconMode === modelData.value
                                                                    width: btnText.implicitWidth + 32
                                                                    height: 36
                                                                    radius: 18
                                                                    color: isActive ? settingsRoot.textPrimary : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.05)

                                                                    Text {
                                                                        id: btnText
                                                                        anchors.centerIn: parent
                                                                        text: modelData.name
                                                                        font.pixelSize: 13; font.family: "Google Sans"; font.weight: 500
                                                                        color: isActive ? settingsRoot.bgColor : settingsRoot.textPrimary
                                                                    }

                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: settingsRoot.updateDockLauncherIconMode(modelData.value)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 0
                                                    visible: false

                                                    /*
                                                     * Dock opacity slider is disabled with the transparency toggle.
                                                    RowLayout {
                                                        anchors { fill: parent; leftMargin: 66; rightMargin: 16; topMargin: 0; bottomMargin: 14 }
                                                        spacing: 18

                                                        Text {
                                                            text: "Opacity"
                                                            font.pixelSize: 14; font.family: "Google Sans"
                                                            color: settingsRoot.textPrimary
                                                            Layout.alignment: Qt.AlignVCenter
                                                        }

                                                        Rectangle {
                                                            id: opacityTrack
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 8
                                                            radius: 4
                                                            color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.12)

                                                            function setFromMouse(mouseX) {
                                                                let normalized = Math.max(0, Math.min(1, mouseX / width));
                                                                settingsRoot.updateDockOpacity(0.2 + normalized * 0.8);
                                                            }

                                                            Rectangle {
                                                                anchors.left: parent.left
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                width: parent.width * ((settingsRoot.dockOpacity - 0.2) / 0.8)
                                                                height: parent.height
                                                                radius: parent.radius
                                                                color: settingsRoot.activeItem
                                                            }

                                                            Rectangle {
                                                                width: 20; height: 20; radius: 10
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                x: Math.max(0, Math.min(parent.width - width, parent.width * ((settingsRoot.dockOpacity - 0.2) / 0.8) - width / 2))
                                                                color: settingsRoot.textPrimary
                                                                border.color: settingsRoot.bgColor
                                                                border.width: 2
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                property bool dragging: false
                                                                onPressed: {
                                                                    dragging = true
                                                                    opacityTrack.setFromMouse(mouse.x)
                                                                }
                                                                onPositionChanged: {
                                                                    if (dragging)
                                                                        opacityTrack.setFromMouse(mouse.x)
                                                                }
                                                                onReleased: dragging = false
                                                                onCanceled: dragging = false
                                                            }
                                                        }

                                                        Text {
                                                            text: Math.round(settingsRoot.dockOpacity * 100) + "%"
                                                            font.pixelSize: 13; font.family: "Google Sans"; font.weight: 600
                                                            color: settingsRoot.textPrimary
                                                            horizontalAlignment: Text.AlignRight
                                                            Layout.preferredWidth: 44
                                                            Layout.alignment: Qt.AlignVCenter
                                                        }
                                                    }
                                                    */
                                                }
                                            }
                                        }
                                    }

                                     // PAGE 6: System Preferences
                                     ColumnLayout {
                                         visible: settingsRoot.currentPage === 6
                                         Layout.fillWidth: true
                                         spacing: 12

                                         // SECTION 1: Power
                                         Text {
                                             text: "Power"
                                             font.pixelSize: 13; font.family: "Google Sans"; font.weight: Font.Bold
                                             color: settingsRoot.activeItem
                                             Layout.leftMargin: 12; Layout.topMargin: 4
                                         }

                                         Rectangle {
                                             Layout.fillWidth: true
                                             Layout.leftMargin: 10; Layout.rightMargin: 10
                                             implicitHeight: storagePowerCol.implicitHeight + 32
                                             radius: 16
                                             color: Qt.rgba(1,1,1,0.03)
                                             border.color: Qt.rgba(1,1,1,0.05)
                                             border.width: 1

                                             ColumnLayout {
                                                 id: storagePowerCol
                                                 anchors { fill: parent; margins: 16 }
                                                 spacing: 16

                                                 // Power profile selection
                                                 RowLayout {
                                                     Layout.fillWidth: true
                                                     spacing: 12

                                                     ColumnLayout {
                                                         spacing: 2
                                                         Text {
                                                             text: "Power profile"
                                                             font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                             color: settingsRoot.textPrimary
                                                         }
                                                         Text {
                                                             text: "Select active system performance and battery profile"
                                                             font.pixelSize: 12; font.family: "Google Sans"
                                                             color: settingsRoot.textSecondary
                                                         }
                                                     }

                                                     Item { Layout.fillWidth: true }

                                                     RowLayout {
                                                         spacing: 8

                                                         Repeater {
                                                             model: [
                                                                 { name: "Performance", value: "performance" },
                                                                 { name: "Balanced", value: "balanced" },
                                                                 { name: "Power Saver", value: "power-saver" }
                                                             ]

                                                             delegate: Rectangle {
                                                                 property bool isActive: powerProfileQuery.currentProfile === modelData.value
                                                                 width: pBtnText.implicitWidth + 24
                                                                 height: 32
                                                                 radius: 16
                                                                 color: isActive ? settingsRoot.textPrimary : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.05)
                                                                 border.color: isActive ? "transparent" : Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.1)
                                                                 border.width: 1

                                                                 Text {
                                                                     id: pBtnText
                                                                     anchors.centerIn: parent
                                                                     text: modelData.name
                                                                     font.pixelSize: 12; font.family: "Google Sans"; font.weight: 500
                                                                     color: isActive ? Theme.bgColor : settingsRoot.textPrimary
                                                                 }

                                                                 MouseArea {
                                                                     anchors.fill: parent
                                                                     cursorShape: Qt.PointingHandCursor
                                                                     onClicked: {
                                                                         powerProfileQuery.setProfile(modelData.value)
                                                                     }
                                                                 }
                                                             }
                                                         }
                                                     }
                                                 }
                                             }
                                         }

                                         // SECTION 2: Languages & Clock
                                         Text {
                                             text: "Date, time and language"
                                             font.pixelSize: 13; font.family: "Google Sans"; font.weight: Font.Bold
                                             color: settingsRoot.activeItem
                                             Layout.leftMargin: 12; Layout.topMargin: 8
                                         }

                                         Rectangle {
                                             Layout.fillWidth: true
                                             Layout.leftMargin: 10; Layout.rightMargin: 10
                                             implicitHeight: dateLangCol.implicitHeight + 32
                                             radius: 16
                                             color: Qt.rgba(1,1,1,0.03)
                                             border.color: Qt.rgba(1,1,1,0.05)
                                             border.width: 1

                                             ColumnLayout {
                                                 id: dateLangCol
                                                 anchors { fill: parent; margins: 16 }
                                                 spacing: 16

                                                 // 24-hour clock
                                                 RowLayout {
                                                     Layout.fillWidth: true
                                                     ColumnLayout {
                                                         spacing: 2
                                                         Text {
                                                             text: "Use 24-hour clock"
                                                             font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                             color: settingsRoot.textPrimary
                                                         }
                                                         Text {
                                                             text: "Display format for the system clock"
                                                             font.pixelSize: 12; font.family: "Google Sans"
                                                             color: settingsRoot.textSecondary
                                                         }
                                                     }

                                                     Item { Layout.fillWidth: true }

                                                     Rectangle {
                                                         width: 52; height: 30; radius: 15
                                                         color: ConfigService.values.use24Hour ? settingsRoot.switchOnColor : settingsRoot.switchOffColor

                                                         Rectangle {
                                                             width: 24; height: 24; radius: 12
                                                             anchors.verticalCenter: parent.verticalCenter
                                                             x: ConfigService.values.use24Hour ? parent.width - width - 3 : 3
                                                             color: settingsRoot.switchKnob
                                                             Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                                         }

                                                         MouseArea {
                                                             anchors.fill: parent
                                                             cursorShape: Qt.PointingHandCursor
                                                             onClicked: {
                                                                 ConfigService.values.use24Hour = !ConfigService.values.use24Hour
                                                             }
                                                         }
                                                     }
                                                 }

                                                 Rectangle {
                                                     Layout.fillWidth: true; height: 1
                                                     color: settingsRoot.dividerColor
                                                 }

                                                  // Keyboard Layouts
                                                  RowLayout {
                                                      Layout.fillWidth: true
                                                      ColumnLayout {
                                                          spacing: 2
                                                          Text {
                                                              text: "Active keyboard layouts"
                                                              font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                              color: settingsRoot.textPrimary
                                                          }
                                                          Text {
                                                              text: "Configured layout rule: " + layoutQuery.layouts
                                                              font.pixelSize: 12; font.family: "Google Sans"
                                                              color: settingsRoot.textSecondary
                                                          }
                                                      }
                                                      Item { Layout.fillWidth: true }
                                                      Text {
                                                          text: "Active layout: " + root.kbLayout
                                                          font.pixelSize: 13; font.family: "Google Sans"; font.weight: 600
                                                          color: settingsRoot.activeItem
                                                      }
                                                  }

                                                  Rectangle {
                                                      Layout.fillWidth: true; height: 1
                                                      color: settingsRoot.dividerColor
                                                  }

                                                  // Interface Language
                                                  RowLayout {
                                                      Layout.fillWidth: true
                                                      ColumnLayout {
                                                          spacing: 2
                                                          Text {
                                                              text: "Interface language"
                                                              font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                              color: settingsRoot.textPrimary
                                                          }
                                                          Text {
                                                              text: "Locale: " + localeQuery.rawLocale
                                                              font.pixelSize: 12; font.family: "Google Sans"
                                                              color: settingsRoot.textSecondary
                                                          }
                                                      }
                                                      Item { Layout.fillWidth: true }
                                                      Text {
                                                          text: localeQuery.localeName
                                                          font.pixelSize: 13; font.family: "Google Sans"; font.weight: 600
                                                          color: settingsRoot.activeItem
                                                      }
                                                 }
                                             }
                                         }

                                         // SECTION 3: Advanced customization
                                         Text {
                                             text: "Advanced customization"
                                             font.pixelSize: 13; font.family: "Google Sans"; font.weight: Font.Bold
                                             color: settingsRoot.activeItem
                                             Layout.leftMargin: 12; Layout.topMargin: 8
                                         }

                                         Rectangle {
                                             Layout.fillWidth: true
                                             Layout.leftMargin: 10; Layout.rightMargin: 10
                                             implicitHeight: extraFeaturesCol.implicitHeight
                                             radius: 16
                                             color: Qt.rgba(1,1,1,0.03)
                                             border.color: Qt.rgba(1,1,1,0.05)
                                             border.width: 1

                                             ColumnLayout {
                                                 id: extraFeaturesCol
                                                 anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
                                                 spacing: 0

                                                 SettingsRow {
                                                     iconSource: "assets/icons/tune.svg"
                                                     title: "Advanced customization"
                                                     subtitle: settingsRoot.extraFeaturesEnabled
                                                               ? "Random wallpapers, icon tinting, and palette selection"
                                                               : "Uses automatic wallpaper color generation"
                                                     hasSwitch: true
                                                     switchVal: settingsRoot.extraFeaturesEnabled
                                                     showDivider: false
                                                     onSwitchToggled: {
                                                         settingsRoot.updateExtraFeaturesEnabled(!settingsRoot.extraFeaturesEnabled)
                                                     }
                                                 }
                                             }
                                         }
                                     }

                                     // PAGE 7: About your system
                                     ColumnLayout {
                                         visible: settingsRoot.currentPage === 7
                                         Layout.fillWidth: true
                                         spacing: 12

                                         Text {
                                             text: "System"
                                             font.pixelSize: 13; font.family: "Google Sans"; font.weight: Font.Bold
                                             color: settingsRoot.activeItem
                                             Layout.leftMargin: 12; Layout.topMargin: 4
                                         }

                                         Rectangle {
                                             Layout.fillWidth: true
                                             Layout.leftMargin: 10; Layout.rightMargin: 10
                                             implicitHeight: systemInfoCol.implicitHeight + 32
                                             radius: 16
                                             color: Qt.rgba(1,1,1,0.03)
                                             border.color: Qt.rgba(1,1,1,0.05)
                                             border.width: 1

                                             ColumnLayout {
                                                 id: systemInfoCol
                                                 anchors { fill: parent; margins: 16 }
                                                 spacing: 12

                                                 InfoRow { label: "Distribution"; value: systemInfoQuery.distro }
                                                 InfoRow { label: "Kernel"; value: systemInfoQuery.kernel }
                                                 InfoRow { label: "Hyprland"; value: systemInfoQuery.hyprlandVersion }
                                                 InfoRow { label: "QuickShell"; value: systemInfoQuery.quickshellVersion }
                                             }
                                         }

                                         Text {
                                             text: "Storage"
                                             font.pixelSize: 13; font.family: "Google Sans"; font.weight: Font.Bold
                                             color: settingsRoot.activeItem
                                             Layout.leftMargin: 12; Layout.topMargin: 8
                                         }

                                         Rectangle {
                                             Layout.fillWidth: true
                                             Layout.leftMargin: 10; Layout.rightMargin: 10
                                             implicitHeight: aboutStorageCol.implicitHeight + 32
                                             radius: 16
                                             color: Qt.rgba(1,1,1,0.03)
                                             border.color: Qt.rgba(1,1,1,0.05)
                                             border.width: 1

                                             ColumnLayout {
                                                 id: aboutStorageCol
                                                 anchors { fill: parent; margins: 16 }
                                                 spacing: 8

                                                 RowLayout {
                                                     Layout.fillWidth: true
                                                     Text {
                                                         text: "Home storage"
                                                         font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                         color: settingsRoot.textPrimary
                                                     }
                                                     Item { Layout.fillWidth: true }
                                                     Text {
                                                         text: storageQueryProc.storageUsed + " used of " + storageQueryProc.storageTotal
                                                         font.pixelSize: 12; font.family: "Google Sans"
                                                         color: settingsRoot.textSecondary
                                                     }
                                                 }

                                                 Rectangle {
                                                     Layout.fillWidth: true
                                                     height: 8
                                                     radius: 4
                                                     color: Qt.rgba(settingsRoot.textPrimary.r, settingsRoot.textPrimary.g, settingsRoot.textPrimary.b, 0.12)

                                                     Rectangle {
                                                         width: parent.width * storageQueryProc.storagePercent
                                                         height: parent.height
                                                         radius: parent.radius
                                                         color: settingsRoot.activeItem
                                                     }
                                                 }

                                                 RowLayout {
                                                     Layout.fillWidth: true
                                                     Text {
                                                         text: storageQueryProc.storageFree + " free"
                                                         font.pixelSize: 12; font.family: "Google Sans"
                                                         color: settingsRoot.textSecondary
                                                     }
                                                     Item { Layout.fillWidth: true }
                                                     Text {
                                                         text: "File system: " + storageQueryProc.storageFs
                                                         font.pixelSize: 12; font.family: "Google Sans"; font.weight: Font.Medium
                                                         color: settingsRoot.textSecondary
                                                     }
                                                 }
                                             }
                                         }

                                         Text {
                                             text: "Configuration"
                                             font.pixelSize: 13; font.family: "Google Sans"; font.weight: Font.Bold
                                             color: settingsRoot.activeItem
                                             Layout.leftMargin: 12; Layout.topMargin: 8
                                         }

                                         Rectangle {
                                             Layout.fillWidth: true
                                             Layout.leftMargin: 10; Layout.rightMargin: 10
                                             implicitHeight: configInfoCol.implicitHeight + 8
                                             radius: 16
                                             color: Qt.rgba(1,1,1,0.03)
                                             border.color: Qt.rgba(1,1,1,0.05)
                                             border.width: 1

                                             ColumnLayout {
                                                 id: configInfoCol
                                                 anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
                                                 spacing: 0

                                                 InfoRow {
                                                     Layout.leftMargin: 16
                                                     Layout.rightMargin: 16
                                                     label: "Config version"
                                                     value: systemInfoQuery.configVersion
                                                 }

                                                 Rectangle {
                                                     Layout.fillWidth: true
                                                     Layout.leftMargin: 16; Layout.rightMargin: 16
                                                     height: 1
                                                     color: settingsRoot.dividerColor
                                                 }

                                                 SettingsRow {
                                                     iconSource: "assets/icons/settings.svg"
                                                     title: "Open config folder"
                                                     subtitle: ConfigService.configDir
                                                     hasChevron: true
                                                     showDivider: false
                                                     onClicked: settingsRoot.openPath(ConfigService.configDir)
                                                 }
                                             }
                                         }
                                     }
                                 }
                            }
                        }
                    }
                }
            }
        }
    }
}
