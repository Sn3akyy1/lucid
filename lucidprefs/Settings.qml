import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import qs

FloatingWindow {
    id: win

    readonly property int wheelStep: 190
    readonly property int flickDecel: 6000
    readonly property int maxFlick: 9000

    // m3 navigation rail: 88 collapsed, 268 expanded
    readonly property int railNarrow: 88
    readonly property int railWide: 268
    property bool railWanted: true
    readonly property bool railExpanded: win.railWanted && surface.width >= 880
    // 0 collapsed .. 1 expanded, tracked through the width animation itself so
    // everything inside the rail can interpolate rather than jump
    readonly property real railT: Math.max(0, Math.min(1, (rail.width - win.railNarrow) / (win.railWide - win.railNarrow)))

    // m3 large top app bar, collapsing to a small one on scroll
    readonly property int barTall: 128
    readonly property int barShort: 66
    property real scrollY: 0
    readonly property real collapse: Math.max(0, Math.min(1, win.scrollY / 72))

    property string page: "general"
    // grouped, and the rail draws a heading above the first page of each group.
    // a hidden page still gets a pane and a header; it just has no rail entry,
    // because something else on screen already leads to it
    readonly property var pages: [
        { "key": "users", "group": "Account", "label": "Account", "title": "Users and Accounts", "blurb": "Who may sign in to this machine, what they are called and what they are allowed to do", "hidden": true },
        { "key": "general", "group": "Appearance", "label": "General", "title": "General", "blurb": "Shape, colour and motion across the whole shell" },
        { "key": "glass", "group": "Appearance", "label": "Glass", "title": "Glass", "blurb": "How far the desktop shows through the shell, the terminal and your windows" },
        { "key": "theme", "group": "Appearance", "label": "Theme", "title": "Theme and Appearance", "blurb": "Colour schemes, wallpapers and themes you import" },
        { "key": "environment", "group": "Appearance", "label": "Environment", "title": "Environment", "blurb": "Cursors, icons, fonts and application themes, across GTK, Qt and Hyprland alike" },
        { "key": "bar", "group": "Desktop", "label": "Bar", "title": "Bar", "blurb": "The status bar, its modules and how they open", "toggle": "barEnabled" },
        { "key": "dock", "group": "Desktop", "label": "Dock", "title": "Dock", "blurb": "The dock, its icons and how it behaves", "toggle": "dockEnabled" },
        { "key": "widgets", "group": "Desktop", "label": "Widgets", "title": "Widgets", "blurb": "Cards you place on the desktop and arrange yourself", "toggle": "widgetsEnabled" },
        { "key": "workspaces", "group": "Desktop", "label": "Workspaces", "title": "Special Workspaces", "blurb": "Your music, chat, to-do list and a scratchpad, each one key away and gone again with the same key" },
        { "key": "displays", "group": "Devices", "label": "Displays", "title": "Displays", "blurb": "Every screen this machine has: resolution, refresh rate, scale, how they are arranged and which one the shell sits on" },
        { "key": "sound", "group": "Devices", "label": "Sound", "title": "Sound", "blurb": "Which speakers play and which microphone listens, what each application is using, and how loud any of it is" },
        { "key": "network", "group": "Devices", "label": "Network", "title": "Network", "blurb": "Wi-Fi, wired, VPN and how this machine gets its address" },
        { "key": "bluetooth", "group": "Devices", "label": "Bluetooth", "title": "Bluetooth and Devices", "blurb": "The radio, what it is paired with, and the phone you connect to it" },
        { "key": "kdeconnect", "group": "Devices", "label": "Phone", "title": "Phone", "blurb": "Your phone on this machine over KDE Connect: files, notifications, clipboard and a remote", "toggle": "kdeConnectEnabled" },
        { "key": "notifications", "group": "System", "label": "Notifications", "title": "Notifications", "blurb": "Popups, quiet hours, sound and which applications may interrupt you", "toggle": "showNotifications" },
        { "key": "idle", "group": "System", "label": "Idle", "title": "Idle and Sleep", "blurb": "What happens when you walk away: dimming, locking, screen off and suspend", "toggle": "idleEnabled" },
        { "key": "datetime", "group": "System", "label": "Date & Time", "title": "Date and Time", "blurb": "Where you are, which zone the clock keeps and how it reads" },
        { "key": "about", "group": "System", "label": "About", "title": "About", "blurb": "Lucid" }
    ]

    // what the rail actually lists
    readonly property var navPages: win.pages.filter((p) => {
        return p.hidden !== true;
    })

    // "" unless this page opens its group
    function groupAt(i) {
        const g = win.navPages[i] ? win.navPages[i].group : "";
        return i === 0 || win.navPages[i - 1].group !== g ? g : "";
    }

    readonly property var current: win.pages.find((p) => {
        return p.key === win.page;
    })

    function show(p) {
        if (p !== "")
            win.page = p;

        win.visible = true;
        // themes can be installed while the shell runs; look again on every open
        if (win.page === "environment")
            Env.rescan();

    }

    // which of the environment's lists is open, so the answer knows where to go
    property string envPickKind: ""

    function openEnvPicker(kind) {
        win.envPickKind = kind;
        if (kind === "cursor")
            envPicker.open("Cursor theme", "cursor themes", Env.cursorThemes, Prefs.envCursorTheme, false);
        else if (kind === "icon") {
            Env.loadPreviews();
            envPicker.open("Icon theme", "icon themes", Env.iconThemes, Prefs.envIconTheme, true);
        } else if (kind === "gtk")
            envPicker.open("Application theme", "GTK themes", Env.gtkThemes, Prefs.envGtkTheme, false);
        else if (kind === "qtStyle")
            envPicker.open("Qt style", "Qt styles", Env.qtStyles, Prefs.envQtStyle, false);
        else if (kind === "appFont")
            envPicker.open("Application font", "fonts", Qt.fontFamilies(), Env.appFont, false);
        else if (kind === "docFont")
            envPicker.open("Document font", "fonts", Qt.fontFamilies(), Prefs.envDocumentFont, false);
        else if (kind === "monoFont")
            envPicker.open("Monospace font", "fonts", Qt.fontFamilies(), Prefs.envMonoFont, false);
    }

    // a rescan can finish while a list is open; keep it showing what is installed
    function refreshEnvPicker(kind, items) {
        if (envPicker.shown && win.envPickKind === kind)
            envPicker.items = items;

    }

    function applyEnvChoice(name) {
        var k = win.envPickKind;
        if (k === "cursor")
            Prefs.envCursorTheme = name;
        else if (k === "icon")
            Prefs.envIconTheme = name;
        else if (k === "gtk")
            Prefs.envGtkTheme = name;
        else if (k === "qtStyle")
            Prefs.envQtStyle = name;
        else if (k === "appFont")
            Prefs.envAppFont = name;
        else if (k === "docFont")
            Prefs.envDocumentFont = name;
        else if (k === "monoFont")
            Prefs.envMonoFont = name;
    }

    onVisibleChanged: {
        if (win.visible) {
            focusSink.forceActiveFocus();
        } else {
            // otherwise a picker left open is still there on the next open
            confirmDialog.dismiss();
            fontPicker.dismiss();
            timeZonePicker.dismiss();
            envPicker.dismiss();
            appPicker.dismiss();
            avatarPicker.dismiss();
            passwordDialog.dismiss();
            newUserDialog.dismiss();
            deleteUserDialog.dismiss();
        }
    }
    onClosed: win.visible = false

    visible: false
    title: "Lucid Settings"
    // a surface created fully opaque keeps qtwayland's opaque region for the life
    // of the process and hyprland never blurs it, so stay one step under solid
    color: Theme.alpha(Theme.bg, Math.min(Theme.bg.a, 254 / 255))

    implicitWidth: 1180
    implicitHeight: 800
    minimumSize.width: 720
    minimumSize.height: 520

    Connections {
        function onSettingsRequested(page) {
            win.show(page);
        }

        target: Prefs
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            if (win.visible)
                win.visible = false;
            else
                win.show("");
        }

        function open(): void {
            win.show("");
        }

        function close(): void {
            win.visible = false;
        }

        // qs ipc call settings show bar
        function show(page: string): void {
            win.show(page);
        }

        function general(): void {
            win.show("general");
        }

        function users(): void {
            win.show("users");
        }

        // the page is about accounts; both names reach it
        function accounts(): void {
            win.show("users");
        }

        function glass(): void {
            win.show("glass");
        }

        function bar(): void {
            win.show("bar");
        }

        function dock(): void {
            win.show("dock");
        }

        function environment(): void {
            win.show("environment");
        }

        function displays(): void {
            win.show("displays");
        }

        // the page is about monitors; both names reach it
        function monitors(): void {
            win.show("displays");
        }

        function widgets(): void {
            win.show("widgets");
        }

        function workspaces(): void {
            win.show("workspaces");
        }

        function notifications(): void {
            win.show("notifications");
        }

        function sound(): void {
            win.show("sound");
        }

        // the page is called Sound; both names reach it
        function audio(): void {
            win.show("sound");
        }

        function network(): void {
            win.show("network");
        }

        function bluetooth(): void {
            win.show("bluetooth");
        }

        function kdeconnect(): void {
            win.show("kdeconnect");
        }

        // the page is called Phone now; the old name still works
        function phone(): void {
            win.show("kdeconnect");
        }

        function idle(): void {
            win.show("idle");
        }

        function datetime(): void {
            win.show("datetime");
        }

        function font(): void {
            win.show("environment");
            Prefs.fontPickerRequested();
        }

        function reset(): void {
            win.show("");
            Prefs.askReset("Reset every setting?", "Every setting on every page goes back to the value it ships with. Your theme, wallpaper, pinned applications and placed widgets are not touched.", Prefs.resetAllToken);
        }

    }

    ConfirmDialog {
        id: confirmDialog

        z: 100
        onConfirmed: (action) => {
            if (action === Prefs.resetAllToken)
                Prefs.resetAll();
            else if (action === Prefs.resetDockToken)
                Prefs.pinnedResetRequested();
            else if (action === Prefs.resetBlurToken)
                Theme.setBlurAmount(0);
            else if (action === Prefs.clearWidgetsToken)
                Widgets.closeAll();
            else if (action === Prefs.clearClipboardToken)
                Clip.wipe();
            else if (action === Prefs.resetIdleToken)
                Prefs.resetKeys(Prefs.idleKeys);
            else if (action === Prefs.resetEnvToken)
                Prefs.resetKeys(Prefs.envKeys);
            else if (action === Prefs.resetSpecialsToken)
                Prefs.resetKeys(Prefs.specialKeys);
            else if (action === Prefs.resetGlassToken)
                Prefs.resetKeys(Prefs.glassKeys);
            else if (action === Prefs.resetMonitorsToken)
                Prefs.resetKeys(Prefs.monitorKeys);
            else if (action.indexOf("wifi-forget:") === 0)
                Net.forgetSsid(action.substring(12));
            else if (action.indexOf("net-delete:") === 0)
                Net.forget(action.substring(11));
            else if (action.indexOf("net-hotspot:") === 0)
                Net.hotspotFromToken(action.substring(12));
            else if (action.indexOf("bt-forget:") === 0)
                Bt.forgetAddress(action.substring(10));
            else if (action.indexOf("kde-unpair:") === 0)
                KdeConnect.unpair(action.substring(11));
            else if (action.indexOf("wallpaper:") === 0)
                Prefs.wallpaperDeleteRequested(action.substring(10));
            else if (action.indexOf("theme:") === 0)
                Prefs.themeDeleteRequested(action.substring(6));
            else if (action.indexOf("widget-preset:") === 0)
                Widgets.deletePreset(action.substring(14));
            else
                Prefs.set(action, Prefs.defaults[action]);
        }
    }

    FontPicker {
        id: fontPicker

        z: 100
    }

    TimeZonePicker {
        id: timeZonePicker

        z: 100
    }

    EnvPicker {
        id: envPicker

        z: 100
        previews: Env.iconPreviews
        onChosen: (name) => {
            return win.applyEnvChoice(name);
        }
    }

    Connections {
        function onCursorThemesChanged() {
            win.refreshEnvPicker("cursor", Env.cursorThemes);
        }

        function onIconThemesChanged() {
            win.refreshEnvPicker("icon", Env.iconThemes);
        }

        function onGtkThemesChanged() {
            win.refreshEnvPicker("gtk", Env.gtkThemes);
        }

        function onQtStylesChanged() {
            win.refreshEnvPicker("qtStyle", Env.qtStyles);
        }

        target: Env
    }

    AppPicker {
        id: appPicker

        z: 100
        onChosen: (workspace, entryId) => {
            return Specials.addApp(workspace, entryId);
        }
    }

    AvatarPicker {
        id: avatarPicker

        z: 100
        onChosen: (uid, path) => {
            return Users.set(uid, {
                "avatar": path
            }, "avatar");
        }
    }

    PasswordDialog {
        id: passwordDialog

        z: 100
        onSubmitted: (uid, password, hint) => {
            return Users.set(uid, {
                "password": password,
                "passwordHint": hint
            }, "password");
        }
    }

    NewUserDialog {
        id: newUserDialog

        z: 100
        onSubmitted: (spec) => {
            return Users.create(spec);
        }
    }

    DeleteUserDialog {
        id: deleteUserDialog

        z: 100
        onSubmitted: (uid, removeFiles) => {
            return Users.remove(uid, removeFiles);
        }
    }

    Connections {
        function onAvatarRequested(uid) {
            avatarPicker.open(Users.userFor(uid));
        }

        function onPasswordRequested(uid, headline, body, hint) {
            passwordDialog.open(uid, headline, body, hint);
        }

        function onNewUserRequested() {
            newUserDialog.open();
        }

        function onDeleteRequested(uid) {
            deleteUserDialog.open(Users.userFor(uid));
        }

        target: Users
    }

    Connections {
        function onResetConfirmRequested(title, body, confirmLabel, action) {
            confirmDialog.ask(title, body, confirmLabel, action);
        }

        function onFontPickerRequested() {
            fontPicker.open();
        }

        function onEnvPickerRequested(kind) {
            win.openEnvPicker(kind);
        }

        function onTimeZonePickerRequested() {
            timeZonePicker.open();
        }

        function onAppPickerRequested(workspace) {
            appPicker.open(workspace);
        }

        target: Prefs
    }

    Item {
        id: focusSink

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (passwordDialog.shown)
                passwordDialog.dismiss();
            else if (newUserDialog.shown)
                newUserDialog.dismiss();
            else if (deleteUserDialog.shown)
                deleteUserDialog.dismiss();
            else if (avatarPicker.shown)
                avatarPicker.dismiss();
            else if (fontPicker.shown)
                fontPicker.dismiss();
            else if (envPicker.shown)
                envPicker.dismiss();
            else if (timeZonePicker.shown)
                timeZonePicker.dismiss();
            else if (appPicker.shown)
                appPicker.dismiss();
            else if (confirmDialog.shown)
                confirmDialog.dismiss();
            else
                win.visible = false;
        }
        Keys.onReturnPressed: confirmDialog.confirm()
        Keys.onEnterPressed: confirmDialog.confirm()
    }

    Item {
        id: surface

        anchors.fill: parent

        Item {
            id: rail

            readonly property int pad: 12

            width: win.railExpanded ? win.railWide : win.railNarrow
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durLong
                    easing.type: Theme.easeStandard
                }

            }

            // menu button and wordmark; the whole strip is a window drag handle
            Item {
                id: railHead

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 78

                MouseArea {
                    anchors.fill: parent
                    onPressed: win.startSystemMove()
                }

                M3IconButton {
                    id: menuBtn

                    x: 20 * win.railT + ((rail.width - menuBtn.width) / 2) * (1 - win.railT)
                    anchors.verticalCenter: parent.verticalCenter
                    size: 44
                    iconSize: 22
                    enabled: surface.width >= 880
                    iconPath: "M3 18h18v-2H3v2Zm0-5h18v-2H3v2Zm0-7v2h18V6H3Z"
                    onClicked: win.railWanted = !win.railWanted
                }

                Row {
                    anchors.left: menuBtn.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 11
                    opacity: Math.max(0, (win.railT - 0.55) / 0.45)
                    visible: opacity > 0.01

                    LucidaMark {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -1

                        Text {
                            text: "Lucid"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitleMd
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Settings"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelMd
                        }

                    }

                }

            }

            // the account, above the destinations: the way into everything the
            // machine knows about whoever is signed in
            UserCard {
                id: userCard

                x: rail.pad
                width: rail.width - rail.pad * 2
                anchors.top: railHead.bottom
                anchors.topMargin: 2
                railT: win.railT
                selected: win.page === "users"
                onClicked: win.page = "users"
            }

            // the destinations outgrew the window, so they scroll under a pinned footer
            Flickable {
                id: navScroll

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: userCard.bottom
                anchors.topMargin: 10
                anchors.bottom: railFoot.top
                anchors.bottomMargin: 8
                contentWidth: width
                contentHeight: navList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: win.flickDecel
                maximumFlickVelocity: win.maxFlick

                Column {
                    id: navList

                    x: rail.pad
                    width: navScroll.width - rail.pad * 2
                    spacing: 3

                    Repeater {
                        model: win.navPages

                        Column {
                            id: navCell

                            required property var modelData
                            required property int index
                            readonly property string heading: win.groupAt(navCell.index)

                            width: parent.width
                            spacing: 0

                            // the group's name while the rail is open, shrinking
                            // to a rule once there is no width left to print it
                            Item {
                                width: parent.width
                                height: Math.round(15 + 19 * win.railT)
                                visible: navCell.heading !== ""

                                Text {
                                    x: 20
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 5
                                    text: navCell.heading
                                    color: Theme.subtextDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabel
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.6
                                    opacity: Math.max(0, (win.railT - 0.55) / 0.45)
                                    visible: opacity > 0.01
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 7
                                    width: 22
                                    height: 1.5
                                    radius: 0.75
                                    color: Theme.outline
                                    opacity: Math.max(0, 1 - win.railT * 2.5)
                                    visible: opacity > 0.01
                                }

                            }

                            Item {
                                id: navItem

                                readonly property var modelData: navCell.modelData

                                readonly property bool selected: win.page === navItem.modelData.key
                                readonly property real iconX: 20 * win.railT + ((navItem.width - 22) / 2) * (1 - win.railT)
                                readonly property real labelFade: Math.max(0, (win.railT - 0.5) / 0.5)
                                readonly property color fg: navItem.selected ? Theme.fgSecondaryContainer : (navArea.containsMouse ? Theme.text : Theme.subtext)

                                width: parent.width
                                height: 50

                                // m3 active indicator: a full-shape tonal pill
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: navItem.selected ? Theme.secondaryContainer : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.durShort
                                        }

                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: navItem.fg
                                        opacity: navArea.pressed ? Theme.statePressed : (navArea.containsMouse && !navItem.selected ? Theme.stateHover : 0)

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.durQuick
                                            }

                                        }

                                    }

                                }

                                LucidaMark {
                                    x: navItem.iconX
                                    width: 22
                                    height: 22
                                    strokeWidth: 3.4
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: navItem.modelData.key === "about"
                                    ringColor: navItem.selected ? navItem.fg : Theme.subtext
                                    starColor: navItem.fg
                                }

                                NavGlyph {
                                    x: navItem.iconX
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: navItem.modelData.key !== "about"
                                    kind: navItem.modelData.key
                                    color: navItem.fg

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.durShort
                                        }

                                    }

                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: navItem.iconX + 38
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navItem.modelData.label
                                    color: navItem.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBodyLg
                                    font.weight: navItem.selected ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                    opacity: navItem.labelFade
                                    visible: opacity > 0.01

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.durShort
                                        }

                                    }

                                }

                                MouseArea {
                                    id: navArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.page = navItem.modelData.key
                                }

                            }

                        }

                    }

                }

                // without this the rail falls back to Flickable's own wheel
                // steps, which crawl. the panes' step, on the panes' curve
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        event.accepted = true;
                        var maxY = Math.max(0, navScroll.contentHeight - navScroll.height);
                        var base = navFlick.running ? navFlick.to : navScroll.contentY;
                        var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * win.wheelStep));
                        if (target === base)
                            return ;

                        navFlick.stop();
                        navFlick.from = navScroll.contentY;
                        navFlick.to = target;
                        navFlick.start();
                    }
                }

                NumberAnimation {
                    id: navFlick

                    target: navScroll
                    property: "contentY"
                    duration: Theme.ms(170)
                    easing.type: Easing.OutCubic
                }

            }

            Item {
                id: railFoot

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 66

                M3Button {
                    x: rail.pad + 6
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "text"
                    destructive: true
                    text: "Reset all"
                    opacity: Math.max(0, (win.railT - 0.6) / 0.4)
                    visible: opacity > 0.01
                    onClicked: Prefs.askReset("Reset every setting?", "Every setting on every page goes back to the value it ships with. Your theme, wallpaper, pinned applications and placed widgets are not touched.", Prefs.resetAllToken)
                }

                M3IconButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    size: 44
                    iconSize: 21
                    destructive: true
                    opacity: 1 - Math.min(1, win.railT * 2)
                    visible: opacity > 0.01
                    iconPath: "M17.65 6.35A7.958 7.958 0 0 0 12 4a8 8 0 1 0 7.73 10h-2.08A6 6 0 1 1 12 6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35Z"
                    onClicked: Prefs.askReset("Reset every setting?", "Every setting on every page goes back to the value it ships with. Your theme, wallpaper, pinned applications and placed widgets are not touched.", Prefs.resetAllToken)
                }

            }

        }

        // the pane floats clear of the window edges, m3 expressive style
        Rectangle {
            id: content

            anchors.left: rail.right
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 12
            color: Theme.withBlur(Theme.bgSunken)
            radius: Theme.shapeXl
            clip: true

            Repeater {
                model: win.pages

                Flickable {
                    id: pane

                    required property var modelData

                    readonly property bool active: win.page === pane.modelData.key

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: paneLoader.y + paneLoader.height + 44
                    clip: true
                    interactive: pane.active
                    visible: pane.opacity > 0.01
                    opacity: pane.active ? 1 : 0
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: win.flickDecel
                    maximumFlickVelocity: win.maxFlick
                    onContentYChanged: {
                        if (pane.active)
                            win.scrollY = pane.contentY;

                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => {
                            event.accepted = true;
                            var maxY = Math.max(0, pane.contentHeight - pane.height);
                            var base = paneScroll.running ? paneScroll.to : pane.contentY;
                            var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * win.wheelStep));
                            if (target === base)
                                return ;

                            paneScroll.stop();
                            paneScroll.from = pane.contentY;
                            paneScroll.to = target;
                            paneScroll.start();
                        }
                    }

                    NumberAnimation {
                        id: paneScroll

                        target: pane
                        property: "contentY"
                        duration: Theme.ms(170)
                        easing.type: Easing.OutCubic
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: paneBar

                        policy: pane.contentHeight > pane.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        width: 10
                        // the app bar is translucent, so the handle would show
                        // through it; and the pane's clip is rectangular while its
                        // corners are not, so an unpadded handle paints outside the
                        // curve. hold it under the bar and clear of the bottom arc
                        topPadding: pageHeader.height
                        bottomPadding: content.radius

                        contentItem: Rectangle {
                            implicitWidth: paneBar.hovered || paneBar.pressed ? 8 : 5
                            radius: width / 2
                            color: paneBar.pressed ? Theme.accent : (paneBar.hovered ? Theme.alpha(Theme.text, 0.4) : Theme.alpha(Theme.text, 0.2))

                            Behavior on implicitWidth {
                                NumberAnimation {
                                    duration: Theme.durQuick
                                    easing.type: Theme.easeStandard
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        background: Rectangle {
                            color: "transparent"
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Theme.easeStandard
                        }

                    }

                    Loader {
                        id: paneLoader

                        property bool everActive: false

                        width: pane.width - 76
                        x: 34
                        y: win.barTall + 10 + (pane.active ? 0 : 14)
                        active: paneLoader.everActive
                        source: {
                            switch (pane.modelData.key) {
                            case "users":
                                return "UsersPage.qml";
                            case "general":
                                return "GeneralPage.qml";
                            case "glass":
                                return "GlassPage.qml";
                            case "theme":
                                return "ThemePage.qml";
                            case "environment":
                                return "EnvironmentPage.qml";
                            case "displays":
                                return "MonitorsPage.qml";
                            case "bar":
                                return "BarPage.qml";
                            case "dock":
                                return "DockPage.qml";
                            case "widgets":
                                return "WidgetsPage.qml";
                            case "workspaces":
                                return "WorkspacesPage.qml";
                            case "notifications":
                                return "NotificationsPage.qml";
                            case "sound":
                                return "AudioPage.qml";
                            case "network":
                                return "NetworkPage.qml";
                            case "bluetooth":
                                return "BluetoothPage.qml";
                            case "kdeconnect":
                                return "KdeConnectPage.qml";
                            case "idle":
                                return "IdlePage.qml";
                            case "datetime":
                                return "DateTimePage.qml";
                            default:
                                return "AboutPage.qml";
                            }
                        }

                        Behavior on y {
                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                    onActiveChanged: {
                        if (pane.active) {
                            paneLoader.everActive = true;
                            win.scrollY = pane.contentY;
                            if (pane.modelData.key === "environment")
                                Env.rescan();

                        }
                    }
                    Component.onCompleted: {
                        if (pane.active)
                            paneLoader.everActive = true;

                    }
                }

            }

            // large app bar floating over the scrolling pane
            Rectangle {
                id: pageHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: win.barShort + (win.barTall - win.barShort) * (1 - win.collapse)
                topLeftRadius: content.radius
                topRightRadius: content.radius
                color: Theme.withBlur(Theme.bgSunken)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: win.startSystemMove()
                }

                Column {
                    id: headText

                    x: 34
                    // an anchored Column would take its width from children that
                    // in turn bind to it, so measure against the trailing row
                    width: Math.max(0, trailing.x - 34 - 24)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 19
                    spacing: 3

                    Text {
                        width: parent.width
                        text: win.current ? win.current.title : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fontHeadlineMd - (Theme.fontHeadlineMd - Theme.fontTitleLg) * win.collapse)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: win.current ? win.current.blurb : ""
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyMd
                        elide: Text.ElideRight
                        opacity: Math.max(0, 1 - win.collapse * 2.4)
                        visible: opacity > 0.01
                    }

                }

                Row {
                    id: trailing

                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: parent.top
                    anchors.topMargin: 13
                    spacing: 10

                    M3Switch {
                        id: surfaceToggle

                        readonly property string key: (win.current && win.current.toggle) ? win.current.toggle : ""

                        anchors.verticalCenter: parent.verticalCenter
                        visible: surfaceToggle.key !== ""
                        checked: surfaceToggle.key !== "" ? Prefs[surfaceToggle.key] : false
                        onToggled: (v) => {
                            return Prefs.setSurface(surfaceToggle.key, v);
                        }
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 40
                        iconSize: 21
                        iconPath: "M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41Z"
                        onClicked: win.visible = false
                    }

                }

            }

        }

    }

}
