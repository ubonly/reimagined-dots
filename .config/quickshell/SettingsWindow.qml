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
    property int    currentPage: 2
    readonly property string themeMode: ConfigService.ready ? ConfigService.values.themeMode : "dark"
    readonly property string dockStyle: ConfigService.ready ? ConfigService.values.dockStyle : "rounded"
    readonly property bool dockTransparencyEnabled: ConfigService.ready ? ConfigService.values.dockTransparencyEnabled : false
    readonly property real dockOpacity: ConfigService.ready ? ConfigService.values.dockOpacity : 0.85
    readonly property bool dockIconFillEnabled: ConfigService.ready ? ConfigService.values.dockIconFillEnabled : false
    readonly property string matugenScheme: ConfigService.ready ? ConfigService.values.matugenScheme : "scheme-tonal-spot"

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
        if (ConfigService.ready) ConfigService.values.dockIconFillEnabled = enabled;
    }

    function setThemeMode(mode) {
        if (ConfigService.ready) {
            ConfigService.values.themeMode = mode;
            Quickshell.execDetached(["bash", ConfigService.configDir + "/set_theme_mode.sh", mode, settingsRoot.matugenScheme]);
        }
    }

    function setMatugenScheme(scheme) {
        if (ConfigService.ready) {
            ConfigService.values.matugenScheme = scheme;
            Quickshell.execDetached(["bash", ConfigService.configDir + "/set_theme_mode.sh", settingsRoot.themeMode, scheme]);
        }
    }

    onSettingsVisibleChanged: {
        if (settingsVisible) {
            currentPage = 3;
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  SYSTEM METRICS & PREFERENCES PROCESSES
    // ══════════════════════════════════════════════════════════════════════
    Process {
        id: storageQueryProc
        property string storageUsed: "0 GB"
        property string storageTotal: "0 GB"
        property string storageFree: "0 GB"
        property real storagePercent: 0.0

        command: ["bash", "-c", "df -h / | tail -n 1 | awk '{print $3 \"|\" $2 \"|\" $4 \"|\" $5}'"]
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 6
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split("|");
                if (parts.length >= 4) {
                    storageQueryProc.storageUsed = parts[0];
                    storageQueryProc.storageTotal = parts[1];
                    storageQueryProc.storageFree = parts[2];
                    var pct = parseFloat(parts[3].replace("%", "")) / 100.0;
                    storageQueryProc.storagePercent = isNaN(pct) ? 0.0 : pct;
                }
            }
        }
    }

    Timer {
        interval: 10000; repeat: true
        running: settingsRoot.settingsVisible && settingsRoot.currentPage === 6
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
        onActivated: settingsRoot.settingsVisible = false
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
                onClicked: settingsRoot.settingsVisible = false
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



                        NavItem { navIconSource: "assets/icons/desktop-windows.svg";    navTitle: "Device";              navSub: "Keyboard, mouse, print";       navIndex: 2 }
                        NavItem { navIconSource: "assets/icons/wallpaper.svg";          navTitle: "Wallpaper and style"; navSub: "Dark theme, screen saver";     navIndex: 3 }
                        NavItem { navIconSource: "assets/icons/apps.svg";               navTitle: "Dock";                navSub: "Shelf style and behavior";     navIndex: 4 }
                        NavItem { navIconSource: "assets/icons/accessibility.svg";      navTitle: "Accessibility";       navSub: "Screen reader, magnification"; navIndex: 5 }
                        NavItem { navIconSource: "assets/icons/build.svg";              navTitle: "System preferences";  navSub: "Storage, power, language";     navIndex: 6 }
                        NavItem { navIconSource: "assets/icons/info.svg";               navTitle: "About ChromeOS";      navSub: "Updates, help";                navIndex: 7 }

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
                                            var titles = ["","","Device","Wallpaper and style",
                                                "Dock","Accessibility","System preferences","About ChromeOS"]
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
                                         visible: settingsRoot.currentPage !== 3 && settingsRoot.currentPage !== 4 && settingsRoot.currentPage !== 6
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Coming soon"
                                            font.pixelSize: 13; font.family: "Google Sans"
                                            font.italic: true
                                            color: Qt.rgba(1,1,1,0.18)
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
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.topMargin: 8; Layout.bottomMargin: 16
                                                    spacing: 12

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
                                                }

                                                SettingsRow {
                                                    iconSource: "assets/icons/image-fill.svg"
                                                    title: "Random Konachan wallpaper"
                                                    subtitle: "Downloads a random anime wallpaper"
                                                    hasChevron: true
                                                    showDivider: true
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
                                                                    { name: "Square", value: "square" },
                                                                    { name: "Floating", value: "floating" }
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

                                                Item {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 82
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

                                                SettingsRow {
                                                    iconSource: "assets/icons/palette-outline.svg"
                                                    title: "Fill dock icons"
                                                    subtitle: "Tint dock app icons with the current theme color"
                                                    hasSwitch: true
                                                    switchVal: settingsRoot.dockIconFillEnabled
                                                    showDivider: false
                                                    onSwitchToggled: {
                                                        settingsRoot.updateDockIconFillEnabled(!settingsRoot.dockIconFillEnabled)
                                                    }
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                    implicitHeight: settingsRoot.dockTransparencyEnabled ? 70 : 0
                                                    visible: settingsRoot.dockTransparencyEnabled

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
                                                }
                                            }
                                        }
                                    }

                                     // PAGE 6: System Preferences
                                     ColumnLayout {
                                         visible: settingsRoot.currentPage === 6
                                         Layout.fillWidth: true
                                         spacing: 12

                                         // SECTION 1: Storage and Power
                                         Text {
                                             text: "Storage and power"
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

                                                 // Item 1: Storage Usage
                                                 ColumnLayout {
                                                     Layout.fillWidth: true
                                                     spacing: 8

                                                     RowLayout {
                                                         Layout.fillWidth: true
                                                         Text {
                                                             text: "Storage management"
                                                             font.pixelSize: 14; font.family: "Google Sans"; font.weight: Font.Medium
                                                             color: settingsRoot.textPrimary
                                                         }
                                                         Item { Layout.fillWidth: true }
                                                         Text {
                                                             text: storageQueryProc.storageUsed + " used of " + storageQueryProc.storageTotal + " (" + storageQueryProc.storageFree + " free)"
                                                             font.pixelSize: 12; font.family: "Google Sans"
                                                             color: settingsRoot.textSecondary
                                                         }
                                                     }

                                                     // Storage Bar
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
                                                 }

                                                 Rectangle {
                                                     Layout.fillWidth: true; height: 1
                                                     color: settingsRoot.dividerColor
                                                 }

                                                 // Item 2: Power profile selection
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
