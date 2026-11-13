import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.lucidlumen
import qs.lucidui

// the clock's window, in Lumen's and Lucid Settings' manner: a sidebar of pages
// with Lumen's gliding pill, the page's own action at its head, and each page
// on a sunken pane beside it. pages push one another up or down, never fade
FloatingWindow {
    id: clockWin

    required property var app
    readonly property var pages: [{
        "key": "alarms",
        "label": "Alarm",
        "icon": "alarm"
    }, {
        "key": "clock",
        "label": "Clock",
        "icon": "schedule"
    }, {
        "key": "timer",
        "label": "Timer",
        "icon": "hourglass_top"
    }, {
        "key": "stopwatch",
        "label": "Stopwatch",
        "icon": "timer"
    }, {
        "key": "focus",
        "label": "Focus",
        "icon": "psychiatry"
    }, {
        "key": "reminders",
        "label": "Reminders",
        "icon": "event"
    }, {
        "key": "settings",
        "label": "Settings",
        "icon": "settings"
    }]
    property string page: clockWin.indexOf(clockWin.app.prefs.page) >= 0 ? clockWin.app.prefs.page : "alarms"
    readonly property int pageIndex: Math.max(0, clockWin.indexOf(clockWin.page))
    property bool switching: false
    readonly property var current: pageRepeater.count > clockWin.pageIndex ? pageRepeater.itemAt(clockWin.pageIndex) : null
    // the drawn content, for a preview to grab
    readonly property alias surface: root

    function indexOf(key) {
        for (let i = 0; i < clockWin.pages.length; i++) {
            if (clockWin.pages[i].key === key)
                return i;

        }
        return -1;
    }

    function go(key) {
        if (clockWin.indexOf(key) < 0 || key === clockWin.page)
            return ;

        // a dialog belongs to the page it was opened on
        if (picker.shown)
            picker.finish(false);

        if (reminderEditor.shown)
            reminderEditor.close();

        menu.close();
        clockWin.switching = true;
        switchDone.restart();
        clockWin.page = key;
        clockWin.app.prefs.page = key;
    }

    // asked for again while it is open: the page, and the window to the front
    function present(key) {
        if (key)
            clockWin.go(key);

        const list = ToplevelManager.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].appId === "lucid.clock") {
                list[i].activate();
                break;
            }
        }
    }

    function toast(message, action, payload) {
        snack.show(message, action || "", payload === undefined ? null : payload);
    }

    // a time from the dial: cb(hour, minute) on OK
    function pickTime(hour, minute, title, cb) {
        picker.ask(hour, minute, title, cb);
    }

    function openMenu(items, x, y, cb) {
        menu.open(items, x, y, cb);
    }

    function editReminder(item, day) {
        reminderEditor.ask(item, day);
    }

    title: "Clock"
    visible: true
    // a surface created fully opaque keeps qtwayland's opaque region for the life
    // of the process and hyprland never blurs it, so stay one step under solid
    color: Theme.alpha(Theme.bg, Math.min(Theme.bg.a, 254 / 255))
    implicitWidth: Theme.dp(clockWin.app.prefs.width)
    implicitHeight: Theme.dp(clockWin.app.prefs.height)
    minimumSize.width: Theme.dp(640)
    minimumSize.height: Theme.dp(540)
    onClosed: clockWin.app.closeWindow()

    Timer {
        id: switchDone

        interval: Theme.ms(520)
        onTriggered: clockWin.switching = false
    }

    // the size the window was left at, for the next time it opens
    Timer {
        id: sizeLater

        interval: 600
        onTriggered: {
            if (root.width > 0 && root.height > 0) {
                clockWin.app.prefs.width = Math.round(root.width / Theme.uiScale);
                clockWin.app.prefs.height = Math.round(root.height / Theme.uiScale);
            }
        }
    }

    Item {
        id: root

        anchors.fill: parent
        focus: true
        onWidthChanged: sizeLater.restart()
        onHeightChanged: sizeLater.restart()
        Keys.onPressed: (e) => {
            const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
            if (ctrl && e.key >= Qt.Key_1 && e.key <= Qt.Key_7) {
                clockWin.go(clockWin.pages[e.key - Qt.Key_1].key);
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_Comma) {
                clockWin.go("settings");
                e.accepted = true;
            } else if (ctrl && (e.key === Qt.Key_W || e.key === Qt.Key_Q)) {
                clockWin.app.closeWindow();
                e.accepted = true;
            } else if (ctrl && e.key === Qt.Key_Tab) {
                clockWin.go(clockWin.pages[(clockWin.pageIndex + 1) % clockWin.pages.length].key);
                e.accepted = true;
            } else if (clockWin.current && clockWin.current.handleKey) {
                e.accepted = clockWin.current.handleKey(e) === true;
            }
        }

        // ---- the sidebar, Lumen's
        Item {
            id: side

            readonly property bool full: root.width >= Theme.dp(820)
            readonly property real rowH: Theme.dp(48)
            property Item activeRow: null

            function letGo(p) {
                if (side.activeRow === p && !p.on)
                    side.activeRow = null;

            }

            width: side.full ? Theme.dp(236) : Theme.dp(84)
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // the app's name
            Row {
                x: side.full ? Theme.dp(22) : (side.width - Theme.dp(30)) / 2
                y: Theme.dp(20)
                spacing: Theme.dp(12)

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(30)
                    height: Theme.dp(30)
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: Qt.resolvedUrl("clock.svg")
                    smooth: true
                }

                LText {
                    visible: side.full
                    anchors.verticalCenter: parent.verticalCenter
                    role: "titleLarge"
                    weight: 560
                    text: "Clock"
                }

            }

            // the page's own action: a new alarm, a city, a timer, the stopwatch going
            Rectangle {
                id: fab

                readonly property var act: clockWin.current && clockWin.current.primaryIcon ? clockWin.current : null

                x: Theme.dp(14)
                y: Theme.dp(72)
                width: side.full ? fabRow.implicitWidth + Theme.dp(40) : Theme.dp(56)
                height: Theme.dp(56)
                radius: Theme.dp(16)
                color: Theme.primaryContainer
                scale: fab.act ? (fabArea.pressed ? 0.95 : 1) : 0.6
                opacity: fab.act ? 1 : 0
                visible: opacity > 0.01

                Row {
                    id: fabRow

                    anchors.centerIn: parent
                    spacing: Theme.dp(12)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: fab.act ? fab.act.primaryIcon : "add"
                        size: Theme.dp(24)
                        fill: 1
                        color: Theme.fgPrimaryContainer
                    }

                    LText {
                        visible: side.full
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        weight: 600
                        color: Theme.fgPrimaryContainer
                        text: fab.act ? fab.act.primaryLabel : ""
                    }

                }

                HoverLayer {
                    area: fabArea
                    tint: Theme.fgPrimaryContainer
                }

                MouseArea {
                    id: fabArea

                    objectName: "fab"
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: fab.act !== null && clockWin.app.linked
                    onClicked: fab.act.primaryAction()
                }

                Tip {
                    text: !side.full && fab.act ? fab.act.primaryLabel : ""
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durFastEffects
                    }

                }

            }

            // the pill for the page you are on. going to another it stretches: the
            // edge on the way leads, the other follows and closes up behind it,
            // with nothing overshooting the row
            Rectangle {
                id: glider

                // its edges: Item's own top and bottom are anchor lines, final
                property real upper: 0
                property real lower: 0
                property bool settled: false

                // glide: to another row; otherwise the row itself moved (the
                // window grew under the settings row), and both edges go together
                function follow(glide) {
                    const r = side.activeRow;
                    if (!r) {
                        glider.settled = false;
                        return ;
                    }
                    const t = r.rowTop, b = r.rowTop + r.height;
                    if (!glider.settled || Theme.motionScale <= 0 || !clockWin.visible) {
                        edges.stop();
                        glider.upper = t;
                        glider.lower = b;
                        glider.settled = true;
                        return ;
                    }
                    if (Math.abs(t - glider.upper) < 0.5 && Math.abs(b - glider.lower) < 0.5)
                        return ;

                    const down = t > glider.upper;
                    const lead = glide ? Theme.ms(200) : Theme.ms(260);
                    const trail = glide ? Theme.ms(330) : Theme.ms(260);
                    topAnim.to = t;
                    bottomAnim.to = b;
                    topAnim.duration = down ? trail : lead;
                    bottomAnim.duration = down ? lead : trail;
                    topAnim.easing.bezierCurve = down ? Theme.curveStandard : Theme.easeEmphasizedDecel;
                    bottomAnim.easing.bezierCurve = down ? Theme.easeEmphasizedDecel : Theme.curveStandard;
                    edges.restart();
                }

                x: Theme.dp(8)
                y: glider.upper
                width: side.width - Theme.dp(16)
                height: Math.max(0, glider.lower - glider.upper)
                radius: Math.min(height, side.rowH) / 2
                color: Theme.accentContainer
                opacity: side.activeRow ? 1 : 0
                scale: side.activeRow ? 1 : 0.94
                visible: opacity > 0

                ParallelAnimation {
                    id: edges

                    NumberAnimation {
                        id: topAnim

                        target: glider
                        property: "upper"
                        easing.type: Easing.BezierSpline
                    }

                    NumberAnimation {
                        id: bottomAnim

                        target: glider
                        property: "lower"
                        easing.type: Easing.BezierSpline
                    }

                }

                Connections {
                    function onActiveRowChanged() {
                        glider.follow(true);
                    }

                    target: side
                }

                Connections {
                    function onRowTopChanged() {
                        glider.follow(false);
                    }

                    target: side.activeRow
                    ignoreUnknownSignals: true
                }

            }

            Column {
                id: list

                y: fab.y + fab.height + Theme.dp(22)
                width: side.width

                Repeater {
                    model: clockWin.pages.slice(0, clockWin.pages.length - 1)

                    delegate: SideRow {
                        entry: modelData
                        slot: index
                        rowTop: list.y + y
                    }

                }

            }

            SideRow {
                id: settingsRow

                entry: clockWin.pages[clockWin.pages.length - 1]
                slot: clockWin.pages.length - 1
                y: side.height - height - Theme.dp(14)
                rowTop: y
            }

        }

        // ---- the page, on a sunken pane clear of the window's edges
        Rectangle {
            id: pane

            anchors.left: side.right
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.dp(12)
            anchors.rightMargin: Theme.dp(12)
            anchors.bottomMargin: Theme.dp(12)
            color: Theme.withBlur(Theme.bgSunken)
            radius: Theme.shapeXl
            clip: true

            Item {
                id: stack

                width: pane.width
                height: pane.height * clockWin.pages.length
                y: -clockWin.pageIndex * pane.height

                Behavior on y {
                    enabled: clockWin.switching

                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Repeater {
                    id: pageRepeater

                    model: clockWin.pages

                    delegate: Loader {
                        required property var modelData
                        required property int index
                        readonly property bool shown: index === clockWin.pageIndex
                        property bool visited: false
                        // the page's own api, through the loader, for the sidebar and the keys
                        readonly property string primaryIcon: item && item.primaryIcon ? item.primaryIcon : ""
                        readonly property string primaryLabel: item && item.primaryLabel ? item.primaryLabel : ""

                        function primaryAction() {
                            if (item && item.primaryAction)
                                item.primaryAction();

                        }

                        function handleKey(e) {
                            return item && item.handleKey ? item.handleKey(e) : false;
                        }

                        onShownChanged: {
                            if (shown)
                                visited = true;

                        }
                        Component.onCompleted: visited = shown
                        y: index * pane.height
                        width: pane.width
                        height: pane.height
                        // a page is built the first time it is visited, and kept
                        active: visited
                        visible: shown || clockWin.switching
                        sourceComponent: {
                            switch (modelData.key) {
                            case "alarms":
                                return alarmsPage;
                            case "clock":
                                return clockPage;
                            case "timer":
                                return timerPage;
                            case "stopwatch":
                                return stopwatchPage;
                            case "focus":
                                return focusPage;
                            case "reminders":
                                return remindersPage;
                            }
                            return settingsPage;
                        }
                    }

                }

            }

            // the shell is not answering
            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.bgSunken, 0.94)
                visible: opacity > 0
                opacity: clockWin.app.linked ? 0 : 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.AllButtons
                    onWheel: (w) => {
                        return w.accepted = true;
                    }
                }

                Column {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Theme.dp(64), Theme.dp(420))
                    spacing: Theme.dp(14)

                    LoadingIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    LText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        role: "titleLarge"
                        text: "Waiting for Lucid"
                    }

                    LText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        role: "bodyMedium"
                        color: Theme.subtext
                        text: "Alarms, timers and reminders run in the shell, so they keep time with this window closed. This connects by itself once the shell is up."
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

        }

        // over the reminder editor, which opens it for the reminder's time
        TimePicker {
            id: picker

            anchors.fill: parent
            app: clockWin.app
            z: 310
        }

        ReminderEditor {
            id: reminderEditor

            anchors.fill: parent
            app: clockWin.app
            win: clockWin
            z: 300
        }

        RingOverlay {
            anchors.fill: parent
            app: clockWin.app
            z: 320
        }

        Snackbar {
            id: snack

            z: 350
            onActed: (payload) => {
                if (payload && payload.undo)
                    payload.undo();

            }
        }

        LumenMenu {
            id: menu

            z: 400
        }

    }

    Component {
        id: alarmsPage

        AlarmPage {
            app: clockWin.app
            win: clockWin
            shown: clockWin.page === "alarms"
        }

    }

    Component {
        id: clockPage

        WorldPage {
            app: clockWin.app
            win: clockWin
            shown: clockWin.page === "clock"
        }

    }

    Component {
        id: timerPage

        TimerPage {
            app: clockWin.app
            win: clockWin
            shown: clockWin.page === "timer"
        }

    }

    Component {
        id: stopwatchPage

        StopwatchPage {
            app: clockWin.app
            win: clockWin
            shown: clockWin.page === "stopwatch"
        }

    }

    Component {
        id: focusPage

        FocusPage {
            app: clockWin.app
            win: clockWin
            shown: clockWin.page === "focus"
        }

    }

    Component {
        id: remindersPage

        RemindersPage {
            app: clockWin.app
            win: clockWin
            shown: clockWin.page === "reminders"
        }

    }

    Component {
        id: settingsPage

        SettingsPage {
            app: clockWin.app
            win: clockWin
            shown: clockWin.page === "settings"
        }

    }

    // a page in the sidebar: Lumen's row. its glyph and words light as the
    // pill arrives, not before, and the glyph swells under the pointer
    component SideRow: Item {
        id: row

        property var entry: ({
            "key": "",
            "label": "",
            "icon": ""
        })
        property int slot: 0
        // where it sits in the sidebar, which the pill measures against
        property real rowTop: 0
        readonly property bool on: row.slot === clockWin.pageIndex
        property real swell: area.pressed ? 0.92 : (area.containsMouse ? 1.12 : 1)
        readonly property real lit: {
            const t = Math.max(row.rowTop, glider.upper), b = Math.min(row.rowTop + row.height, glider.lower);
            return Math.max(0, Math.min(1, (b - t) / Math.max(1, row.height))) * glider.opacity;
        }
        readonly property bool arrived: row.on && row.lit > 0.5
        readonly property color ink: Qt.tint(Theme.text, Qt.rgba(Theme.fgAccentContainer.r, Theme.fgAccentContainer.g, Theme.fgAccentContainer.b, row.lit))
        readonly property color softInk: Qt.tint(Theme.subtext, Qt.rgba(Theme.fgAccentContainer.r, Theme.fgAccentContainer.g, Theme.fgAccentContainer.b, row.lit))

        width: side.width
        height: side.rowH
        onOnChanged: {
            if (row.on)
                side.activeRow = row;
            else if (side.activeRow === row)
                Qt.callLater(side.letGo, row);
        }
        Component.onCompleted: {
            if (row.on)
                side.activeRow = row;

        }
        Component.onDestruction: {
            if (side.activeRow === row)
                side.activeRow = null;

        }

        StateLayer {
            id: area

            anchors.fill: undefined
            x: Theme.dp(8)
            width: parent.width - Theme.dp(16)
            height: parent.height
            radius: height / 2
            onClicked: clockWin.go(row.entry.key)
        }

        Icon {
            x: side.full ? Theme.dp(26) : (row.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            name: row.entry.icon
            size: Theme.dp(22)
            fill: row.arrived ? 1 : 0
            color: row.softInk
            animateColor: false
            scale: row.swell

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

        }

        LText {
            visible: side.full
            x: Theme.dp(62)
            anchors.verticalCenter: parent.verticalCenter
            role: "titleSmall"
            weight: row.arrived ? 650 : 520
            color: row.ink
            text: row.entry.label
        }

        Tip {
            text: side.full ? "" : row.entry.label
        }

    }

}
