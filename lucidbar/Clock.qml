import QtQuick
import Quickshell
import Quickshell.Io
import "../lucidwidgets"
import qs
import qs.lucidui

// the bar's clock, and behind it a clock app: today, the calendar, timers,
// a stopwatch and the time elsewhere
BarPill {
    id: root

    property string tab: "today"
    property bool tabSwitching: false
    property date now: Loc.now()
    readonly property var headline: Chrono.headline
    readonly property var wx: WeatherSource.report
    readonly property var tabs: [
        { "key": "today", "label": "Today", "icon": "wb_sunny" },
        { "key": "calendar", "label": "Calendar", "icon": "calendar_month" },
        { "key": "timer", "label": "Timer", "icon": "hourglass_top" },
        { "key": "stopwatch", "label": "Stopwatch", "icon": "timer" },
        { "key": "world", "label": "World", "icon": "public" }
    ]
    readonly property int tabIndex: {
        for (var i = 0; i < root.tabs.length; i++) {
            if (root.tabs[i].key === root.tab)
                return i;

        }
        return 0;
    }
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int pad: Theme.dp(16)

    function showTab(t) {
        if (t === root.tab)
            return ;

        root.tabSwitching = true;
        tabSwitchTimer.restart();
        root.tab = t;
    }

    function openTab(t) {
        root.tab = t;
        root.expanded = true;
    }

    function hourText(d) {
        var h = d.getHours();
        return Prefs.clock24h ? String(h).padStart(2, "0") : String(h % 12 === 0 ? 12 : h % 12);
    }

    shown: Prefs.barHas("clock")
    compactWidth: compactRow.implicitWidth + Theme.dp(30)
    panelWidth: Math.min(Theme.dp(720), root.screenW - Theme.dp(34))
    panelHeight: Math.min(root.screenH - Theme.dp(60), root.pad + tabsBar.height + Theme.dp(10) + Theme.dp(404) + root.pad)
    expandedRadius: Theme.shapeXl
    compactCollapseScale: 0.9
    // a reminder going off rides the pill's alt surface
    altOpen: Agenda.firing !== null && !root.expanded
    altWidth: Theme.dp(340)
    altHeight: Theme.dp(76)
    onExpandedChanged: {
        if (!root.expanded)
            tabResetTimer.restart();

    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = Loc.now()
    }

    Timer {
        id: tabSwitchTimer

        interval: Theme.barMs(600)
        onTriggered: root.tabSwitching = false
    }

    Timer {
        id: tabResetTimer

        interval: Theme.barMs(700)
        onTriggered: {
            if (!root.expanded)
                root.tab = "today";

        }
    }

    IpcHandler {
        target: "clock"

        // qs ipc call clock open timer
        function open(page: string): void {
            root.openTab(page === "" ? "today" : page);
        }

        function toggle(): void {
            root.expanded = !root.expanded;
        }

        function close(): void {
            root.expanded = false;
        }
    }

    compactContent: [
        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: Theme.dp(8)

            // lucidshot is recording; a click brings its toolbar back
            Rectangle {
                id: recChip

                visible: Capture.active
                anchors.verticalCenter: parent.verticalCenter
                width: recRow.implicitWidth + Theme.dp(16)
                height: Theme.dp(24)
                radius: Theme.dp(12)
                color: Theme.errorContainer

                Row {
                    id: recRow

                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(8)
                        height: Theme.dp(8)
                        radius: Theme.dp(4)
                        color: Theme.error

                        SequentialAnimation on opacity {
                            running: recChip.visible && Capture.state === "recording"
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.25
                                duration: 700
                            }

                            NumberAnimation {
                                to: 1
                                duration: 700
                            }

                        }

                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        weight: 660
                        tabular: true
                        color: Theme.fgErrorContainer
                        text: Capture.state === "paused" ? "Paused" : Capture.clock(Capture.seconds)
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Capture.hidden ? Capture.showRequested() : Quickshell.execDetached(["qs", "ipc", "call", "snap", "video"])
                }

            }

            // whatever is counting down, or up
            Rectangle {
                id: timerChip

                readonly property var h: root.headline

                visible: Prefs.clockShowTimer && timerChip.h !== null
                anchors.verticalCenter: parent.verticalCenter
                width: chipRow.implicitWidth + Theme.dp(16)
                height: Theme.dp(24)
                radius: Theme.dp(12)
                color: Theme.secondaryContainer

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: Theme.dp(5)

                    Item {
                        width: Theme.dp(15)
                        height: Theme.dp(15)
                        anchors.verticalCenter: parent.verticalCenter

                        CircularProgress {
                            anchors.fill: parent
                            visible: timerChip.h !== null && timerChip.h.total > 0
                            thickness: 2.5
                            value: timerChip.h && timerChip.h.total > 0 ? timerChip.h.left / timerChip.h.total : 0
                            color: Theme.fgSecondaryContainer
                            trackColor: Theme.alpha(Theme.fgSecondaryContainer, 0.25)
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: timerChip.h !== null && timerChip.h.total <= 0
                            name: "timer"
                            size: Theme.dp(15)
                            fill: 1
                            color: Theme.fgSecondaryContainer
                        }

                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        weight: 660
                        rounded: 100
                        tabular: true
                        color: Theme.fgSecondaryContainer
                        opacity: timerChip.h && !timerChip.h.running ? 0.6 : 1
                        text: !timerChip.h ? "" : (timerChip.h.kind === "stopwatch" ? Chrono.clock(timerChip.h.left, false) : Chrono.countdown(timerChip.h.left))
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openTab(timerChip.h && timerChip.h.kind === "stopwatch" ? "stopwatch" : "timer")
                }

            }

            // the date reads as context, the time as the thing itself: an accent
            // chip is the one fill the bar carries on live data
            LText {
                visible: Prefs.clockShowDate
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                size: Theme.fs(12.5)
                weight: 560
                color: Theme.subtext
                text: root.now.toLocaleDateString(Qt.locale(), "ddd, dd/MM")
            }

            Rectangle {
                id: timeChip

                anchors.verticalCenter: parent.verticalCenter
                width: timeRow.implicitWidth + Theme.dp(17)
                height: Math.min(parent.height, Math.round(Theme.dp(Prefs.barHeight) * 0.66))
                radius: height / 2
                color: Theme.primary

                // the ink on an accent fill, not the deepest surface tone: that one is
                // near-black on most palettes and carries none of their hue
                Row {
                    id: timeRow

                    anchors.centerIn: parent
                    spacing: 0

                    LText {
                        id: hourText

                        role: "labelLarge"
                        size: Theme.fs(13.5)
                        weight: 700
                        rounded: 100
                        tabular: true
                        color: Theme.fgAccent
                        text: root.hourText(root.now)
                    }

                    LText {
                        role: "labelLarge"
                        size: Theme.fs(13.5)
                        weight: 700
                        rounded: 100
                        color: Theme.fgAccent
                        text: ":"
                        opacity: root.now.getSeconds() % 2 === 0 || Prefs.clockShowSeconds ? 1 : 0.35

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(400)
                            }

                        }

                    }

                    LText {
                        role: "labelLarge"
                        size: Theme.fs(13.5)
                        weight: 700
                        rounded: 100
                        tabular: true
                        color: Theme.fgAccent
                        text: String(root.now.getMinutes()).padStart(2, "0")
                    }

                    LText {
                        visible: Prefs.clockShowSeconds
                        anchors.baseline: hourText.baseline
                        leftPadding: Theme.dp(2)
                        role: "labelMedium"
                        weight: 600
                        tabular: true
                        color: Theme.alpha(Theme.fgAccent, 0.7)
                        text: String(root.now.getSeconds()).padStart(2, "0")
                    }

                    LText {
                        visible: !Prefs.clock24h
                        anchors.baseline: hourText.baseline
                        leftPadding: Theme.dp(4)
                        role: "labelMedium"
                        weight: 600
                        color: Theme.alpha(Theme.fgAccent, 0.7)
                        // the locale's own meridiem ("PM", "P.M.", "午後")
                        text: root.now.toLocaleTimeString(Qt.locale(), "AP")
                    }

                }

            }

            Row {
                visible: Prefs.clockShowWeather && root.wx !== null
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(3)

                WeatherIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(20)
                    animate: false
                    kind: root.wx ? WeatherSource.kindFor(root.wx.code, !root.wx.isDay) : "clear"
                    tint: Theme.accent
                    cloudColor: Theme.subtext
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    size: Theme.fs(13.5)
                    weight: 600
                    rounded: 100
                    text: root.wx ? root.wx.tempC + "°" : ""
                }

            }

            Icon {
                id: bell

                visible: Agenda.soon
                anchors.verticalCenter: parent.verticalCenter
                name: "notifications_active"
                size: Theme.dp(15)
                fill: 1
                color: Theme.accent
                transformOrigin: Item.Top

                SequentialAnimation on rotation {
                    loops: Animation.Infinite
                    running: bell.visible

                    NumberAnimation {
                        from: 0
                        to: -14
                        duration: Theme.barMs(100)
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        from: -14
                        to: 14
                        duration: Theme.barMs(160)
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        from: 14
                        to: 0
                        duration: Theme.barMs(140)
                        easing.type: Easing.OutQuad
                    }

                    PauseAnimation {
                        duration: Theme.barMs(2800)
                    }

                }

            }

        }
    ]

    altContent: [
        Item {
            anchors.fill: parent

            Item {
                id: bellBox

                x: Theme.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(46)
                height: Theme.dp(46)

                MaterialShape {
                    anchors.fill: parent
                    shape: "cookie9"
                    color: Theme.primaryContainer

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 8000
                        loops: Animation.Infinite
                        running: root.altOpen
                    }

                }

                Icon {
                    anchors.centerIn: parent
                    name: "notifications_active"
                    size: Theme.dp(24)
                    fill: 1
                    color: Theme.fgPrimaryContainer
                    transformOrigin: Item.Top

                    SequentialAnimation on rotation {
                        loops: Animation.Infinite
                        running: root.altOpen

                        NumberAnimation {
                            from: -16
                            to: 16
                            duration: Theme.barMs(180)
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            from: 16
                            to: -16
                            duration: Theme.barMs(180)
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

            }

            Column {
                anchors.left: bellBox.right
                anchors.leftMargin: Theme.dp(12)
                anchors.right: actions.left
                anchors.rightMargin: Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                LText {
                    width: parent.width
                    role: "titleSmall"
                    text: Agenda.firing ? Agenda.firing.name : ""
                    elide: Text.ElideRight
                }

                LText {
                    role: "bodySmall"
                    color: Theme.subtext
                    text: Agenda.firing ? Agenda.timeText(Agenda.firing) + (Agenda.ringing.length > 1 ? "  ·  +" + (Agenda.ringing.length - 1) + " more" : "") : ""
                }

            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(6)

                Button {
                    variant: "tonal"
                    size: "xs"
                    text: "10 min"
                    icon: "snooze"
                    onClicked: {
                        if (Agenda.firing)
                            Agenda.snooze(Agenda.firing.id, 10);

                    }
                }

                IconButton {
                    variant: "filled"
                    size: "xs"
                    icon: "check"
                    onClicked: {
                        if (Agenda.firing)
                            Agenda.dismiss(Agenda.firing.id);

                    }
                }

            }

        }
    ]

    panelContent: [
        Item {
            anchors.fill: parent

            Tabs {
                id: tabsBar

                x: root.pad
                y: root.pad - Theme.dp(6)
                width: parent.width - root.pad * 2
                inline: true
                options: root.tabs
                current: root.tab
                onPicked: (k) => {
                    return root.showTab(k);
                }
            }

            Item {
                id: viewport

                anchors.top: tabsBar.bottom
                anchors.topMargin: Theme.dp(10)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.pad
                anchors.rightMargin: root.pad
                height: Theme.dp(404)
                clip: true

                // pages side by side; a tab change pushes one out as the next comes in
                // explicit x per page: a Row would close the gaps of the hidden ones
                Item {
                    id: pages

                    x: -root.tabIndex * viewport.width
                    width: viewport.width * root.tabs.length
                    height: viewport.height

                    Behavior on x {
                        enabled: root.tabSwitching

                        NumberAnimation {
                            duration: root.morphDuration
                            easing.type: Easing.Bezier
                            easing.bezierCurve: root.morphEasing
                        }

                    }

                    ClockToday {
                        x: 0 * viewport.width
                        width: viewport.width
                        height: viewport.height
                        host: root
                        visible: root.tabIndex === 0 || root.tabSwitching
                        onAddRequested: {
                            root.showTab("calendar");
                            calendarPage.selectToday();
                            calendarPage.focusName();
                        }
                    }

                    ClockCalendar {
                        x: 1 * viewport.width
                        id: calendarPage

                        width: viewport.width
                        height: viewport.height
                        host: root
                        visible: root.tabIndex === 1 || root.tabSwitching
                    }

                    ClockTimers {
                        x: 2 * viewport.width
                        width: viewport.width
                        height: viewport.height
                        host: root
                        visible: root.tabIndex === 2 || root.tabSwitching
                    }

                    ClockStopwatch {
                        x: 3 * viewport.width
                        width: viewport.width
                        height: viewport.height
                        host: root
                        visible: root.tabIndex === 3 || root.tabSwitching
                    }

                    ClockWorld {
                        x: 4 * viewport.width
                        width: viewport.width
                        height: viewport.height
                        host: root
                        visible: root.tabIndex === 4 || root.tabSwitching
                    }

                }

            }

        }
    ]

}
