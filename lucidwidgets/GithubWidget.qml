import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.lucidui

WidgetBody {
    id: w

    // the script's last answer, kept even when it is for a name since changed
    property var answer: null
    // the day under the pointer, for the line under the graph
    property var hoverDay: null

    readonly property string user: {
        var v = w.opt("user");
        return v === undefined ? "" : String(v).trim();
    }
    // no name yet, or the name is being changed: the card is a text field
    readonly property bool asking: !w.preview && (w.user === "" || w.editing)
    readonly property bool streakOnly: w.variant === "streak"
    // a year that looks lived in, for the gallery tile
    readonly property var sample: {
        var days = [];
        var start = new Date();
        start.setHours(12, 0, 0, 0);
        start.setDate(start.getDate() - 364 - start.getDay());
        var seed = 7;
        var total = 0;
        for (var i = 0; i < 371; i++) {
            var d = new Date(start.getTime() + i * 86400000);
            seed = (seed * 16807) % 2147483647;
            var r = seed / 2147483647;
            var weekday = d.getDay() > 0 && d.getDay() < 6;
            var n = r < (weekday ? 0.35 : 0.7) ? 0 : Math.round((r - 0.3) * (weekday ? 14 : 6));
            if (i > 364)
                n = 3;

            total += n;
            days.push([Qt.formatDate(d, "yyyy-MM-dd"), n, n === 0 ? 0 : n < 3 ? 1 : n < 6 ? 2 : n < 9 ? 3 : 4]);
        }
        return {
            "ok": true,
            "user": "octocat",
            "total": total,
            "streak": 6,
            "longest": 14,
            "days": days
        };
    }
    readonly property var report: {
        if (w.preview)
            return w.sample;

        var a = w.answer;
        return a && a.ok && String(a.user).toLowerCase() === w.user.toLowerCase() ? a : null;
    }
    readonly property var days: w.report ? w.report.days : []
    readonly property int today: w.days.length > 0 ? w.days[w.days.length - 1][1] : 0
    // what to say when there is no graph to draw
    readonly property string problem: {
        var a = w.answer;
        if (w.report || !a || String(a.user).toLowerCase() !== w.user.toLowerCase())
            return "";

        switch (a.error) {
        case "invalid":
            return "That isn't a GitHub username";
        case "notfound":
            return "No GitHub user called " + w.user;
        case "offline":
            return "Can't reach GitHub right now";
        }
        return "GitHub didn't answer the way it should";
    }

    function fetch() {
        if (!w.live || w.user === "" || fetcher.running)
            return ;

        fetcher.command = ["python3", Qt.resolvedUrl("github-contributions.py").toString().replace("file://", ""), w.user];
        fetcher.running = true;
    }

    function openProfile() {
        if (!w.preview && w.user !== "")
            Quickshell.execDetached(["xdg-open", "https://github.com/" + w.user]);

    }

    function plural(n, one, many) {
        return n + " " + (n === 1 ? one : many);
    }

    function dayText(day) {
        var d = new Date(day[0] + "T12:00:00");
        var when = d.toLocaleDateString(Qt.locale(), "ddd d MMM");
        return (day[1] === 0 ? "No contributions" : w.plural(day[1], "contribution", "contributions")) + " on " + when;
    }

    // GitHub's own five steps, drawn in the card's accent
    function cellColor(level) {
        if (level <= 0)
            return Theme.alpha(w.ink, 0.08);

        return Theme.alpha(w.inkAccent, [0.32, 0.54, 0.78, 1][Math.min(level, 4) - 1]);
    }

    defaultTone: "surface"
    Component.onCompleted: w.fetch()
    onUserChanged: w.fetch()
    onLiveChanged: w.fetch()
    onEditingChanged: {
        if (w.editing) {
            nameInput.text = w.user;
            nameInput.selectAll();
            nameInput.forceActiveFocus();
        } else if (nameInput.activeFocus) {
            nameInput.focus = false;
        }
    }

    Timer {
        interval: 1800000
        repeat: true
        running: w.live && w.user !== ""
        onTriggered: w.fetch()
    }

    Process {
        id: fetcher

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    w.answer = JSON.parse(this.text);
                } catch (e) {
                    w.answer = {
                        "ok": false,
                        "user": w.user,
                        "error": "parse"
                    };
                }
                // the name changed while this one was on its way
                if (String(w.answer.user).toLowerCase() !== w.user.toLowerCase())
                    Qt.callLater(w.fetch);

            }
        }

    }

    // ------------------------------------------------------------ the name
    Column {
        anchors.centerIn: parent
        width: parent.width - Theme.dp(40)
        spacing: Theme.dp(10)
        visible: w.asking

        WidgetGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "code"
            size: Theme.dp(26)
            color: w.inkAccent
        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "titleSmall"
            color: w.ink
            text: "Your GitHub username"
        }

        Rectangle {
            width: Math.min(parent.width, Theme.dp(240))
            height: Theme.dp(40)
            anchors.horizontalCenter: parent.horizontalCenter
            radius: height / 2
            color: w.editing ? Theme.alpha(w.inkAccent, 0.14) : Theme.alpha(w.ink, 0.06)
            border.width: w.editing ? 2 : 0
            border.color: w.inkAccent

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    w.beginEdit();
                    nameInput.forceActiveFocus();
                }
            }

            TextInput {
                id: nameInput

                anchors.fill: parent
                anchors.leftMargin: Theme.dp(16)
                anchors.rightMargin: Theme.dp(16)
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: w.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeSize("bodyMedium")
                font.variableAxes: Theme.axes(Theme.typeSize("bodyMedium"), 420, 0)
                selectByMouse: true
                selectionColor: w.inkAccent
                selectedTextColor: w.fgInkAccent
                clip: true
                maximumLength: 39
                validator: RegularExpressionValidator {
                    regularExpression: /[A-Za-z0-9-]*/
                }
                onActiveFocusChanged: {
                    if (nameInput.activeFocus)
                        w.beginEdit();

                }
                onAccepted: {
                    var name = nameInput.text.trim();
                    if (name !== "")
                        w.setOpt("user", name);

                    w.endEdit();
                }
                Keys.onEscapePressed: {
                    nameInput.text = w.user;
                    w.endEdit();
                }
            }

            LText {
                anchors.centerIn: parent
                role: "bodyMedium"
                color: w.inkFaint
                text: "octocat"
                visible: nameInput.text === ""
            }

        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "bodySmall"
            color: w.inkFaint
            text: w.user === "" ? "Public contributions, no token needed" : "Enter to save · Esc to keep " + w.user
            wrapMode: Text.WordWrap
        }

    }

    // ------------------------------------------------------------ shared head
    Item {
        id: head

        visible: !w.asking
        x: Theme.dp(16)
        y: Theme.dp(14)
        width: parent.width - Theme.dp(32)
        height: Theme.dp(22)

        Row {
            id: who

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(8)

            WidgetGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "code"
                size: Theme.dp(16)
                color: w.inkAccent
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                color: whoArea.containsMouse ? w.inkAccent : w.ink
                text: w.preview ? "octocat" : w.user
                elide: Text.ElideRight
                width: Math.min(implicitWidth, head.width - total.implicitWidth - Theme.dp(40))
            }

        }

        // the name is the way back to changing it
        MouseArea {
            id: whoArea

            anchors.fill: who
            enabled: !w.preview
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: w.beginEdit()
        }

        LText {
            id: total

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            role: "labelMedium"
            tabular: true
            color: w.inkDim
            text: !w.report ? "" : (w.streakOnly ? (w.report.stale ? "offline" : "") : w.plural(w.report.total, "contribution", "contributions") + (w.report.stale ? " · offline" : ""))
        }

    }

    LText {
        anchors.centerIn: parent
        width: parent.width - Theme.dp(40)
        visible: !w.asking && !w.report
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        role: "bodyMedium"
        color: w.inkFaint
        text: w.problem !== "" ? w.problem : "Asking GitHub…"
    }

    // ------------------------------------------------------------ year
    Item {
        id: year

        readonly property real gap: Math.max(2, Math.round(year.cell * 0.22))
        readonly property real cell: Math.max(Theme.dp(6), Math.min(Theme.dp(22), (grid.height - 6 * Theme.dp(3)) / 7))
        // github's columns start on a sunday
        readonly property int lead: w.days.length > 0 ? new Date(w.days[0][0] + "T12:00:00").getDay() : 0
        readonly property int columns: Math.ceil((year.lead + w.days.length) / 7)
        readonly property int fits: Math.max(1, Math.min(year.columns, Math.floor((year.width + year.gap) / (year.cell + year.gap))))
        readonly property int firstColumn: year.columns - year.fits
        readonly property real gridW: year.fits * (year.cell + year.gap) - year.gap
        readonly property bool months: w.opt("months") !== false

        visible: !w.asking && w.report !== null && !w.streakOnly
        anchors.fill: parent
        anchors.topMargin: head.y + head.height + Theme.dp(8)
        anchors.leftMargin: Theme.dp(16)
        anchors.rightMargin: Theme.dp(16)
        anchors.bottomMargin: Theme.dp(12)

        // a month's name over the first column that starts in it
        Item {
            id: monthRow

            x: (year.width - year.gridW) / 2
            width: year.gridW
            height: year.months ? Theme.dp(16) : 0
            visible: year.months

            Repeater {
                model: {
                    var marks = [];
                    var last = -1;
                    for (var c = year.firstColumn; c < year.columns; c++) {
                        var i = Math.max(0, c * 7 - year.lead);
                        if (i >= w.days.length)
                            break;

                        var m = parseInt(w.days[i][0].slice(5, 7));
                        if (m !== last) {
                            marks.push({
                                "col": c - year.firstColumn,
                                "month": m
                            });
                            last = m;
                        }
                    }
                    // a name needs room: when two crowd, the month that only
                    // just shows at the left edge gives way
                    var room = Math.ceil(Theme.dp(30) / (year.cell + year.gap));
                    var kept = [];
                    for (var k = marks.length - 1; k >= 0; k--) {
                        if (kept.length === 0 || kept[0].col - marks[k].col >= room)
                            kept.unshift(marks[k]);

                    }
                    return kept;
                }

                LText {
                    required property var modelData

                    x: modelData.col * (year.cell + year.gap)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelSmall"
                    color: w.inkFaint
                    text: Qt.locale().standaloneMonthName(modelData.month - 1, Locale.ShortFormat)
                }

            }

        }

        Item {
            id: grid

            x: (year.width - year.gridW) / 2
            y: monthRow.height + (year.months ? Theme.dp(4) : 0)
            width: year.gridW
            height: year.height - y - foot.height - Theme.dp(8)

            Repeater {
                model: w.days.length

                Rectangle {
                    id: cellBox

                    required property int index
                    readonly property int slot: year.lead + index
                    readonly property int col: Math.floor(slot / 7) - year.firstColumn
                    readonly property var day: w.days[index]

                    visible: col >= 0
                    x: col * (year.cell + year.gap)
                    y: (slot % 7) * (year.cell + year.gap)
                    width: year.cell
                    height: year.cell
                    radius: Math.max(2, year.cell * 0.28)
                    color: w.cellColor(day[2])
                    border.width: w.hoverDay === day ? 1.5 : 0
                    border.color: w.ink

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse)
                                w.hoverDay = cellBox.day;
                            else if (w.hoverDay === cellBox.day)
                                w.hoverDay = null;
                        }
                        onClicked: w.openProfile()
                    }

                }

            }

        }

        LText {
            id: foot

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, year.gridW)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            role: "bodySmall"
            tabular: true
            color: w.hoverDay ? w.ink : w.inkDim
            text: {
                if (w.hoverDay)
                    return w.dayText(w.hoverDay);

                if (!w.report)
                    return "";

                return w.report.streak > 0 ? w.plural(w.report.streak, "day", "days") + " in a row · best " + w.report.longest : "Longest run this year: " + w.plural(w.report.longest, "day", "days");
            }
        }

    }

    // ------------------------------------------------------------ streak
    Item {
        id: streak

        readonly property real cell: Theme.dp(12)
        readonly property real gap: Theme.dp(4)
        readonly property int fits: Math.max(1, Math.min(w.days.length, Math.floor((streak.width + streak.gap) / (streak.cell + streak.gap))))

        visible: !w.asking && w.report !== null && w.streakOnly
        anchors.fill: parent
        anchors.topMargin: head.y + head.height + Theme.dp(6)
        anchors.leftMargin: Theme.dp(16)
        anchors.rightMargin: Theme.dp(16)
        anchors.bottomMargin: Theme.dp(14)

        Column {
            id: big

            anchors.left: parent.left
            anchors.top: parent.top
            spacing: 0

            LText {
                role: "displayMedium"
                tabular: true
                color: w.inkAccent
                text: w.report ? w.report.streak : 0
            }

            LText {
                role: "labelMedium"
                color: w.inkDim
                text: w.report && w.report.streak === 1 ? "day in a row" : "days in a row"
            }

        }

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: big.verticalCenter
            spacing: Theme.dp(4)

            Repeater {
                model: w.report ? [["Today", w.today], ["Best run", w.report.longest], ["This year", w.report.total]] : []

                Row {
                    required property var modelData

                    anchors.right: parent.right
                    spacing: Theme.dp(10)

                    LText {
                        role: "bodySmall"
                        color: w.inkFaint
                        text: modelData[0]
                    }

                    LText {
                        role: "labelLarge"
                        tabular: true
                        color: w.ink
                        text: modelData[1]
                    }

                }

            }

        }

        // the last days that fit, today at the right
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: streak.gap

            Repeater {
                model: w.days.slice(w.days.length - streak.fits)

                Rectangle {
                    required property var modelData

                    width: streak.cell
                    height: streak.cell
                    radius: Theme.dp(3)
                    color: w.cellColor(modelData[2])

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: w.openProfile()
                    }

                }

            }

        }

    }

}
