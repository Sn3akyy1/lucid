import QtQuick
import Quickshell.Io
import qs
import qs.lucidlumen
import qs.lucidui
import "ClockMath.js" as CM

// the time here on a big tonal face, and in the places you keep an eye on as
// one grouped list. a slider runs every clock forward or back, to see what
// time it will be there when it is six here
Item {
    id: page

    property var app: null
    property var win: null
    property bool shown: false
    // the true instant, a second at a time
    property real nowMs: Date.now()
    // minutes the clocks are run forward (or back) to compare
    property real scrub: 0
    readonly property real viewMs: page.nowMs + page.scrub * 60000
    readonly property var here: new Date(page.viewMs + (page.app ? page.app.shift : 0))
    readonly property bool wide: page.width >= Theme.dp(900)
    readonly property int edge: Theme.dp(32)
    property bool searching: false
    property var allZones: []
    // offsets of zones looked up while searching, minutes east by name
    property var probed: ({})
    readonly property string query: field.text.trim()
    readonly property var results: page.search(page.query)
    readonly property bool digital: page.app && page.app.prefs.face === "digital"
    readonly property string primaryIcon: "add"
    readonly property string primaryLabel: "Add a city"

    function primaryAction() {
        page.searching = true;
        if (page.allZones.length === 0)
            lister.running = true;

        field.input.forceActiveFocus();
    }

    function handleKey(e) {
        if (e.key === Qt.Key_N && !(e.modifiers & Qt.ControlModifier)) {
            page.primaryAction();
            return true;
        }
        return false;
    }

    function search(q) {
        const t = q.toLowerCase().replace(/ /g, "_");
        if (t === "")
            return [];

        const have = page.app ? page.app.cities : [];
        const first = [], rest = [];
        for (const z of page.allZones) {
            if (have.indexOf(z) >= 0)
                continue;

            const city = z.slice(z.lastIndexOf("/") + 1).toLowerCase();
            if (city.indexOf(t) === 0)
                first.push(z);
            else if (z.toLowerCase().indexOf(t) >= 0)
                rest.push(z);
            if (first.length >= 8)
                break;

        }
        return first.concat(rest).slice(0, 8);
    }

    function pick(tz) {
        page.app.send("zone.add", {
            "tz": tz
        });
        field.text = "";
        page.searching = false;
        page.win.toast(CM.cityOf(tz) + " added");
    }

    function offsetOf(tz) {
        const o = page.app ? page.app.offsets[tz] : undefined;
        return o !== undefined ? o : page.probed[tz];
    }

    function cityMenu(tz, anchor) {
        const list = page.app.cities;
        const i = list.indexOf(tz);
        const p = anchor.mapToItem(page.win.contentItem, 0, anchor.height);
        page.win.openMenu([{
            "id": "up",
            "label": "Move up",
            "icon": "arrow_upward",
            "disabled": i <= 0
        }, {
            "id": "down",
            "label": "Move down",
            "icon": "arrow_downward",
            "disabled": i < 0 || i >= list.length - 1
        }, {
            "sep": true
        }, {
            "id": "remove",
            "label": "Remove",
            "icon": "delete",
            "danger": true
        }], p.x - Theme.dp(160), p.y, (id) => {
            if (id === "up" || id === "down") {
                page.app.send("zone.move", {
                    "tz": tz,
                    "by": id === "up" ? -1 : 1
                });
            } else if (id === "remove") {
                page.app.send("zone.remove", {
                    "tz": tz
                });
                page.win.toast(CM.cityOf(tz) + " removed", "Undo", {
                    "undo": () => {
                        return page.app.send("zone.add", {
                            "tz": tz
                        });
                    }
                });
            }
        });
    }

    onResultsChanged: probeLater.restart()

    Timer {
        interval: 1000
        repeat: true
        running: page.shown
        triggeredOnStart: true
        onTriggered: page.nowMs = Date.now()
    }

    Timer {
        id: probeLater

        interval: 120
        onTriggered: {
            const want = page.results.filter((z) => {
                return page.offsetOf(z) === undefined && /^[A-Za-z0-9_+\-\/]+$/.test(z);
            });
            if (want.length === 0)
                return ;

            probe.running = false;
            // argv, never interpolated: a zone name is typed by hand
            probe.command = ["sh", "-c", "for z in \"$@\"; do printf '%s %s\\n' \"$z\" \"$(TZ=\"$z\" date +%z)\"; done", "sh"].concat(want);
            probe.running = true;
        }
    }

    Process {
        id: lister

        command: ["sh", "-c", "timedatectl list-timezones 2>/dev/null || find /usr/share/zoneinfo -type f -printf '%P\\n' | grep -E '^[A-Z][A-Za-z_]+/' | sort"]

        stdout: StdioCollector {
            onStreamFinished: page.allZones = this.text.split("\n").filter((z) => {
                return z.indexOf("/") > 0;
            })
        }

    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                const m = Object.assign({
                }, page.probed);
                for (const l of this.text.trim().split("\n")) {
                    const p = l.trim().split(" ");
                    if (p.length !== 2 || !/^[+-]\d{4}$/.test(p[1]))
                        continue;

                    m[p[0]] = (p[1][0] === "-" ? -1 : 1) * (parseInt(p[1].slice(1, 3), 10) * 60 + parseInt(p[1].slice(3, 5), 10));
                }
                page.probed = m;
            }
        }

    }

    PageHead {
        id: head

        x: page.edge
        width: parent.width - page.edge * 2
        title: "Clock"
        subtitle: {
            const zone = page.app ? page.app.hereZone : "";
            return (zone !== "" ? CM.cityOf(zone) + "  ·  " : "") + CM.utcText(page.app ? page.app.hereOffset : 0) + (page.app && page.app.cities.length ? "  ·  " + page.app.cities.length + (page.app.cities.length === 1 ? " city" : " cities") : "");
        }

        IconButton {
            icon: "schedule"
            checkable: true
            checked: !page.digital
            tooltip: checked ? "Digits only" : "Show the dial"
            onClicked: page.app.prefs.face = page.digital ? "analog" : "digital"
        }

    }

    // ---- here: the face, sized to the room it has
    Item {
        id: heroZone

        x: page.edge
        y: head.height
        width: page.wide ? Math.min(page.width * 0.42, Theme.dp(500)) : page.width - page.edge * 2
        height: page.wide ? page.height - head.height - Theme.dp(24) : heroCol.implicitHeight + Theme.dp(8)

        Column {
            id: heroCol

            anchors.horizontalCenter: parent.horizontalCenter
            y: page.wide ? Math.max(0, (heroZone.height - implicitHeight) / 2 - Theme.dp(12)) : 0
            spacing: Theme.dp(16)

            AnalogClock {
                id: face

                visible: !page.digital
                anchors.horizontalCenter: parent.horizontalCenter
                width: page.wide ? Math.max(Theme.dp(180), Math.min(heroZone.width - Theme.dp(24), heroZone.height - Theme.dp(170), Theme.dp(400))) : Math.min(heroZone.width, Theme.dp(240))
                height: width
                time: page.here
                shape: "cookie12"
                dial: Theme.atTone(Theme.primaryContainer, Theme.toneOf(Theme.primaryContainer) + (Theme.isLight ? -7 : 7))
                ink: Theme.fgPrimaryContainer
                accent: Theme.atTone(Theme.primary, Theme.isLight ? 48 : 72)
                secondColor: Theme.atTone(Theme.tertiary, Theme.isLight ? 58 : 78)
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.dp(4)

                    LText {
                        id: hm

                        size: page.digital ? Theme.fs(page.wide ? 120 : 84) : Theme.fs(56)
                        weight: 520
                        rounded: 100
                        tabular: true
                        text: CM.hourText(page.here.getHours(), page.app ? page.app.h24 : false) + ":" + CM.pad(page.here.getMinutes())
                    }

                    LText {
                        anchors.baseline: hm.baseline
                        size: Math.round(hm.size * 0.4)
                        weight: 560
                        rounded: 100
                        tabular: true
                        color: Theme.atTone(Theme.tertiary, Theme.isLight ? 50 : 78)
                        text: CM.pad(page.here.getSeconds())
                    }

                    LText {
                        visible: page.app && !page.app.h24
                        anchors.baseline: hm.baseline
                        size: Math.round(hm.size * 0.3)
                        weight: 560
                        color: Theme.subtext
                        text: page.here.getHours() < 12 ? "AM" : "PM"
                    }

                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "titleMedium"
                    color: page.scrub === 0 ? Theme.subtext : Theme.primary
                    text: page.scrub === 0 ? page.here.toLocaleDateString(Qt.locale(), "dddd, d MMMM") : (page.scrub > 0 ? "+" : "−") + CM.span(Math.abs(page.scrub) * 60000) + (page.scrub > 0 ? " from now" : " ago") + "  ·  " + page.here.toLocaleDateString(Qt.locale(), "ddd d MMM")
                }

            }

        }

    }

    // ---- elsewhere, one grouped list
    Scroller {
        id: scroller

        x: page.wide ? heroZone.x + heroZone.width + Theme.dp(28) : 0
        y: page.wide ? head.height : heroZone.y + heroZone.height + Theme.dp(12)
        width: page.wide ? page.width - x : page.width
        height: page.height - y
        contentHeight: cityCol.implicitHeight + Theme.dp(28)

        Column {
            id: cityCol

            x: page.wide ? 0 : page.edge
            width: scroller.width - page.edge - (page.wide ? 0 : page.edge)
            spacing: Theme.dp(3)

            Repeater {
                model: page.query === "" && page.app ? page.app.cities : []

                GroupRow {
                    id: row

                    required property string modelData
                    required property int index
                    readonly property var off: page.offsetOf(row.modelData)
                    readonly property var there: row.off !== undefined ? CM.zoneTime(page.viewMs, row.off) : null
                    readonly property int diff: row.off !== undefined ? row.off - (page.app ? page.app.hereOffset : 0) : 0
                    readonly property bool day: row.there !== null && CM.daytime(row.there)

                    width: cityCol.width
                    height: Theme.dp(88)
                    first: row.index === 0
                    last: false

                    AnalogClock {
                        id: mini

                        x: Theme.dp(18)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(54)
                        height: Theme.dp(54)
                        time: row.there || new Date(0)
                        seconds: false
                        marks: false
                        shape: "circle"
                        dial: row.day ? Theme.secondaryContainer : Theme.withBlur(Theme.bgHigh)
                        ink: row.day ? Theme.fgSecondaryContainer : Theme.text
                        accent: Theme.primary
                    }

                    Column {
                        anchors.left: mini.right
                        anchors.leftMargin: Theme.dp(16)
                        anchors.right: timeRow.left
                        anchors.rightMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(2)

                        LText {
                            width: parent.width
                            role: "titleMedium"
                            elide: Text.ElideRight
                            text: CM.cityOf(row.modelData)
                        }

                        LText {
                            width: parent.width
                            role: "bodyMedium"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            text: row.there ? CM.relDay(row.there, page.here) + "  ·  " + CM.offsetText(row.diff) : "Looking it up…"
                        }

                    }

                    Row {
                        id: timeRow

                        anchors.right: more.left
                        anchors.rightMargin: Theme.dp(6)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(6)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.day ? "wb_sunny" : "clear_night"
                            size: Theme.dp(18)
                            color: Theme.subtext
                        }

                        LText {
                            id: rt

                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.fs(32)
                            weight: 480
                            rounded: 60
                            tabular: true
                            text: row.there ? CM.hourText(row.there.getHours(), page.app.h24) + ":" + CM.pad(row.there.getMinutes()) : "–:––"
                        }

                        LText {
                            visible: page.app && !page.app.h24 && row.there !== null
                            anchors.baseline: rt.baseline
                            role: "labelLarge"
                            color: Theme.subtext
                            text: row.there && row.there.getHours() < 12 ? "AM" : "PM"
                        }

                    }

                    IconButton {
                        id: more

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "more_vert"
                        tooltip: "Move or remove"
                        onClicked: page.cityMenu(row.modelData, more)
                    }

                }

            }

            // the search, in the list's own place, its finds under it
            GroupRow {
                width: cityCol.width
                height: page.searching ? Theme.dp(72) : Theme.dp(60)
                first: page.query !== "" || !page.app || page.app.cities.length === 0
                last: page.query === "" || page.results.length === 0
                hoverable: !page.searching

                TextField {
                    id: field

                    visible: page.searching
                    x: Theme.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.dp(20)
                    variant: "search"
                    placeholder: "Search for a city"
                    containerColor: Theme.withBlur(Theme.bgHigh)
                    onTextEdited: {
                        if (page.allZones.length === 0)
                            lister.running = true;

                    }
                    onAccepted: {
                        if (page.results.length > 0)
                            page.pick(page.results[0]);

                    }
                    onEscaped: {
                        field.text = "";
                        page.searching = false;
                    }
                }

                Row {
                    visible: !page.searching
                    x: Theme.dp(24)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(14)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "add"
                        size: Theme.dp(22)
                        color: Theme.primary
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "titleSmall"
                        color: Theme.primary
                        text: page.app && page.app.cities.length === 0 ? "Add a city to keep its time here" : "Add a city"
                    }

                }

                MouseArea {
                    visible: !page.searching
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.primaryAction()
                }

            }

            Repeater {
                model: page.query !== "" ? page.results : []

                GroupRow {
                    id: hit

                    required property string modelData
                    required property int index
                    readonly property var off: page.offsetOf(hit.modelData)

                    width: cityCol.width
                    height: Theme.dp(64)
                    first: false
                    last: hit.index === page.results.length - 1

                    Icon {
                        x: Theme.dp(24)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "location_on"
                        size: Theme.dp(22)
                        color: Theme.primary
                    }

                    Column {
                        x: Theme.dp(62)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - Theme.dp(20)

                        LText {
                            role: "titleSmall"
                            text: CM.cityOf(hit.modelData)
                        }

                        LText {
                            width: parent.width
                            role: "bodySmall"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            text: CM.regionOf(hit.modelData) + (hit.off !== undefined ? "  ·  " + CM.utcText(hit.off) + "  ·  " + CM.time(CM.zoneTime(page.nowMs, hit.off).getHours(), CM.zoneTime(page.nowMs, hit.off).getMinutes(), page.app.h24) : "")
                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.pick(hit.modelData)
                    }

                }

            }

            Item {
                width: 1
                height: Theme.dp(18)
            }

            // run the clocks forward or back
            GroupRow {
                width: cityCol.width
                height: compareCol.implicitHeight + Theme.dp(30)
                hoverable: false

                Column {
                    id: compareCol

                    x: Theme.dp(24)
                    y: Theme.dp(15)
                    width: parent.width - Theme.dp(48)
                    spacing: Theme.dp(8)

                    Item {
                        width: parent.width
                        height: Theme.dp(32)

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            LText {
                                role: "titleSmall"
                                text: "Compare times"
                            }

                            LText {
                                role: "bodySmall"
                                color: Theme.subtext
                                text: "Slide to see the time everywhere then"
                            }

                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.dp(6)

                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "labelLarge"
                                color: page.scrub === 0 ? Theme.subtext : Theme.primary
                                text: page.scrub === 0 ? "Now" : (page.scrub > 0 ? "+" : "−") + CM.span(Math.abs(page.scrub) * 60000)
                            }

                            IconButton {
                                visible: page.scrub !== 0
                                size: "xs"
                                icon: "replay"
                                tooltip: "Back to now"
                                onClicked: page.scrub = 0
                            }

                        }

                    }

                    Slider {
                        width: parent.width
                        from: -720
                        to: 720
                        stepSize: 15
                        value: page.scrub
                        showValue: false
                        onMoved: (v) => {
                            return page.scrub = v;
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.dp(14)

                        LText {
                            role: "labelSmall"
                            color: Theme.subtextDim
                            text: "−12 h"
                        }

                        LText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "labelSmall"
                            color: Theme.subtextDim
                            text: "now"
                        }

                        LText {
                            anchors.right: parent.right
                            role: "labelSmall"
                            color: Theme.subtextDim
                            text: "+12 h"
                        }

                    }

                }

            }

        }

    }

}
