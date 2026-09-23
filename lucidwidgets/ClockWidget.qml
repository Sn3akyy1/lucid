import QtQuick
import qs
import qs.lucidui

WidgetBody {
    id: w

    defaultTone: "primary"

    readonly property bool use24: {
        var m = w.opt("hourMode");
        return m === "24" || (m === "auto" && Prefs.clock24h);
    }
    readonly property bool seconds: w.opt("seconds") === true
    readonly property bool showDate: w.opt("showDate") !== false
    readonly property var zoneSets: ({
        "eu": ["Europe/London", "Europe/Paris", "Europe/Moscow"],
        "us": ["America/New_York", "America/Chicago", "America/Los_Angeles"],
        "asia": ["Asia/Dubai", "Asia/Tokyo", "Australia/Sydney"],
        "mine": Zones.cities.slice(0, 3)
    })
    readonly property var zones: w.zoneSets[w.opt("zones")] || w.zoneSets["eu"]
    property date now: Loc.now()

    function hourOf(d) {
        var h = d.getHours();
        return w.use24 ? String(h).padStart(2, "0") : String(h % 12 === 0 ? 12 : h % 12);
    }

    function two(n) {
        return String(n).padStart(2, "0");
    }

    function ampm(d) {
        return w.use24 ? "" : (d.getHours() < 12 ? "AM" : "PM");
    }

    bare: w.variant === "minimal"
    onZonesChanged: Zones.watch(w.zones)
    Component.onCompleted: Zones.watch(w.zones)

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: w.now = Loc.now()
    }

    // digital: the time set like a headline, the date under it
    Item {
        visible: w.variant === "digital"
        anchors.fill: parent

        Row {
            x: 22
            y: 10
            spacing: 6

            LText {
                id: dTime

                size: 74
                weight: 620
                rounded: 100
                tabular: true
                color: w.ink
                text: w.hourOf(w.now) + ":" + w.two(w.now.getMinutes())
            }

            Column {
                anchors.bottom: dTime.bottom
                anchors.bottomMargin: 16
                spacing: 0

                LText {
                    visible: w.seconds
                    role: "titleMedium"
                    weight: 600
                    tabular: true
                    color: w.inkAccent
                    text: w.two(w.now.getSeconds())
                }

                LText {
                    visible: !w.use24
                    role: "labelLarge"
                    color: w.inkDim
                    text: w.ampm(w.now)
                }

            }

        }

        LText {
            visible: w.showDate
            x: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            role: "titleSmall"
            weight: 520
            color: w.inkDim
            text: w.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
        }

    }

    // stack: the hour over the minute, with the date tucked under them as one group
    Item {
        id: stack

        // sized off the card, not off `unit`, or the two size each other in a loop
        readonly property int dateSize: Math.max(11, Math.round(stack.height * 0.06))
        readonly property int dateBox: w.showDate ? Math.round(stack.dateSize * 1.45) : 0
        // the lock screen's proportions: a line box of 0.82 units, two of them
        readonly property int unit: Math.max(24, Math.min((stack.height - 52 - stack.dateBox) / 1.64, (stack.width - 56) / 1.35))

        visible: w.variant === "stack"
        anchors.fill: parent

        Column {
            id: stackGroup

            anchors.horizontalCenter: parent.horizontalCenter
            // the digits sit low in their line boxes, so nudge the group back up
            y: Math.round((stack.height - height) / 2) - Math.round(stack.unit * 0.02)
            spacing: 2

            // both lines take the width of the wider one, so a one-digit hour sits
            // centred over the minute instead of leaving a hole beside it
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(stackHour.implicitWidth, stackMin.implicitWidth)
                height: Math.round(stack.unit * 1.64)

                LText {
                    id: stackHour

                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    // a trailing negative letterSpacing narrows the layout box
                    rightPadding: Math.round(stack.unit * 0.03)
                    y: 0
                    height: Math.round(stack.unit * 0.82)
                    size: stack.unit
                    weight: 620
                    rounded: 100
                    tabular: true
                    font.letterSpacing: -Math.round(stack.unit * 0.03)
                    color: w.ink
                    text: w.hourOf(w.now)
                }

                LText {
                    id: stackMin

                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    rightPadding: Math.round(stack.unit * 0.03)
                    y: Math.round(stack.unit * 0.82)
                    height: Math.round(stack.unit * 0.82)
                    size: stack.unit
                    weight: 620
                    rounded: 100
                    tabular: true
                    font.letterSpacing: -Math.round(stack.unit * 0.03)
                    color: w.inkAccent
                    text: w.two(w.now.getMinutes())
                }

            }

            LText {
                id: stackDate

                anchors.horizontalCenter: parent.horizontalCenter
                visible: w.showDate
                size: stack.dateSize
                weight: 640
                color: w.ink
                text: w.now.toLocaleDateString(Qt.locale(), "ddd d MMM") + (w.seconds ? "  ·  " + w.two(w.now.getSeconds()) : "")
            }

        }

    }

    // analog: a scalloped dial, chunky hands, the seconds as an orbiting dot
    Item {
        id: analog

        readonly property real r: Math.min(width, height) / 2 - 12

        visible: w.variant === "analog"
        anchors.fill: parent

        MaterialShape {
            anchors.centerIn: parent
            width: analog.r * 2
            height: analog.r * 2
            shape: "cookie12"
            color: Theme.alpha(w.ink, 0.08)
        }

        Repeater {
            model: 12

            Rectangle {
                required property int index

                readonly property real a: index / 12 * 2 * Math.PI

                x: analog.width / 2 + Math.sin(a) * (analog.r - 16) - width / 2
                y: analog.height / 2 - Math.cos(a) * (analog.r - 16) - height / 2
                width: index % 3 === 0 ? 7 : 4
                height: width
                radius: width / 2
                visible: !(w.showDate && index === 3)
                color: index % 3 === 0 ? w.ink : Theme.alpha(w.ink, 0.4)
            }

        }

        // a watch's date window, where the three would be
        Rectangle {
            visible: w.showDate
            x: analog.width / 2 + analog.r - 22 - width
            anchors.verticalCenter: parent.verticalCenter
            width: dateWin.implicitWidth + 12
            height: 22
            radius: 8
            color: Theme.alpha(w.inkAccent, 0.18)

            LText {
                id: dateWin

                anchors.centerIn: parent
                role: "labelMedium"
                weight: 660
                rounded: 100
                tabular: true
                color: w.inkAccent
                text: w.now.getDate()
            }

        }

        Rectangle {
            x: analog.width / 2 - width / 2
            y: analog.height / 2 - height + width / 2
            width: 11
            height: analog.r * 0.52
            radius: 5.5
            color: w.inkAccent
            transformOrigin: Item.Bottom
            rotation: (w.now.getHours() % 12 + w.now.getMinutes() / 60) * 30
            antialiasing: true
        }

        Rectangle {
            x: analog.width / 2 - width / 2
            y: analog.height / 2 - height + width / 2
            width: 6
            height: analog.r * 0.8
            radius: 3
            color: w.ink
            transformOrigin: Item.Bottom
            rotation: (w.now.getMinutes() + w.now.getSeconds() / 60) * 6
            antialiasing: true
        }

        Rectangle {
            anchors.centerIn: parent
            width: 14
            height: 14
            radius: 7
            color: w.ink
        }

        Rectangle {
            readonly property real a: w.now.getSeconds() / 60 * 2 * Math.PI

            visible: w.seconds
            x: analog.width / 2 + Math.sin(a) * (analog.r - 3) - width / 2
            y: analog.height / 2 - Math.cos(a) * (analog.r - 3) - height / 2
            width: 10
            height: 10
            radius: 5
            color: w.inkAccent
        }

    }

    // shape: the time inside one big expressive shape
    Item {
        visible: w.variant === "shape"
        anchors.fill: parent

        MaterialShape {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - 18
            height: width
            shape: w.opt("shape") || "cookie9"
            color: w.inkAccent
            rotation: w.seconds ? w.now.getSeconds() * 6 : 0

            Behavior on rotation {
                RotationAnimation {
                    duration: Theme.durDefaultSpatial
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

        }

        Column {
            anchors.centerIn: parent
            spacing: -4

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 56
                weight: 640
                rounded: 100
                tabular: true
                color: w.onInkAccent
                text: w.hourOf(w.now) + ":" + w.two(w.now.getMinutes())
            }

            LText {
                visible: w.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelLarge"
                color: Theme.alpha(w.onInkAccent, 0.8)
                text: w.now.toLocaleDateString(Qt.locale(), "ddd d MMM")
            }

        }

    }

    // minimal: straight onto the wallpaper
    Column {
        visible: w.variant === "minimal"
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: -6

        Row {
            spacing: 6

            ShadowText {
                text: w.hourOf(w.now) + ":" + w.two(w.now.getMinutes())
                color: "white"
                shadow: true
                pixelSize: 58
                weight: 600
                rounded: 100
            }

            ShadowText {
                visible: !w.use24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: w.ampm(w.now)
                color: "white"
                shadow: true
                pixelSize: 18
                weight: 560
            }

        }

        ShadowText {
            visible: w.showDate
            text: w.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: "white"
            opacity: 0.85
            shadow: true
            pixelSize: 15
            weight: 520
        }

    }

    // world: three cities, their time and how far ahead or behind
    Column {
        visible: w.variant === "world"
        anchors.fill: parent
        anchors.margins: 12
        spacing: 3

        Repeater {
            model: w.zones

            Rectangle {
                id: city

                required property var modelData
                required property int index
                readonly property date there: {
                    w.now;
                    return Zones.timeIn(city.modelData);
                }

                width: parent.width
                height: (parent.height - 6) / 3
                topLeftRadius: city.index === 0 ? 18 : 6
                topRightRadius: city.index === 0 ? 18 : 6
                bottomLeftRadius: city.index === w.zones.length - 1 ? 18 : 6
                bottomRightRadius: city.index === w.zones.length - 1 ? 18 : 6
                color: Theme.alpha(w.ink, 0.07)

                Column {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    LText {
                        role: "titleSmall"
                        color: w.ink
                        text: Zones.cityOf(city.modelData)
                    }

                    LText {
                        role: "bodySmall"
                        color: w.inkDim
                        text: Zones.dayText(city.modelData) + (Zones.offsetText(city.modelData) !== "" ? " · " + Zones.offsetText(city.modelData) : "")
                    }

                }

                LText {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    role: "headlineSmall"
                    weight: 600
                    rounded: 100
                    tabular: true
                    color: city.index === 0 ? w.inkAccent : w.ink
                    text: w.hourOf(city.there) + ":" + w.two(city.there.getMinutes())
                }

            }

        }

    }

}
