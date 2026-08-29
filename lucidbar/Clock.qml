import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Io
import qs

BarPill {
    id: root

    readonly property string hourFormat: Prefs.clock24h ? "HH" : "hh AP"
    readonly property string minuteFormat: Prefs.clock24h ? "mm" : "mm AP"
    readonly property string fullTimeFormat: Prefs.clock24h ? "H:mm:ss" : "h:mm:ss AP"
    readonly property int horizontalPadding: 17
    property real lat: 52.2297
    property real lon: 21.0122
    property real temp: 0
    property int humidity: 0
    property int weatherCode: 0
    property real feelsLike: 0
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    readonly property bool isViewingCurrentMonth: {
        const now = new Date();
        return root.viewYear === now.getFullYear() && root.viewMonth === now.getMonth();
    }
    property bool calFrontIsA: true
    property int clockTick: 0
    readonly property bool isNight: {
        root.clockTick;
        const h = new Date().getHours();
        return h < 6 || h >= 20;
    }
    property var editingDate: null
    property string reminderMeridiem: "AM"
    property var notifyQueue: []
    readonly property var firingReminder: notifyQueue.length > 0 ? notifyQueue[0] : null
    readonly property bool showingNotify: firingReminder !== null && !root.expanded
    property var dismissedToday: ({
    })
    property var snoozedUntil: ({
    })
    property string lastCheckedDay: ""
    readonly property bool hasUpcomingReminder: {
        root.clockTick;
        const now = new Date();
        now.setHours(0, 0, 0, 0);
        for (const r of remindersAdapter.items) {
            const d = new Date(r.year, r.month, r.day);
            d.setHours(0, 0, 0, 0);
            const diffDays = Math.round((d - now) / 8.64e+07);
            if (diffDays >= 0 && diffDays <= 7)
                return true;

        }
        return false;
    }

    readonly property var nextReminder: {
        root.clockTick;
        const now = new Date();
        let best = null;
        let bestAt = null;
        for (const r of remindersAdapter.items) {
            const at = new Date(r.year, r.month, r.day, r.hour, r.minute, 0, 0);
            if (at < now)
                continue;

            if (bestAt === null || at < bestAt) {
                best = r;
                bestAt = at;
            }
        }
        return best ? {
            "item": best,
            "at": bestAt
        } : null;
    }

    function untilText(at) {
        if (!at)
            return "";

        const mins = Math.round((at - new Date()) / 60000);
        if (mins < 1)
            return "now";

        if (mins < 60)
            return "in " + mins + " min";

        const hrs = Math.round(mins / 60);
        if (hrs < 24)
            return "in " + hrs + (hrs === 1 ? " hour" : " hours");

        const days = Math.round(hrs / 24);
        return days === 1 ? "tomorrow" : "in " + days + " days";
    }

    function weatherIconCategory(code, night) {
        if (code === 0)
            return night ? "clear-night" : "sunny";

        if (code <= 3)
            return night ? "partly-night" : "partly";

        if (code <= 48)
            return "fog";

        if (code <= 67)
            return "rain";

        if (code <= 77)
            return "snow";

        if (code <= 82)
            return "rain";

        if (code <= 99)
            return "storm";

        return "cloudy";
    }

    function weatherDesc(code) {
        if (code === 0)
            return "Clear";

        if (code <= 3)
            return "Partly Cloudy";

        if (code <= 48)
            return "Foggy";

        if (code <= 67)
            return "Rainy";

        if (code <= 77)
            return "Snowy";

        if (code <= 82)
            return "Rain Showers";

        if (code <= 99)
            return "Thunderstorm";

        return "—";
    }

    function buildCalendarModel(year, month) {
        const now = new Date();
        const isCurrentMonth = year === now.getFullYear() && month === now.getMonth();
        const today = now.getDate();
        const firstDay = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrevMonth = new Date(year, month, 0).getDate();
        let prevY = year, prevM = month - 1;
        if (prevM < 0) {
            prevM = 11;
            prevY -= 1;
        }
        let nextY = year, nextM = month + 1;
        if (nextM > 11) {
            nextM = 0;
            nextY += 1;
        }
        let cells = [];
        for (let i = firstDay - 1; i >= 0; i--) cells.push({
            "day": daysInPrevMonth - i,
            "year": prevY,
            "month": prevM,
            "other": true,
            "today": false
        })
        for (let i = 1; i <= daysInMonth; i++) cells.push({
            "day": i,
            "year": year,
            "month": month,
            "other": false,
            "today": isCurrentMonth && i === today
        })
        const remaining = 42 - cells.length;
        for (let i = 1; i <= remaining; i++) cells.push({
            "day": i,
            "year": nextY,
            "month": nextM,
            "other": true,
            "today": false
        })
        return cells;
    }

    function transitionToMonth(newYear, newMonth, dir) {
        const incoming = root.calFrontIsA ? calGridB : calGridA;
        const outgoing = root.calFrontIsA ? calGridA : calGridB;
        incoming.cells = root.buildCalendarModel(newYear, newMonth);
        incoming.z = 1;
        outgoing.z = 0;
        incoming.suppressMotion = true;
        incoming.x = dir * calViewport.width;
        incoming.opacity = 0;
        incoming.suppressMotion = false;
        incoming.x = 0;
        incoming.opacity = 1;
        outgoing.x = -dir * calViewport.width;
        outgoing.opacity = 0;
        root.calFrontIsA = !root.calFrontIsA;
        root.viewYear = newYear;
        root.viewMonth = newMonth;
    }

    function resyncCalendarGrids() {
        const front = root.calFrontIsA ? calGridA : calGridB;
        const back = root.calFrontIsA ? calGridB : calGridA;
        front.cells = root.buildCalendarModel(root.viewYear, root.viewMonth);
        front.suppressMotion = true;
        front.x = 0;
        front.opacity = 1;
        front.z = 1;
        front.suppressMotion = false;
        back.suppressMotion = true;
        back.x = calViewport.width;
        back.opacity = 0;
        back.z = 0;
        back.suppressMotion = false;
    }

    function addReminder(year, month, day, hour, minute, name) {
        const item = {
            "id": Date.now() + "-" + Math.random().toString(36).slice(2, 7),
            "year": year,
            "month": month,
            "day": day,
            "hour": hour,
            "minute": minute,
            "name": name
        };
        var arr = remindersAdapter.items.slice();
        arr.push(item);
        remindersAdapter.items = arr;
    }

    function removeReminder(id) {
        remindersAdapter.items = remindersAdapter.items.filter((r) => {
            return r.id !== id;
        });
    }

    function remindersFor(year, month, day) {
        return remindersAdapter.items.filter((r) => {
            return r.year === year && r.month === month && r.day === day;
        });
    }

    function hasReminderOn(year, month, day) {
        return root.remindersFor(year, month, day).length > 0;
    }

    function submitNewReminder() {
        if (!root.editingDate)
            return ;

        const name = reminderNameInput.text.trim();
        if (!name)
            return ;

        let hour12 = parseInt(reminderHourInput.text, 10);
        let minute = parseInt(reminderMinuteInput.text, 10);
        if (isNaN(hour12) || hour12 < 1 || hour12 > 12)
            hour12 = 9;

        if (isNaN(minute))
            minute = 0;

        minute = Math.max(0, Math.min(59, minute));
        let hour = hour12 % 12;
        if (root.reminderMeridiem === "PM")
            hour += 12;

        root.addReminder(root.editingDate.year, root.editingDate.month, root.editingDate.day, hour, minute, name);
        reminderNameInput.text = "";
        reminderHourInput.text = "9";
        reminderMinuteInput.text = "00";
        root.reminderMeridiem = "AM";
    }

    function fmtHour12(date) {
        const h = date.getHours() % 12 || 12;
        return h < 10 ? "0" + h : "" + h;
    }

    function fmtReminderTime(r) {
        if (!r)
            return "";

        const h = r.hour % 12 === 0 ? 12 : r.hour % 12;
        const ap = r.hour < 12 ? "AM" : "PM";
        const mm = r.minute < 10 ? "0" + r.minute : r.minute;
        return h + ":" + mm + " " + ap;
    }

    function cleanupPastReminders(now) {
        const y = now.getFullYear(), m = now.getMonth(), d = now.getDate();
        const kept = remindersAdapter.items.filter((r) => {
            return !(r.year < y || (r.year === y && r.month < m) || (r.year === y && r.month === m && r.day < d));
        });
        if (kept.length !== remindersAdapter.items.length)
            remindersAdapter.items = kept;

    }

    function checkReminders() {
        const now = new Date();
        const todayKey = now.getFullYear() + "-" + now.getMonth() + "-" + now.getDate();
        if (root.lastCheckedDay !== todayKey) {
            root.dismissedToday = {
            };
            root.cleanupPastReminders(now);
            root.lastCheckedDay = todayKey;
        }
        for (const r of remindersAdapter.items) {
            if (root.dismissedToday[r.id])
                continue;

            if (root.notifyQueue.some((q) => {
                return q.id === r.id;
            }))
                continue;

            const snoozeTarget = root.snoozedUntil[r.id];
            if (snoozeTarget && now.getTime() < snoozeTarget)
                continue;

            const due = new Date(r.year, r.month, r.day, r.hour, r.minute, 0);
            if (now >= due)
                root.notifyQueue = root.notifyQueue.concat([r]);

        }
    }

    function snoozeReminder(id, minutes) {
        const m = Object.assign({
        }, root.snoozedUntil);
        m[id] = Date.now() + minutes * 60000;
        root.snoozedUntil = m;
        root.notifyQueue = root.notifyQueue.filter((q) => {
            return q.id !== id;
        });
    }

    function dismissReminder(id) {
        const m = Object.assign({
        }, root.dismissedToday);
        m[id] = true;
        root.dismissedToday = m;
        root.notifyQueue = root.notifyQueue.filter((q) => {
            return q.id !== id;
        });
    }

    function goPrevMonth() {
        let m = root.viewMonth - 1;
        let y = root.viewYear;
        if (m < 0) {
            m = 11;
            y -= 1;
        }
        root.transitionToMonth(y, m, -1);
    }

    function goNextMonth() {
        let m = root.viewMonth + 1;
        let y = root.viewYear;
        if (m > 11) {
            m = 0;
            y += 1;
        }
        root.transitionToMonth(y, m, 1);
    }

    function goToday() {
        const now = new Date();
        const newYear = now.getFullYear();
        const newMonth = now.getMonth();
        const dir = (newYear * 12 + newMonth) >= (root.viewYear * 12 + root.viewMonth) ? 1 : -1;
        root.transitionToMonth(newYear, newMonth, dir);
    }

    shown: Prefs.showClock
    compactWidth: compactRow.implicitWidth + root.horizontalPadding * 2
    panelWidth: Math.min(620, root.screenW - 34)
    panelHeight: Math.min(root.maxPanelHeight, expandedRow.implicitHeight + 32)
    // reminder toast, on BarPill's alt surface
    altOpen: root.showingNotify
    altWidth: 270
    altHeight: 78
    expandedRadius: 20

    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int maxPanelHeight: Math.min(560, Math.max(240, root.screenH - 40))

    Component.onCompleted: root.resyncCalendarGrids()
    onExpandedChanged: {
        if (expanded) {
            const now = new Date();
            root.viewYear = now.getFullYear();
            root.viewMonth = now.getMonth();
            root.calFrontIsA = true;
            root.resyncCalendarGrids();
        } else {
            root.editingDate = null;
        }
    }

    FileView {
        id: remindersFile

        path: Qt.resolvedUrl("./clock_reminders.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: remindersAdapter

            property var items: []
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockHourText.text = new Date().toLocaleTimeString(Qt.locale(), root.hourFormat).replace(/\s*[AP]M/i, "");
            clockMinuteText.text = new Date().toLocaleTimeString(Qt.locale(), root.minuteFormat);
            dateText.text = new Date().toLocaleDateString(Qt.locale(), "ddd d");
            expandedTimeText.text = new Date().toLocaleTimeString(Qt.locale(), root.fullTimeFormat);
            expandedDateText.text = new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d");
            root.clockTick++;
            root.checkReminders();
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Process {
        id: weatherProc

        command: ["curl", "-s", "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon + "&current=temperature_2m,relative_humidity_2m,weather_code,apparent_temperature"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.temp = Math.round(data.current.temperature_2m);
                    root.humidity = Math.round(data.current.relative_humidity_2m);
                    root.weatherCode = data.current.weather_code;
                    root.feelsLike = Math.round(data.current.apparent_temperature);
                } catch (e) {
                    console.log("weather parse failed:", e);
                }
            }
        }

    }

    compactContent: [
        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: 8

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    id: clockHourText

                    text: new Date().toLocaleTimeString(Qt.locale(), root.hourFormat).replace(/\s*[AP]M/i, "")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                }

                Text {
                    id: clockColonText

                    text: ":"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: true

                        NumberAnimation {
                            from: 1
                            to: 0.45
                            duration: Theme.barMs(500)
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            from: 0.45
                            to: 1
                            duration: Theme.barMs(500)
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

                Text {
                    id: clockMinuteText

                    text: new Date().toLocaleTimeString(Qt.locale(), root.minuteFormat)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                }

            }

            Rectangle {
                visible: Prefs.clockShowDate
                width: 3
                height: 3
                radius: 1.5
                color: Theme.subtextDim
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: dateText

                anchors.verticalCenter: parent.verticalCenter
                text: new Date().toLocaleDateString(Qt.locale(), "ddd d")
                visible: Prefs.clockShowDate
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fs(13)
            }

            Item {
                id: bellIcon

                visible: root.hasUpcomingReminder
                width: 12
                height: 12
                anchors.verticalCenter: parent.verticalCenter

                Shape {
                    id: bellShape

                    width: 24
                    height: 24
                    scale: 12 / 24
                    anchors.centerIn: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.accent
                        strokeWidth: 0

                        PathSvg {
                            path: "M8 10A4 6 0 0 1 16 10L18 17H6Z M12 17.7a1.3 1.3 0 1 0 0 2.6 1.3 1.3 0 0 0 0-2.6Z"
                        }

                    }

                    SequentialAnimation on rotation {
                        loops: Animation.Infinite
                        running: root.hasUpcomingReminder

                        NumberAnimation {
                            from: 0
                            to: -12
                            duration: Theme.barMs(100)
                            easing.type: Easing.OutQuad
                        }

                        NumberAnimation {
                            from: -12
                            to: 12
                            duration: Theme.barMs(160)
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            from: 12
                            to: -8
                            duration: Theme.barMs(140)
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            from: -8
                            to: 0
                            duration: Theme.barMs(100)
                            easing.type: Easing.OutQuad
                        }

                        PauseAnimation {
                            duration: Theme.barMs(2600)
                        }

                    }

                }

            }

        }
    ]

    altContent: [
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Row {
                width: parent.width
                spacing: 8

                Item {
                    id: ringingBellBox

                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    Shape {
                        width: 24
                        height: 24
                        scale: 20 / 24
                        anchors.centerIn: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.accent
                            strokeWidth: 0

                            PathSvg {
                                path: "M8 10A4 6 0 0 1 16 10L18 17H6Z M12 17.7a1.3 1.3 0 1 0 0 2.6 1.3 1.3 0 0 0 0-2.6Z"
                            }

                        }

                        SequentialAnimation on rotation {
                            loops: Animation.Infinite
                            running: root.showingNotify

                            NumberAnimation {
                                from: 0
                                to: -16
                                duration: Theme.barMs(110)
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                from: -16
                                to: 16
                                duration: Theme.barMs(180)
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                from: 16
                                to: -14
                                duration: Theme.barMs(170)
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                from: -14
                                to: 10
                                duration: Theme.barMs(150)
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                from: 10
                                to: 0
                                duration: Theme.barMs(120)
                                easing.type: Easing.OutQuad
                            }

                            PauseAnimation {
                                duration: Theme.barMs(500)
                            }

                        }

                    }

                }

                Text {
                    width: parent.width - 22 - 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.firingReminder ? root.firingReminder.name : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontTitle
                    elide: Text.ElideRight
                }

            }

            Item {
                width: parent.width
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.fmtReminderTime(root.firingReminder)
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        id: snoozeBtn

                        height: 24
                        width: snoozeLabel.implicitWidth + 16
                        radius: 999
                        color: snoozeArea.containsMouse ? Theme.withBlur(Theme.bgHigh) : Theme.withBlur(Theme.cContainer)
                        scale: snoozeArea.pressed ? 0.92 : 1

                        Text {
                            id: snoozeLabel

                            anchors.centerIn: parent
                            text: "Snooze"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fontLabel
                        }

                        MouseArea {
                            id: snoozeArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.firingReminder)
                                    root.snoozeReminder(root.firingReminder.id, 10);

                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barDurQuick
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                    Rectangle {
                        id: closeBtn

                        height: 24
                        width: closeLabel.implicitWidth + 16
                        radius: 999
                        color: closeArea.containsMouse ? Theme.accentHover : Theme.accent
                        scale: closeArea.pressed ? 0.92 : 1

                        Text {
                            id: closeLabel

                            anchors.centerIn: parent
                            text: "Close"
                            color: Theme.onAccent
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fontLabel
                        }

                        MouseArea {
                            id: closeArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.firingReminder)
                                    root.dismissReminder(root.firingReminder.id);

                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barDurQuick
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                }

            }

        }
    ]

    panelContent: [
        Item {
            anchors.fill: parent

            Row {
                id: expandedRow

                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                Column {
                    id: leftRail

                    width: 250
                    spacing: 14

                    Rectangle {
                        id: heroCard

                        width: parent.width
                        height: 96
                        radius: Theme.radiusXl
                        color: Theme.withBlur(Theme.accentContainer)
                        scale: heroArea.containsMouse ? 1.015 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.text
                            opacity: heroArea.containsMouse ? Theme.stateHover : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.barDurQuick
                                    easing.type: Theme.easeStandard
                                }

                            }

                        }

                        MouseArea {
                            id: heroArea

                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                id: expandedTimeText

                                width: heroCard.width
                                text: new Date().toLocaleTimeString(Qt.locale(), root.fullTimeFormat)
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(30)
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                id: expandedDateText

                                width: heroCard.width
                                text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fontBody
                                horizontalAlignment: Text.AlignHCenter
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barDurShort
                                easing.type: Theme.easeEmphasized
                                easing.overshoot: Theme.emphasizedOvershoot * 0.4
                            }

                        }

                    }

                    Rectangle {
                        id: weatherCard

                        width: parent.width
                        height: 76
                        radius: Theme.radiusLg
                        color: Theme.withBlur(Theme.cContainer)
                        scale: weatherArea.containsMouse ? 1.015 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.text
                            opacity: weatherArea.containsMouse ? Theme.stateHover : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.barDurQuick
                                    easing.type: Theme.easeStandard
                                }

                            }

                        }

                        MouseArea {
                            id: weatherArea

                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            spacing: 12

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 999
                                color: Theme.accentContainer
                                anchors.verticalCenter: parent.verticalCenter

                                Item {
                                    id: weatherIconBox

                                    readonly property string category: root.weatherIconCategory(root.weatherCode, root.isNight)
                                    readonly property bool isPartly: category === "partly" || category === "partly-night"

                                    width: 22
                                    height: 22
                                    anchors.centerIn: parent

                                    WeatherGlyph {
                                        svgPath: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z M12 6L12 4 M12 18L12 20 M18 12L20 12 M6 12L4 12 M16.24 7.76L17.66 6.34 M7.76 7.76L6.34 6.34 M16.24 16.24L17.66 17.66 M7.76 16.24L6.34 17.66"
                                        anchors.horizontalCenterOffset: weatherIconBox.isPartly ? 4 : 0
                                        anchors.verticalCenterOffset: weatherIconBox.isPartly ? -4 : 0
                                        scale: (weatherIconBox.category === "sunny" ? 22 : 13) / 24
                                        opacity: (weatherIconBox.category === "sunny" || weatherIconBox.category === "partly") ? 1 : 0

                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: Theme.barMs(14000)
                                            loops: Animation.Infinite
                                            running: weatherIconBox.category === "sunny" || weatherIconBox.category === "partly"
                                        }

                                    }

                                    WeatherGlyph {
                                        svgPath: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z M17.5 5.5v3M16 7h3 M20.5 10.5v2M19.5 11.5h2 M6 6.5v2M5 7.5h2"
                                        anchors.horizontalCenterOffset: weatherIconBox.isPartly ? 4 : 0
                                        anchors.verticalCenterOffset: weatherIconBox.isPartly ? -4 : 0
                                        scale: (weatherIconBox.category === "clear-night" ? 22 : 13) / 24
                                        opacity: (weatherIconBox.category === "clear-night" || weatherIconBox.category === "partly-night") ? 1 : 0

                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: Theme.barMs(40000)
                                            loops: Animation.Infinite
                                            running: weatherIconBox.category === "clear-night" || weatherIconBox.category === "partly-night"
                                        }

                                    }

                                    WeatherGlyph {
                                        svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"
                                        anchors.horizontalCenterOffset: weatherIconBox.isPartly ? -3 : 0
                                        anchors.verticalCenterOffset: weatherIconBox.isPartly ? 3 : 0
                                        scale: (weatherIconBox.category === "cloudy" ? 22 : 15) / 24
                                        opacity: (weatherIconBox.category === "cloudy" || weatherIconBox.isPartly) ? 1 : 0
                                    }

                                    // cloud + rain
                                    WeatherGlyph {
                                        id: rainGlyph

                                        svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z M8 20L6.5 23.5 M12.5 20L11 23.5 M17 20L15.5 23.5"
                                        scale: 22 / 24
                                        opacity: weatherIconBox.category === "rain" ? 1 : 0

                                        transform: Translate {

                                            SequentialAnimation on y {
                                                loops: Animation.Infinite
                                                running: weatherIconBox.category === "rain"

                                                NumberAnimation {
                                                    from: 0
                                                    to: 1.6
                                                    duration: Theme.barMs(450)
                                                    easing.type: Easing.InQuad
                                                }

                                                NumberAnimation {
                                                    from: 1.6
                                                    to: 0
                                                    duration: Theme.barMs(0)
                                                }

                                            }

                                        }

                                    }

                                    // cloud + snow
                                    WeatherGlyph {
                                        svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z M8 20.4v2.6M6.7 21.7h2.6 M12.5 20.4v2.6M11.2 21.7h2.6 M17 20.4v2.6M15.7 21.7h2.6"
                                        scale: 22 / 24
                                        opacity: weatherIconBox.category === "snow" ? 1 : 0

                                        transform: Translate {

                                            SequentialAnimation on x {
                                                loops: Animation.Infinite
                                                running: weatherIconBox.category === "snow"

                                                NumberAnimation {
                                                    from: 0
                                                    to: 1.4
                                                    duration: Theme.barMs(900)
                                                    easing.type: Easing.InOutSine
                                                }

                                                NumberAnimation {
                                                    from: 1.4
                                                    to: -1.4
                                                    duration: Theme.barMs(1800)
                                                    easing.type: Easing.InOutSine
                                                }

                                                NumberAnimation {
                                                    from: -1.4
                                                    to: 0
                                                    duration: Theme.barMs(900)
                                                    easing.type: Easing.InOutSine
                                                }

                                            }

                                        }

                                    }

                                    // cloud + fog
                                    WeatherGlyph {
                                        svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z M6 20H11M13 20H19 M5.5 21.7H10.5M12.5 21.7H19 M6 23.4H11M13 23.4H18.5"
                                        scale: 22 / 24
                                        opacity: weatherIconBox.category === "fog" ? 1 : 0

                                        transform: Translate {

                                            SequentialAnimation on x {
                                                loops: Animation.Infinite
                                                running: weatherIconBox.category === "fog"

                                                NumberAnimation {
                                                    from: 0
                                                    to: 1.8
                                                    duration: Theme.barMs(1800)
                                                    easing.type: Easing.InOutSine
                                                }

                                                NumberAnimation {
                                                    from: 1.8
                                                    to: -1.8
                                                    duration: Theme.barMs(3600)
                                                    easing.type: Easing.InOutSine
                                                }

                                                NumberAnimation {
                                                    from: -1.8
                                                    to: 0
                                                    duration: Theme.barMs(1800)
                                                    easing.type: Easing.InOutSine
                                                }

                                            }

                                        }

                                    }

                                    // cloud + storm (rumbles periodically)
                                    WeatherGlyph {
                                        svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z M13.5 19L11.2 21.8L13 21.8L10.5 24"
                                        scale: 22 / 24
                                        opacity: weatherIconBox.category === "storm" ? 1 : 0

                                        SequentialAnimation on rotation {
                                            loops: Animation.Infinite
                                            running: weatherIconBox.category === "storm"

                                            NumberAnimation {
                                                from: 0
                                                to: -4
                                                duration: Theme.barMs(80)
                                                easing.type: Easing.OutQuad
                                            }

                                            NumberAnimation {
                                                from: -4
                                                to: 4
                                                duration: Theme.barMs(120)
                                                easing.type: Easing.InOutQuad
                                            }

                                            NumberAnimation {
                                                from: 4
                                                to: 0
                                                duration: Theme.barMs(80)
                                                easing.type: Easing.OutQuad
                                            }

                                            PauseAnimation {
                                                duration: Theme.barMs(2200)
                                            }

                                        }

                                    }

                                }

                            }

                            Column {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: root.temp + "°C"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fontHeadline
                                }

                                Text {
                                    text: root.weatherDesc(root.weatherCode) + " • " + root.humidity + "% Hum"
                                    color: Theme.subtext
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabel
                                }

                                Text {
                                    text: "Feels like " + root.feelsLike + "°C"
                                    color: Theme.subtextDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabel
                                }

                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barDurShort
                                easing.type: Theme.easeEmphasized
                                easing.overshoot: Theme.emphasizedOvershoot * 0.4
                            }

                        }

                    }

                    Rectangle {
                        id: upNextCard

                        width: parent.width
                        height: 74
                        radius: Theme.radiusLg
                        color: Theme.withBlur(Theme.cContainer)

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 3

                            Text {
                                text: "UP NEXT"
                                color: Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(9)
                                font.letterSpacing: 1.2
                            }

                            Text {
                                width: parent.width
                                text: root.nextReminder ? root.nextReminder.item.name : "Nothing scheduled"
                                color: root.nextReminder ? Theme.text : Theme.subtext
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(13)
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: root.nextReminder !== null
                                width: parent.width
                                text: root.nextReminder ? root.fmtReminderTime(root.nextReminder.item) + " \u00b7 " + root.untilText(root.nextReminder.at) : ""
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(11)
                                elide: Text.ElideRight
                            }

                        }

                    }

                }

                Column {
                    width: parent.width - leftRail.width - parent.spacing
                    spacing: 10

                    Column {
                        width: parent.width
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 26

                            NavButton {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                iconPath: "M15.41 7.41 14 6l-6 6 6 6 1.41-1.41L10.83 12Z"
                                onClicked: root.goPrevMonth()
                            }

                            NavButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                iconPath: "M8.59 16.59 13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41Z"
                                onClicked: root.goNextMonth()
                            }

                            Text {
                                id: monthText

                                anchors.centerIn: parent
                                text: new Date(root.viewYear, root.viewMonth, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy") + (root.isViewingCurrentMonth ? "  •  Today" : "")
                                color: root.isViewingCurrentMonth ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fontTitle

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.barDurQuick
                                    }

                                }

                            }

                            MouseArea {
                                anchors.fill: monthText
                                enabled: !root.isViewingCurrentMonth
                                hoverEnabled: enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.goToday()
                            }

                        }

                        Item {
                            id: calViewport

                            width: parent.width
                            height: 212
                            clip: true

                            MonthGrid {
                                id: calGridA

                                anchors.top: parent.top
                                width: parent.width
                                // filled in by resyncCalendarGrids(), not bound directly
                                cells: []
                                x: 0
                                opacity: 1
                                z: 1
                            }

                            MonthGrid {
                                id: calGridB

                                anchors.top: parent.top
                                width: parent.width
                                cells: []
                                x: parent.width
                                opacity: 0
                                z: 0
                            }

                        }

                    }
                }

            }

            Item {
                id: reminderOverlay

                anchors.fill: parent
                z: 10
                visible: root.editingDate !== null

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLg
                    color: Theme.scrim

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.editingDate = null
                    }

                }

                Rectangle {
                    id: reminderSheet

                    width: 250
                    height: sheetColumn.implicitHeight + 32
                    anchors.centerIn: parent
                    radius: Theme.radiusLg
                    color: Theme.cHigh
                    scale: root.editingDate !== null ? 1 : 0.9

                    Column {
                        id: sheetColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 26

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.editingDate ? new Date(root.editingDate.year, root.editingDate.month, root.editingDate.day).toLocaleDateString(Qt.locale(), "MMM d, yyyy") : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fontTitle
                            }

                            NavButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                iconPath: "M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"
                                onClicked: root.editingDate = null
                            }

                        }

                        Repeater {
                            model: root.editingDate ? root.remindersFor(root.editingDate.year, root.editingDate.month, root.editingDate.day) : []

                            Row {
                                id: reminderRow

                                required property var modelData

                                width: sheetColumn.width
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (reminderRow.modelData.hour < 10 ? "0" : "") + reminderRow.modelData.hour + ":" + (reminderRow.modelData.minute < 10 ? "0" : "") + reminderRow.modelData.minute
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fontLabel
                                }

                                Text {
                                    width: reminderRow.width - 44 - 26
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: reminderRow.modelData.name
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabel
                                    elide: Text.ElideRight
                                }

                                NavButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    iconPath: "M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"
                                    onClicked: root.removeReminder(reminderRow.modelData.id)
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            visible: root.editingDate && root.remindersFor(root.editingDate.year, root.editingDate.month, root.editingDate.day).length > 0
                        }

                        Item {
                            width: parent.width
                            height: 26

                            TextInput {
                                id: reminderNameInput

                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                clip: true
                                focus: root.editingDate !== null
                                Keys.onReturnPressed: root.submitNewReminder()
                                Keys.onEnterPressed: root.submitNewReminder()
                                Keys.onEscapePressed: root.editingDate = null
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Reminder name"
                                color: Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                visible: reminderNameInput.text === ""
                            }

                        }

                        Row {
                            spacing: 8

                            Rectangle {
                                width: 32
                                height: 26
                                radius: Theme.radiusXs
                                color: Theme.withBlur(Theme.cContainer)

                                TextInput {
                                    id: reminderHourInput

                                    anchors.fill: parent
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    text: "9"
                                    maximumLength: 2

                                    validator: IntValidator {
                                        bottom: 1
                                        top: 12
                                    }

                                }

                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ":"
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fontBody
                            }

                            Rectangle {
                                width: 32
                                height: 26
                                radius: Theme.radiusXs
                                color: Theme.withBlur(Theme.cContainer)

                                TextInput {
                                    id: reminderMinuteInput

                                    anchors.fill: parent
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    text: "00"
                                    maximumLength: 2

                                    validator: IntValidator {
                                        bottom: 0
                                        top: 59
                                    }

                                }

                            }

                            Rectangle {
                                id: meridiemToggle

                                width: 62
                                height: 26
                                radius: 999
                                color: Theme.withBlur(Theme.cContainer)

                                Rectangle {
                                    width: parent.width / 2
                                    height: parent.height
                                    radius: 999
                                    color: Theme.accent
                                    x: root.reminderMeridiem === "AM" ? 0 : parent.width / 2

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.barDurQuick
                                            easing.type: Theme.easeStandard
                                        }

                                    }

                                }

                                Row {
                                    anchors.fill: parent

                                    Item {
                                        width: parent.width / 2
                                        height: parent.height

                                        Text {
                                            anchors.centerIn: parent
                                            text: "AM"
                                            color: root.reminderMeridiem === "AM" ? Theme.onAccent : Theme.subtext
                                            font.family: Theme.fontFamily
                                            font.bold: true
                                            font.pixelSize: Theme.fontLabel

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Theme.barDurQuick
                                                }

                                            }

                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.reminderMeridiem = "AM"
                                        }

                                    }

                                    Item {
                                        width: parent.width / 2
                                        height: parent.height

                                        Text {
                                            anchors.centerIn: parent
                                            text: "PM"
                                            color: root.reminderMeridiem === "PM" ? Theme.onAccent : Theme.subtext
                                            font.family: Theme.fontFamily
                                            font.bold: true
                                            font.pixelSize: Theme.fontLabel

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Theme.barDurQuick
                                                }

                                            }

                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.reminderMeridiem = "PM"
                                        }

                                    }

                                }

                            }

                        }

                        Item {
                            width: parent.width
                            height: 26

                            Rectangle {
                                id: addBtn

                                anchors.right: parent.right
                                height: 26
                                width: addLabel.implicitWidth + 20
                                radius: 999
                                color: addArea.containsMouse ? Theme.accentHover : Theme.accent
                                scale: addArea.pressed ? 0.92 : 1

                                Text {
                                    id: addLabel

                                    anchors.centerIn: parent
                                    text: "Add"
                                    color: Theme.onAccent
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fontLabel
                                }

                                MouseArea {
                                    id: addArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.submitNewReminder()
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.barDurQuick
                                        easing.type: Theme.easeStandard
                                    }

                                }

                            }

                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.barDurShort
                            easing.type: Theme.easeEmphasized
                            easing.overshoot: Theme.emphasizedOvershoot
                        }

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.barDurShort
                            easing.type: Theme.easeStandard
                        }

                    }

                }

            }
        }
    ]

    component SvgIcon: Item {
        id: iconRoot

        property string path: ""
        property color tint: Theme.text
        property int iconSize: 16

        width: iconSize
        height: iconSize

        Shape {
            width: 24
            height: 24
            scale: iconRoot.iconSize / 24
            anchors.centerIn: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: iconRoot.tint
                strokeWidth: 0

                PathSvg {
                    path: iconRoot.path
                }

            }

        }

    }

    component NavButton: Item {
        id: navBtn

        property string iconPath: ""

        signal clicked()

        width: 26
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: 999
            color: Theme.text
            opacity: navArea.containsMouse ? Theme.stateHover : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.barDurQuick
                    easing.type: Theme.easeStandard
                }

            }

        }

        SvgIcon {
            anchors.centerIn: parent
            path: navBtn.iconPath
            tint: navArea.containsMouse ? Theme.accent : Theme.subtext
            iconSize: 14
            scale: navArea.pressed ? 0.8 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.barDurQuick
                    easing.type: Theme.easeStandard
                }

            }

        }

        MouseArea {
            id: navArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navBtn.clicked()
        }

    }

    // two of these ping-pong so month changes slide
    component MonthGrid: Column {
        id: monthGrid

        property var cells: []
        property bool suppressMotion: false

        spacing: 8

        Grid {
            width: parent.width
            columns: 7

            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]

                Text {
                    width: parent.width / 7
                    text: modelData
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontLabel
                    horizontalAlignment: Text.AlignHCenter
                }

            }

        }

        Grid {
            width: parent.width
            columns: 7
            rowSpacing: 4
            columnSpacing: 0

            Repeater {
                model: monthGrid.cells

                Item {
                    id: dayCell

                    required property var modelData
                    readonly property bool hasReminder: root.hasReminderOn(modelData.year, modelData.month, modelData.day)

                    width: parent.width / 7
                    height: 28

                    Shape {
                        id: todayBlob

                        width: 24
                        height: 24
                        anchors.centerIn: parent
                        scale: (48 / 24) * (dayArea.pressed ? 0.86 : (dayArea.containsMouse ? 1.1 : 1))
                        rotation: dayArea.containsMouse ? 6 : 0
                        visible: dayCell.modelData.today
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.accent
                            strokeWidth: 0

                            PathSvg {
                                path: "M14.14,4.56 L18.42,7.67 Q20.56,9.22 19.74,11.74 L18.11,16.77 Q17.29,19.28 14.65,19.28 L9.36,19.28 Q6.71,19.28 5.89,16.77 L4.26,11.74 Q3.44,9.22 5.58,7.67 L9.86,4.56 Q12,3 14.14,4.56 Z"
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barDurShort
                                easing.type: Theme.easeEmphasized
                                easing.overshoot: Theme.emphasizedOvershoot
                            }

                        }

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.barDurShort
                                easing.type: Theme.easeEmphasized
                                easing.overshoot: Theme.emphasizedOvershoot
                            }

                        }

                    }

                    Rectangle {
                        id: dayBg

                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        scale: dayArea.pressed ? 0.86 : 1
                        color: (!dayCell.modelData.today && dayArea.containsMouse) ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.modelData.day
                            color: dayCell.modelData.today ? Theme.onAccent : (dayCell.modelData.other ? Theme.subtext : Theme.text)
                            opacity: dayCell.modelData.other ? 0.3 : 1
                            font.family: Theme.fontFamily
                            font.bold: dayCell.modelData.today
                            font.pixelSize: Theme.fs(12)
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4
                            height: 4
                            radius: 2
                            color: dayCell.modelData.today ? Theme.onAccent : Theme.accent
                            visible: dayCell.hasReminder
                            scale: dayCell.hasReminder ? 1 : 0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.barDurShort
                                    easing.type: Theme.easeEmphasized
                                    easing.overshoot: Theme.emphasizedOvershoot
                                }

                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barDurQuick
                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barDurQuick
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barDurQuick
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                    MouseArea {
                        id: dayArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editingDate = {
                            "year": dayCell.modelData.year,
                            "month": dayCell.modelData.month,
                            "day": dayCell.modelData.day
                        }
                    }

                }

            }

        }

        Behavior on x {
            enabled: !monthGrid.suppressMotion

            NumberAnimation {
                duration: Theme.barDurMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot * 0.3
            }

        }

        Behavior on opacity {
            enabled: !monthGrid.suppressMotion

            NumberAnimation {
                duration: Theme.barDurMedium
                easing.type: Theme.easeStandard
            }

        }

    }

    // one weather icon layer, crossfades on change
    component WeatherGlyph: Shape {
        id: glyph

        property string svgPath: ""

        width: 24
        height: 24
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: glyph.svgPath
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.barDurMedium
                easing.type: Theme.easeStandard
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.barDurMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation {
                duration: Theme.barDurMedium
                easing.type: Theme.easeStandard
            }

        }

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: Theme.barDurMedium
                easing.type: Theme.easeStandard
            }

        }

    }
}
