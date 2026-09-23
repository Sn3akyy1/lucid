import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs

WidgetBody {
    id: w

    readonly property bool mondayFirst: w.opt("mondayFirst") !== false
    readonly property bool showMonthName: w.opt("showMonthName") !== false
    readonly property var dayLetters: w.mondayFirst ? ["M", "T", "W", "T", "F", "S", "S"] : ["S", "M", "T", "W", "T", "F", "S"]

    property var today: Loc.now()
    property int viewYear: Loc.now().getFullYear()
    property int viewMonth: Loc.now().getMonth()

    // 42 cells, the month padded out with the tail of the last one and the head of the next
    readonly property var grid: {
        var first = new Date(w.viewYear, w.viewMonth, 1);
        var lead = (first.getDay() - (w.mondayFirst ? 1 : 0) + 7) % 7;
        var daysThis = new Date(w.viewYear, w.viewMonth + 1, 0).getDate();
        var daysPrev = new Date(w.viewYear, w.viewMonth, 0).getDate();
        var prev = new Date(w.viewYear, w.viewMonth - 1, 1);
        var next = new Date(w.viewYear, w.viewMonth + 1, 1);
        var out = [];
        for (var i = 0; i < 42; i++) {
            var n = i - lead + 1;
            if (n < 1)
                out.push({
                    "day": daysPrev + n,
                    "inMonth": false,
                    "year": prev.getFullYear(),
                    "month": prev.getMonth()
                });
            else if (n > daysThis)
                out.push({
                    "day": n - daysThis,
                    "inMonth": false,
                    "year": next.getFullYear(),
                    "month": next.getMonth()
                });
            else
                out.push({
                    "day": n,
                    "inMonth": true,
                    "year": w.viewYear,
                    "month": w.viewMonth
                });
        }
        return out;
    }
    readonly property int weeksShown: {
        var last = 0;
        for (var i = 0; i < 42; i++) {
            if (w.grid[i].inMonth)
                last = Math.floor(i / 7);

        }
        return last + 1;
    }
    // the seven days around today, starting on the configured first day
    readonly property var weekDays: {
        var base = new Date(w.today.getFullYear(), w.today.getMonth(), w.today.getDate());
        var off = (base.getDay() - (w.mondayFirst ? 1 : 0) + 7) % 7;
        var out = [];
        for (var i = 0; i < 7; i++) {
            var d = new Date(base.getTime());
            d.setDate(base.getDate() - off + i);
            out.push(d);
        }
        return out;
    }

    // the squircle the bar's calendar marks today with, on material's 24x24 grid
    readonly property string blobPath: "M14.14,4.56 L18.42,7.67 Q20.56,9.22 19.74,11.74 L18.11,16.77 Q17.29,19.28 14.65,19.28 L9.36,19.28 Q6.71,19.28 5.89,16.77 L4.26,11.74 Q3.44,9.22 5.58,7.67 L9.86,4.56 Q12,3 14.14,4.56 Z"
    // the blob's own ink is about 16 units wide inside that grid
    readonly property real blobUnit: 16

    function hasReminderOn(year, month, day) {
        var items = reminders.items;
        for (var i = 0; i < items.length; i++) {
            var r = items[i];
            if (r.year === year && r.month === month && r.day === day)
                return true;

        }
        return false;
    }

    function isToday(day) {
        return day && w.viewYear === w.today.getFullYear() && w.viewMonth === w.today.getMonth() && day === w.today.getDate();
    }

    function step(n) {
        var d = new Date(w.viewYear, w.viewMonth + n, 1);
        w.viewYear = d.getFullYear();
        w.viewMonth = d.getMonth();
    }

    function backToToday() {
        w.viewYear = w.today.getFullYear();
        w.viewMonth = w.today.getMonth();
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: w.today = Loc.now()
    }

    // the bar clock owns these; this only ever reads them
    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/lucidbar/clock_reminders.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: reminders

            property var items: []
        }

    }

    onHoveredChanged: {
        if (!w.hovered)
            resetView.restart();

    }

    Timer {
        id: resetView

        interval: 8000
        onTriggered: w.backToToday()
    }

    Item {
        id: month

        visible: w.variant === "month"
        anchors.fill: parent
        anchors.margins: 18

        Item {
            id: monthHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 30

            Text {
                id: monthName

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: new Date(w.viewYear, w.viewMonth, 1).toLocaleDateString(Qt.locale(), "MMMM")
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.bold: true
                visible: w.showMonthName
            }

            Text {
                anchors.left: monthName.right
                anchors.leftMargin: 7
                anchors.baseline: monthName.baseline
                text: w.viewYear
                color: Theme.alpha(Theme.accent, 0.62)
                font.family: Theme.fontFamily
                font.pixelSize: 14
                visible: w.showMonthName
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                opacity: w.hovered ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

                WidgetButton {
                    icon: "chevron"
                    diameter: 26
                    iconSize: 15
                    rotation: 180
                    onClicked: w.step(-1)
                }

                WidgetButton {
                    icon: "chevron"
                    diameter: 26
                    iconSize: 15
                    onClicked: w.step(1)
                }

            }

        }

        Row {
            id: dayHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: monthHead.bottom
            anchors.topMargin: 2
            height: 20

            Repeater {
                model: w.dayLetters

                Text {
                    required property var modelData

                    width: dayHead.width / 7
                    height: dayHead.height
                    text: modelData
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

            }

        }

        Grid {
            id: monthGrid

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: dayHead.bottom
            anchors.bottom: parent.bottom
            columns: 7

            Repeater {
                model: w.grid.slice(0, w.weeksShown * 7)

                Item {
                    id: cell

                    required property var modelData

                    readonly property bool marked: cell.modelData.inMonth && w.isToday(cell.modelData.day)
                    readonly property bool hasReminder: w.hasReminderOn(cell.modelData.year, cell.modelData.month, cell.modelData.day)
                    readonly property real span: Math.min(cell.width, cell.height)

                    width: monthGrid.width / 7
                    height: monthGrid.height / w.weeksShown

                    // a handler rather than a MouseArea, so the card can still be dragged from here
                    HoverHandler {
                        id: cellHover
                    }

                    Shape {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        scale: ((cell.span - 6) / w.blobUnit) * (cellHover.hovered ? 1.1 : 1)
                        rotation: cellHover.hovered ? 6 : 0
                        visible: cell.marked
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.accent
                            strokeWidth: 0

                            PathSvg {
                                path: w.blobPath
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeEmphasized
                                easing.overshoot: Theme.emphasizedOvershoot
                            }

                        }

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeEmphasized
                                easing.overshoot: Theme.emphasizedOvershoot
                            }

                        }

                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: cell.span - 6
                        height: cell.span - 6
                        radius: Theme.pill(width)
                        color: (!cell.marked && cellHover.hovered) ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cell.hasReminder ? -2 : 0
                            text: cell.modelData.day
                            color: cell.marked ? Theme.fgAccent : (cell.modelData.inMonth ? Theme.text : Theme.alpha(Theme.subtextDim, 0.45))
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: cell.marked
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4
                            height: 4
                            radius: 2
                            color: cell.marked ? Theme.fgAccent : Theme.accent
                            visible: cell.hasReminder
                            scale: cell.hasReminder ? 1 : 0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.durShort
                                    easing.type: Theme.easeEmphasized
                                    easing.overshoot: Theme.emphasizedOvershoot
                                }

                            }

                        }

                    }

                }

            }

        }

    }

    Item {
        id: weekView

        visible: w.variant === "week"
        anchors.fill: parent
        anchors.margins: 16

        Text {
            id: weekLabel

            anchors.left: parent.left
            anchors.top: parent.top
            text: w.today.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 0.6
            visible: w.showMonthName
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: w.showMonthName ? weekLabel.bottom : parent.top
            anchors.topMargin: 6

            Repeater {
                model: w.weekDays

                Item {
                    id: wcell

                    required property var modelData
                    required property int index

                    readonly property bool marked: wcell.modelData.getDate() === w.today.getDate() && wcell.modelData.getMonth() === w.today.getMonth()
                    readonly property bool hasReminder: w.hasReminderOn(wcell.modelData.getFullYear(), wcell.modelData.getMonth(), wcell.modelData.getDate())

                    width: weekView.width / 7
                    height: parent.height

                    HoverHandler {
                        id: weekHover
                    }

                    Rectangle {
                        id: weekPill

                        anchors.centerIn: parent
                        width: Math.min(parent.width - 4, 42)
                        height: Math.min(parent.height, 58)
                        radius: Theme.pill(width)
                        scale: weekHover.hovered ? 1.06 : 1
                        color: wcell.marked ? Theme.accent : (weekHover.hovered ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeEmphasized
                                easing.overshoot: Theme.emphasizedOvershoot
                            }

                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 7
                            width: 4
                            height: 4
                            radius: 2
                            color: wcell.marked ? Theme.fgAccent : Theme.accent
                            visible: wcell.hasReminder
                        }

                    }

                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: wcell.hasReminder ? -3 : 0
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: w.dayLetters[wcell.index]
                            color: wcell.marked ? Theme.fgAccent : Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: wcell.modelData.getDate()
                            color: wcell.marked ? Theme.fgAccent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 19
                            font.bold: wcell.marked
                        }

                    }

                }

            }

        }

    }

    Column {
        id: todayView

        visible: w.variant === "today"
        anchors.centerIn: parent
        spacing: -8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.today.toLocaleDateString(Qt.locale(), "dddd").toUpperCase()
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 2.4
            bottomPadding: 6
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.today.getDate()
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 82
            font.bold: true
            font.letterSpacing: -3
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.today.toLocaleDateString(Qt.locale(), w.showMonthName ? "MMMM yyyy" : "yyyy")
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 14
            topPadding: 10
        }

    }

}
