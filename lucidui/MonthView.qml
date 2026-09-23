import QtQuick
import qs
import qs.lucidui

// one month, for picking a day or glancing at one. today keeps lucid's pentagon; the picked day
// sits in a tonal circle; a reminder leaves a dot. paging slides the month in
Item {
    id: month

    property int year: Loc.now().getFullYear()
    property int monthIndex: Loc.now().getMonth()
    // { year, month, day } or null
    property var selected: null
    property int cell: 40
    property real slideX: 0
    property bool mondayFirst: Prefs.weekStartMonday
    property bool showHeader: true
    property bool showNav: true
    // ink, for a month drawn on a tonal card
    property color ink: Theme.text
    property color inkDim: Theme.subtext
    property color accent: Theme.primary
    property color onAccent: Theme.fgPrimary
    property color pickFill: Theme.secondaryContainer
    property color pickInk: Theme.fgSecondaryContainer
    property color markColor: Theme.tertiary
    readonly property bool isCurrent: {
        const n = Loc.now();
        return month.year === n.getFullYear() && month.monthIndex === n.getMonth();
    }
    readonly property var weekdays: month.mondayFirst ? ["M", "T", "W", "T", "F", "S", "S"] : ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var cells: {
        Agenda.tick;
        const now = Loc.now();
        const lead = (new Date(month.year, month.monthIndex, 1).getDay() + (month.mondayFirst ? 6 : 0)) % 7;
        const first = new Date(month.year, month.monthIndex, 1 - lead);
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), first.getDate() + i);
            out.push({
                "year": d.getFullYear(),
                "month": d.getMonth(),
                "day": d.getDate(),
                "other": d.getMonth() !== month.monthIndex,
                "today": d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate(),
                "marked": Agenda.hasOn(d.getFullYear(), d.getMonth(), d.getDate())
            });
        }
        return out;
    }

    signal picked(int y, int m, int d)

    function page(dir) {
        let m = month.monthIndex + dir;
        let y = month.year;
        if (m < 0) {
            m = 11;
            y -= 1;
        } else if (m > 11) {
            m = 0;
            y += 1;
        }
        month.year = y;
        month.monthIndex = m;
        slideIn.from = dir * 42;
        slideIn.restart();
    }

    function goToday() {
        const n = Loc.now();
        const dir = (n.getFullYear() * 12 + n.getMonth()) >= (month.year * 12 + month.monthIndex) ? 1 : -1;
        month.year = n.getFullYear();
        month.monthIndex = n.getMonth();
        slideIn.from = dir * 42;
        slideIn.restart();
    }

    implicitWidth: month.cell * 7
    implicitHeight: (month.showHeader ? head.height + 6 : 0) + weekRow.height + month.cell * 6

    NumberAnimation {
        id: slideIn

        target: month
        property: "slideX"
        to: 0
        duration: Theme.durDefaultSpatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveDefaultSpatial
    }

    Item {
        id: head

        visible: month.showHeader
        width: parent.width
        height: month.showHeader ? 36 : 0

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleMedium"
                weight: 600
                color: month.accent
                text: new Date(month.year, month.monthIndex, 1).toLocaleDateString(Qt.locale(), "MMMM")
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleMedium"
                weight: 420
                color: month.inkDim
                text: month.year
            }

        }

        Row {
            visible: month.showNav
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            IconButton {
                visible: !month.isCurrent
                icon: "today"
                size: "xs"
                tintOverride: month.inkDim
                onClicked: month.goToday()
            }

            IconButton {
                icon: "chevron_left"
                size: "xs"
                tintOverride: month.inkDim
                onClicked: month.page(-1)
            }

            IconButton {
                icon: "chevron_right"
                size: "xs"
                tintOverride: month.inkDim
                onClicked: month.page(1)
            }

        }

    }

    Item {
        id: body

        anchors.top: head.bottom
        anchors.topMargin: month.showHeader ? 6 : 0
        width: parent.width
        height: weekRow.height + month.cell * 6
        clip: true

        Item {
            x: month.slideX
            width: parent.width
            height: parent.height
            opacity: 1 - Math.abs(month.slideX) / 60

            Row {
                id: weekRow

                width: parent.width
                height: 22

                Repeater {
                    model: month.weekdays

                    LText {
                        required property var modelData
                        required property int index

                        width: month.cell
                        horizontalAlignment: Text.AlignHCenter
                        role: "labelMedium"
                        color: (month.mondayFirst ? index >= 5 : (index === 0 || index === 6)) ? month.accent : month.inkDim
                        text: modelData
                    }

                }

            }

            Grid {
                anchors.top: weekRow.bottom
                columns: 7

                Repeater {
                    model: month.cells

                    Item {
                        id: c

                        required property var modelData
                        readonly property bool isSelected: month.selected !== null && month.selected.year === c.modelData.year && month.selected.month === c.modelData.month && month.selected.day === c.modelData.day

                        width: month.cell
                        height: month.cell

                        Rectangle {
                            anchors.centerIn: parent
                            width: month.cell - 4
                            height: month.cell - 4
                            radius: width / 2
                            color: c.isSelected && !c.modelData.today ? month.pickFill : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durFastEffects
                                }

                            }

                        }

                        MaterialShape {
                            visible: c.modelData.today
                            anchors.centerIn: parent
                            width: month.cell
                            height: month.cell
                            shape: "pentagon"
                            color: month.accent
                            scale: area.pressed ? 0.88 : (area.containsMouse ? 1.06 : 1)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveFastSpatial
                                }

                            }

                        }

                        StateLayer {
                            id: area

                            anchors.fill: undefined
                            anchors.centerIn: parent
                            width: month.cell - 4
                            height: month.cell - 4
                            radius: width / 2
                            visible: !c.modelData.today
                            onClicked: month.picked(c.modelData.year, c.modelData.month, c.modelData.day)
                        }

                        MouseArea {
                            anchors.fill: parent
                            visible: c.modelData.today
                            cursorShape: Qt.PointingHandCursor
                            onClicked: month.picked(c.modelData.year, c.modelData.month, c.modelData.day)
                        }

                        LText {
                            anchors.centerIn: parent
                            role: "bodyMedium"
                            weight: c.modelData.today || c.isSelected ? 650 : 440
                            rounded: c.modelData.today ? 100 : 0
                            color: c.modelData.today ? month.onAccent : (c.isSelected ? month.pickInk : month.ink)
                            opacity: c.modelData.other ? 0.35 : 1
                            text: c.modelData.day
                        }

                        Rectangle {
                            visible: c.modelData.marked
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            width: 5
                            height: 5
                            radius: 2.5
                            color: c.modelData.today ? month.onAccent : month.markColor
                        }

                    }

                }

            }

        }

    }

}
