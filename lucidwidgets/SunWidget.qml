import QtQuick
import QtQuick.Shapes
import qs
import qs.lucidui

// sunrise and sunset worked out where you are, and where the sun is between them
WidgetBody {
    id: w

    property date now: Loc.now()
    readonly property var today: NightLight.sunTimes(w.now, Loc.lat, Loc.lon)
    readonly property var tomorrow: NightLight.sunTimes(new Date(w.now.getFullYear(), w.now.getMonth(), w.now.getDate() + 1, 12), Loc.lat, Loc.lon)
    readonly property int nowMin: w.now.getHours() * 60 + w.now.getMinutes()
    readonly property int dayLen: w.wrap(w.today.set - w.today.rise)
    readonly property bool up: w.wrap(w.nowMin - w.today.rise) < w.dayLen
    // 0 at sunrise, 1 at sunset
    readonly property real dayPos: w.up && w.dayLen > 0 ? w.wrap(w.nowMin - w.today.rise) / w.dayLen : 0
    // after sunset the next sunrise is tomorrow's
    readonly property int nextRise: w.nowMin < w.today.rise ? w.today.rise : w.tomorrow.rise
    // the pair the lists show: today's until the sun sets, then tomorrow's
    readonly property var shown: !w.up && w.nowMin >= w.today.set ? w.tomorrow : w.today
    readonly property string next: w.up ? "set" : "rise"
    readonly property int nextAt: w.up ? w.today.set : w.nextRise
    readonly property int nextIn: w.wrap(w.nextAt - w.nowMin)

    function wrap(m) {
        return ((Math.round(m) % 1440) + 1440) % 1440;
    }

    function clock(min) {
        const m = w.wrap(min);
        const h = Math.floor(m / 60);
        const mm = String(m % 60).padStart(2, "0");
        if (Prefs.clock24h)
            return String(h).padStart(2, "0") + ":" + mm;

        return ((h % 12) || 12) + ":" + mm + (h < 12 ? " AM" : " PM");
    }

    function span(min) {
        const h = Math.floor(min / 60);
        const m = min % 60;
        if (h === 0)
            return I18n.tr("%1 min", m);

        return m === 0 ? h + " h" : I18n.tr("%1 h %2 min", h, m);
    }

    defaultTone: "tertiary"

    Timer {
        interval: 30000
        repeat: true
        running: !w.preview
        onTriggered: w.now = Loc.now()
    }

    // arc: the sun on its road over the horizon, the stretch behind it drawn in
    Item {
        id: arc

        readonly property real pad: Theme.dp(18)
        readonly property real sun: Theme.dp(30)
        readonly property real horizon: Theme.dp(112)
        readonly property real rx: (arc.width - arc.pad * 2 - arc.sun) / 2
        readonly property real ry: arc.horizon - arc.pad - arc.sun / 2
        readonly property real angle: Math.PI * (1 + w.dayPos)

        visible: w.variant === "arc"
        anchors.fill: parent

        Item {
            width: parent.width
            height: arc.horizon
            clip: true

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Theme.alpha(w.ink, 0.24)
                    strokeWidth: Theme.dp(2)
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [2, 3]
                    capStyle: ShapePath.FlatCap

                    PathAngleArc {
                        centerX: arc.width / 2
                        centerY: arc.horizon
                        radiusX: arc.rx
                        radiusY: arc.ry
                        startAngle: 180
                        sweepAngle: 180
                    }

                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: w.up && w.dayPos > 0.005 ? w.inkAccent : "transparent"
                    strokeWidth: Theme.dp(4)
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: arc.width / 2
                        centerY: arc.horizon
                        radiusX: arc.rx
                        radiusY: arc.ry
                        startAngle: 180
                        sweepAngle: 180 * w.dayPos
                    }

                }

            }

            // below the horizon it waits half sunk at the end it went down or comes up at
            MaterialShape {
                readonly property real cx: w.up ? arc.width / 2 + Math.cos(arc.angle) * arc.rx : arc.width / 2 + (w.wrap(w.nowMin - w.today.set) < 720 ? arc.rx : -arc.rx)
                readonly property real cy: w.up ? arc.horizon + Math.sin(arc.angle) * arc.ry : arc.horizon

                x: cx - width / 2
                y: cy - height / 2
                width: arc.sun
                height: arc.sun
                shape: "sunny"
                color: w.inkAccent
                rotation: w.dayPos * 360
                opacity: w.up ? 1 : 0.55
            }

        }

        Rectangle {
            x: arc.pad
            y: arc.horizon
            width: arc.width - arc.pad * 2
            height: 1
            color: Theme.alpha(w.ink, 0.28)
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: arc.horizon - height - Theme.dp(10)
            spacing: -Theme.dp(2)

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelMedium"
                color: w.inkDim
                text: w.next === "set" ? I18n.tr("Sunset in") : I18n.tr("Sunrise in")
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "titleLarge"
                weight: 600
                rounded: 100
                color: w.ink
                text: w.span(w.nextIn)
            }

        }

        Column {
            x: arc.pad
            y: arc.horizon + Theme.dp(10)
            spacing: -Theme.dp(1)

            LText {
                role: "labelMedium"
                color: w.inkDim
                text: I18n.tr("Sunrise")
            }

            LText {
                role: "titleMedium"
                weight: 600
                tabular: true
                color: w.ink
                text: w.clock(w.shown.rise)
            }

        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: arc.pad
            y: arc.horizon + Theme.dp(10)
            spacing: -Theme.dp(1)

            LText {
                anchors.right: parent.right
                role: "labelMedium"
                color: w.inkDim
                text: I18n.tr("Sunset")
            }

            LText {
                anchors.right: parent.right
                role: "titleMedium"
                weight: 600
                tabular: true
                color: w.ink
                text: w.clock(w.shown.set)
            }

        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: arc.horizon + Theme.dp(12)
            spacing: -Theme.dp(1)

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelMedium"
                weight: 600
                color: w.ink
                text: w.span(w.dayLen)
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelSmall"
                color: w.inkFaint
                text: I18n.tr("of daylight")
            }

        }

    }

    // times: sunrise over sunset with a wave between, the next one counting down
    Item {
        id: times

        visible: w.variant === "times"
        anchors.fill: parent

        Repeater {
            model: w.variant === "times" ? ["rise", "set"] : []

            Item {
                id: srow

                required property string modelData
                required property int index
                readonly property bool rise: srow.modelData === "rise"
                readonly property bool isNext: w.next === srow.modelData

                x: Theme.dp(18)
                y: srow.index === 0 ? Theme.dp(14) : times.height - height - Theme.dp(14)
                width: times.width - Theme.dp(36)
                height: Theme.dp(58)

                MaterialShape {
                    id: mark

                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(46)
                    height: Theme.dp(46)
                    shape: srow.rise ? "sunny" : "semiCircle"
                    color: srow.isNext ? w.inkAccent : Theme.alpha(w.inkAccent, 0.45)
                }

                Column {
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.dp(14)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -Theme.dp(2)

                    LText {
                        width: parent.width
                        elide: Text.ElideRight
                        role: "labelLarge"
                        color: srow.isNext ? w.inkAccent : w.inkDim
                        text: (srow.rise ? I18n.tr("Sunrise") : I18n.tr("Sunset")) + (srow.isNext ? I18n.tr(" · in %1", w.span(w.nextIn)) : "")
                    }

                    LText {
                        size: Theme.dp(26)
                        weight: 600
                        rounded: 100
                        tabular: true
                        color: w.ink
                        text: w.clock(srow.rise ? w.shown.rise : w.shown.set)
                    }

                }

            }

        }

        LinearProgress {
            x: Theme.dp(18)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.dp(36)
            value: 1
            wavy: true
            flowing: false
            valueAnimated: false
            thickness: Theme.dp(2)
            amplitude: Theme.dp(3)
            wavelength: Theme.dp(18)
            color: Theme.alpha(w.ink, 0.22)
            trackColor: "transparent"
        }

    }

    // compact: whichever of the two comes next
    Row {
        visible: w.variant === "compact"
        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(12)

        MaterialShape {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(46)
            height: Theme.dp(46)
            shape: w.next === "rise" ? "sunny" : "semiCircle"
            color: w.inkAccent
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -Theme.dp(2)

            LText {
                role: "labelLarge"
                color: w.inkDim
                text: (w.next === "rise" ? I18n.tr("Sunrise") : I18n.tr("Sunset")) + I18n.tr(" · in %1", w.span(w.nextIn))
            }

            LText {
                size: Theme.dp(28)
                weight: 600
                rounded: 100
                tabular: true
                color: w.ink
                text: w.clock(w.nextAt)
            }

        }

    }

}
