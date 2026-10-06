import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import qs
import qs.lucidui

FloatingWindow {
    id: win

    PaletteFade {
        active: win.visible
    }

    readonly property int wheelStep: 190
    readonly property int flickDecel: 6000
    readonly property int maxFlick: 9000

    // m3 navigation rail: 88 collapsed, 268 expanded
    readonly property int railNarrow: Theme.dp(88)
    readonly property int railWide: Theme.dp(268)
    property bool railWanted: true
    readonly property bool railExpanded: (win.railWanted && surface.width >= 880) || railSearch.focused || win.searching
    // 0 collapsed .. 1 expanded, tracked through the width animation itself so
    // everything inside the rail can interpolate rather than jump
    readonly property real railT: Math.max(0, Math.min(1, (rail.width - win.railNarrow) / (win.railWide - win.railNarrow)))

    // m3 large top app bar, collapsing to a small one on scroll
    readonly property int barTall: Theme.dp(128)
    readonly property int barShort: Theme.dp(66)
    property real scrollY: 0
    readonly property real collapse: Math.max(0, Math.min(1, win.scrollY / 72))

    property string page: "general"
    // grouped, and the rail draws a heading above the first page of each group.
    // a hidden page still gets a pane and a header; it just has no rail entry,
    // because something else on screen already leads to it
    // plus the results page, which only exists while something is typed
    readonly property var pages: Prefs.settingsPages.concat([{
        "key": "search",
        "group": "",
        "label": "Search",
        "title": "Search",
        "blurb": "",
        "hidden": true
    }])

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

    // search: typing in the rail's field swaps the page for the results, and
    // emptying it goes back to the page it replaced
    readonly property string searchQuery: railSearch.text.trim()
    readonly property bool searching: win.searchQuery !== ""
    readonly property bool searchReady: searchIndex.rows.length > 0
    readonly property var searchResults: win.searching ? searchIndex.find(win.searchQuery) : []
    readonly property int searchRowCount: win.searchResults.filter((r) => {
        return r.kind === "row";
    }).length
    readonly property string searchSummary: {
        const n = win.searchRowCount;
        if (win.searchResults.length === 0)
            return win.searchReady ? "Nothing matches “" + win.searchQuery + "”" : "";

        return n === 0 ? "Pages matching “" + win.searchQuery + "”" : (n === 1 ? "1 setting" : n + " settings") + " matching “" + win.searchQuery + "”";
    }
    property int searchSel: 0
    property string searchReturn: "general"
    // typing starts a search only when no dialog is taking the keys
    readonly property bool dialogOpen: passwordDialog.shown || newUserDialog.shown || deleteUserDialog.shown || avatarPicker.shown || fontPicker.shown || envPicker.shown || timeZonePicker.shown || appPicker.shown || confirmDialog.shown || keybindEditor.shown || layoutPicker.shown

    onSearchResultsChanged: {
        // the first row, unless the page itself is what was asked for
        const r = win.searchResults;
        win.searchSel = r.length > 1 && !r[0].matched ? 1 : 0;
    }
    onPageChanged: {
        if (win.page !== "search" && railSearch.text !== "")
            railSearch.clear();

        win.record();
    }

    // pages visited since the window opened; search results never count
    property var backStack: []
    property var forwardStack: []
    property string lastPage: ""
    property bool stepping: false
    readonly property bool canGoBack: win.page === "search" || win.backStack.length > 0
    readonly property bool canGoForward: win.forwardStack.length > 0

    function record() {
        if (!win.visible || win.page === "search" || win.page === win.lastPage)
            return ;

        if (!win.stepping && win.lastPage !== "") {
            win.backStack = win.backStack.concat([win.lastPage]).slice(-50);
            win.forwardStack = [];
        }
        win.lastPage = win.page;
    }

    function step(p) {
        win.stepping = true;
        win.page = p;
        win.stepping = false;
    }

    // backing out of search results just clears the search
    function goBack() {
        if (win.page === "search") {
            railSearch.clear();
            return ;
        }
        const b = win.backStack;
        if (b.length === 0)
            return ;

        win.backStack = b.slice(0, -1);
        win.forwardStack = win.forwardStack.concat([win.lastPage]);
        win.step(b[b.length - 1]);
    }

    function goForward() {
        const f = win.forwardStack;
        if (f.length === 0)
            return ;

        win.forwardStack = f.slice(0, -1);
        win.backStack = win.backStack.concat([win.lastPage]);
        win.step(f[f.length - 1]);
    }

    // reads the field itself: this runs before the bindings on it catch up
    function searchTextChanged() {
        if (railSearch.text.trim() !== "") {
            searchIndex.ensure();
            if (win.page !== "search") {
                win.searchReturn = win.page;
                win.page = "search";
            }
        } else if (win.page === "search") {
            win.page = win.searchReturn;
        }
    }

    function moveSearchSel(by) {
        const n = win.searchResults.length;
        if (n > 0)
            win.searchSel = (win.searchSel + by + n) % n;

    }

    // a page opens at the top; a row opens its page scrolled to it, and flashes
    function openResult(r) {
        if (!r)
            return ;

        win.page = r.key;
        focusSink.forceActiveFocus();
        if (r.kind === "row") {
            revealTimer.target = r;
            revealTimer.restart();
        }
    }

    function findRow(item, r) {
        const kids = item.children;
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i];
            if (c.isGroupItem === true && c.title === r.title && c.visible && (c.group ? c.group.title === r.card : r.card === ""))
                return c;

            const deeper = win.findRow(c, r);
            if (deeper)
                return deeper;

        }
        return null;
    }

    function revealRow(r) {
        const pane = panes.itemAt(win.pages.findIndex((p) => {
            return p.key === r.key;
        }));
        const row = pane && pane.pageItem ? win.findRow(pane.pageItem, r) : null;
        if (!row)
            return ;

        pane.scrollToItem(row);
        row.flash();
    }

    // one frame for the page to load and lay out before measuring where the row is
    Timer {
        id: revealTimer

        property var target: null

        interval: 80
        onTriggered: win.revealRow(revealTimer.target)
    }

    SettingsIndex {
        id: searchIndex

        pages: win.pages
        fileOf: (key) => {
            const pane = panes.itemAt(win.pages.findIndex((p) => {
                return p.key === key;
            }));
            return pane ? pane.pageFile : "";
        }
    }

    // qs ipc call -- settings search "night light"
    function search(query) {
        win.show("");
        railSearch.text = query;
        railSearch.focusInput();
    }

    function show(p) {
        // the results page only exists while something is typed
        if (p !== "" && p !== "search")
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
        win.backStack = [];
        win.forwardStack = [];
        win.lastPage = win.page === "search" ? win.searchReturn : win.page;
        if (win.visible) {
            // opened with a search already typed (the ipc call): stay in the field
            if (railSearch.text !== "")
                railSearch.focusInput();
            else
                focusSink.forceActiveFocus();
        } else {
            railSearch.clear();
            // otherwise a picker left open is still there on the next open
            confirmDialog.dismiss();
            fontPicker.dismiss();
            timeZonePicker.dismiss();
            envPicker.dismiss();
            keybindEditor.dismiss();
            appPicker.dismiss();
            layoutPicker.dismiss();
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

    implicitWidth: Theme.dp(1180)
    implicitHeight: Theme.dp(800)
    minimumSize.width: Theme.dp(720)
    minimumSize.height: Theme.dp(520)

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
            else if (action.indexOf("special-delete:") === 0)
                Specials.remove(action.substring(15));
            else if (action.indexOf("hypr:") === 0)
                HyprConfig.resetKeys(action.substring(5).split(","));
            else if (action.indexOf("keybind-delete:") === 0) {
                Keybinds.remove(action.substring(15));
                keybindEditor.dismiss();
            } else if (action.indexOf("wifi-forget:") === 0)
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

    // under the confirm dialog, which asks before a delete from inside it
    KeybindEditor {
        id: keybindEditor

        z: 90
        onDismissed: focusSink.forceActiveFocus()
    }

    Connections {
        function onEditRequested(id) {
            keybindEditor.open(id);
        }

        function onNewRequested(preset) {
            keybindEditor.openNew(preset);
        }

        target: Keybinds
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

    LayoutPicker {
        id: layoutPicker

        z: 100
        onChosen: (layout, variant) => {
            return HyprConfig.setLayouts(HyprConfig.layoutList().concat([{
                "layout": layout,
                "variant": variant
            }]));
        }
    }

    Connections {
        function onLayoutPickerRequested(taken) {
            layoutPicker.open(taken);
        }

        target: HyprConfig
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
            else if (layoutPicker.shown)
                layoutPicker.dismiss();
            else if (confirmDialog.shown)
                confirmDialog.dismiss();
            else if (keybindEditor.shown)
                keybindEditor.dismiss();
            else
                win.visible = false;
        }
        Keys.onReturnPressed: confirmDialog.confirm()
        Keys.onEnterPressed: confirmDialog.confirm()
        Keys.onPressed: (event) => {
            if (win.dialogOpen)
                return ;

            const altOnly = (event.modifiers & Qt.AltModifier) && !(event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier));
            if (event.key === Qt.Key_Back || (altOnly && event.key === Qt.Key_Left)) {
                win.goBack();
                event.accepted = true;
            } else if (event.key === Qt.Key_Forward || (altOnly && event.key === Qt.Key_Right)) {
                win.goForward();
                event.accepted = true;
            } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                railSearch.focusInput();
                event.accepted = true;
            } else if (event.text.length === 1 && event.text.charCodeAt(0) > 32 && event.text.charCodeAt(0) !== 127 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                railSearch.focusInput(event.text);
                event.accepted = true;
            }
        }
    }

    // the mouse's side buttons
    MouseArea {
        anchors.fill: parent
        z: 200
        enabled: !win.dialogOpen
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.BackButton)
                win.goBack();
            else
                win.goForward();
        }
    }

    Item {
        id: surface

        anchors.fill: parent

        Item {
            id: rail

            readonly property int pad: Theme.dp(12)

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
                height: Theme.dp(78)

                MouseArea {
                    anchors.fill: parent
                    onPressed: win.startSystemMove()
                }

                M3IconButton {
                    id: menuBtn

                    x: 20 * win.railT + ((rail.width - menuBtn.width) / 2) * (1 - win.railT)
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(44)
                    iconSize: Theme.dp(22)
                    enabled: surface.width >= 880
                    iconPath: "menu"
                    onClicked: win.railWanted = !win.railWanted
                }

                Row {
                    anchors.left: menuBtn.right
                    anchors.leftMargin: Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(11)
                    opacity: Math.max(0, (win.railT - 0.55) / 0.45)
                    visible: opacity > 0.01

                    LucidaMark {
                        width: Theme.dp(24)
                        height: Theme.dp(24)
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
                            font.variableAxes: Theme.axes(Theme.fontTitleMd, 600, 0)
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Settings"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelMd
                            font.variableAxes: Theme.axes(Theme.fontLabelMd, 420, 0)
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
                anchors.topMargin: Theme.dp(2)
                railT: win.railT
                selected: win.page === "users"
                onClicked: win.page = "users"
            }

            SettingsSearch {
                id: railSearch

                x: rail.pad
                width: rail.width - rail.pad * 2
                anchors.top: userCard.bottom
                anchors.topMargin: Theme.dp(8)
                railT: win.railT
                onTextChanged: win.searchTextChanged()
                onMoved: (by) => {
                    return win.moveSearchSel(by);
                }
                onAccepted: win.openResult(win.searchResults[win.searchSel])
                onEscaped: {
                    if (railSearch.text !== "")
                        railSearch.clear();
                    else
                        focusSink.forceActiveFocus();
                }
            }

            // the destinations outgrew the window, so they scroll under a pinned footer
            Flickable {
                id: navScroll

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: railSearch.bottom
                anchors.topMargin: Theme.dp(6)
                anchors.bottom: railFoot.top
                anchors.bottomMargin: Theme.dp(8)
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
                    spacing: Theme.dp(3)

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
                                height: Math.round(Theme.dp(15) + 19 * win.railT)
                                visible: navCell.heading !== ""

                                Text {
                                    x: Theme.dp(20)
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: Theme.dp(5)
                                    text: navCell.heading
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabelLg
                                    font.variableAxes: Theme.axes(Theme.fontLabelLg, 600, 0)
                                    font.weight: Font.DemiBold
                                    opacity: Math.max(0, (win.railT - 0.55) / 0.45)
                                    visible: opacity > 0.01
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: Theme.dp(7)
                                    width: Theme.dp(22)
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
                                readonly property real iconX: Theme.dp(20) * win.railT + ((navItem.width - Theme.dp(22)) / 2) * (1 - win.railT)
                                readonly property real labelFade: Math.max(0, (win.railT - 0.5) / 0.5)
                                readonly property color fg: navItem.selected ? Theme.fgSecondaryContainer : (navArea.containsMouse ? Theme.text : Theme.subtext)

                                width: parent.width
                                height: Theme.dp(50)

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
                                    width: Theme.dp(22)
                                    height: Theme.dp(22)
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
                                    active: navItem.selected

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.durShort
                                        }

                                    }

                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: navItem.iconX + Theme.dp(38)
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.dp(14)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navItem.modelData.label
                                    color: navItem.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBodyLg
                                    font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
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
                height: Theme.dp(66)

                M3Button {
                    x: rail.pad + Theme.dp(6)
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
                    size: Theme.dp(44)
                    iconSize: Theme.dp(21)
                    destructive: true
                    opacity: 1 - Math.min(1, win.railT * 2)
                    visible: opacity > 0.01
                    iconPath: "refresh"
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
            anchors.topMargin: Theme.dp(12)
            anchors.rightMargin: Theme.dp(12)
            anchors.bottomMargin: Theme.dp(12)
            color: Theme.withBlur(Theme.bgSunken)
            radius: Theme.shapeXl
            clip: true

            Repeater {
                id: panes

                model: win.pages

                Flickable {
                    id: pane

                    required property var modelData

                    readonly property bool active: win.page === pane.modelData.key
                    readonly property Item pageItem: paneLoader.item
                    // the file, known before the page is ever opened
                    readonly property string pageFile: paneLoader.source.toString().split("/").pop()

                    // measured against where the page settles, not where its
                    // entrance has it right now
                    function scrollToItem(target) {
                        const y = win.barTall + 10 + target.mapToItem(paneLoader.item, 0, 0).y;
                        const maxY = Math.max(0, pane.contentHeight - pane.height);
                        paneScroll.stop();
                        paneScroll.from = pane.contentY;
                        paneScroll.to = Math.max(0, Math.min(maxY, y - win.barShort - 40));
                        paneScroll.start();
                    }

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: paneLoader.y + paneLoader.height + Theme.dp(44)
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
                        width: Theme.dp(10)
                        // the app bar is translucent, so the handle would show
                        // through it; and the pane's clip is rectangular while its
                        // corners are not, so an unpadded handle paints outside the
                        // curve. hold it under the bar and clear of the bottom arc
                        topPadding: pageHeader.height
                        bottomPadding: content.radius

                        contentItem: Rectangle {
                            implicitWidth: paneBar.hovered || paneBar.pressed ? Theme.dp(8) : Theme.dp(5)
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

                        x: Theme.dp(34)
                        y: win.barTall + Theme.dp(10) + (pane.active ? 0 : Theme.dp(14))
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
                            case "colours":
                                return "ColoursPage.qml";
                            case "palettes":
                                return "PalettesPage.qml";
                            case "environment":
                                return "EnvironmentPage.qml";
                            case "keybinds":
                                return "KeybindsPage.qml";
                            case "displays":
                                return "MonitorsPage.qml";
                            case "input":
                                return "InputPage.qml";
                            case "bar":
                                return "BarPage.qml";
                            case "dock":
                                return "DockPage.qml";
                            case "launcher":
                                return "LauncherPage.qml";
                            case "widgets":
                                return "WidgetsPage.qml";
                            case "windows":
                                return "WindowsPage.qml";
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
                            case "search":
                                return "SearchPage.qml";
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

                    // only the page on screen follows the window; every page ever
                    // visited re-laying out on each resize step froze the window
                    Binding {
                        target: paneLoader
                        property: "width"
                        value: pane.width - 76
                        when: pane.active
                        restoreMode: Binding.RestoreNone
                    }

                    // a page with a pageShown property is told when it comes on and off screen
                    readonly property bool showing: pane.active && win.visible

                    onShowingChanged: {
                        if (pane.showing)
                            paneLoader.everActive = true;

                        if (paneLoader.item && paneLoader.item.pageShown !== undefined)
                            paneLoader.item.pageShown = pane.showing;

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

                Row {
                    id: leading

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(18)
                    anchors.top: parent.top
                    anchors.topMargin: Theme.dp(13)
                    spacing: Theme.dp(2)

                    M3IconButton {
                        size: Theme.dp(40)
                        iconSize: Theme.dp(21)
                        iconPath: "arrow_back"
                        enabled: win.canGoBack
                        onClicked: win.goBack()
                    }

                    M3IconButton {
                        size: Theme.dp(40)
                        iconSize: Theme.dp(21)
                        iconPath: "arrow_forward"
                        enabled: win.canGoForward
                        onClicked: win.goForward()
                    }

                }

                Column {
                    id: headText

                    // slides in beside the arrows as the bar collapses to one row
                    x: Theme.dp(34) + (leading.x + leading.width + Theme.dp(14) - Theme.dp(34)) * win.collapse
                    // an anchored Column would take its width from children that
                    // in turn bind to it, so measure against the trailing row
                    width: Math.max(0, trailing.x - headText.x - Theme.dp(24))
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.dp(19)
                    spacing: Theme.dp(3)

                    Text {
                        width: parent.width
                        text: win.current ? win.current.title : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fontHeadlineMd - (Theme.fontHeadlineMd - Theme.fontTitleLg) * win.collapse)
                        font.variableAxes: Theme.axes(Math.round(Theme.fontHeadlineMd - (Theme.fontHeadlineMd - Theme.fontTitleLg) * win.collapse), 520, 0)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: win.page === "search" ? win.searchSummary : (win.current ? win.current.blurb : "")
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyMd
                        font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                        elide: Text.ElideRight
                        opacity: Math.max(0, 1 - win.collapse * 2.4)
                        visible: opacity > 0.01
                    }

                }

                Row {
                    id: trailing

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(18)
                    anchors.top: parent.top
                    anchors.topMargin: Theme.dp(13)
                    spacing: Theme.dp(10)

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
                        size: Theme.dp(40)
                        iconSize: Theme.dp(21)
                        iconPath: "close"
                        onClicked: win.visible = false
                    }

                }

            }

        }

    }

}
