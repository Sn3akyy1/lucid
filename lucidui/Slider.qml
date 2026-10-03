import QtQuick
import qs

// m3 expressive slider: a bar handle parted from the track by a gap, a stop dot
// at the end, and on the large sizes an icon set into the active track
Item {
    id: sl

    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    // "xs" | "s" | "m" | "l"
    property string size: "xs"
    property string icon: ""
    property bool disabled: false
    property bool showValue: true
    // the reading rides the end of the fill instead of living outside the track
    property bool inlineValue: false
    readonly property alias valueItem: valueLabel
    property var valueText: null
    property color activeColor: Theme.primary
    property color inactiveColor: Theme.secondaryContainer
    readonly property bool dragging: area.pressed
    readonly property bool hovered: area.containsMouse
    // the value while dragging, before it is committed
    property real live: sl.value
    // eases a value that arrives from elsewhere, a key or another control, so
    // the fill travels to it. never while the pointer is the source
    property bool easeValue: false
    // a drag the slider does not own, like the bar tooltip's card: it writes live
    // itself, and value cannot pull live back until it lets go
    property bool held: false

    property bool iconClickable: false

    signal moved(real value)
    signal released(real value)
    signal iconClicked()

    // metrics follow the size token unless a call site overrides them
    property int trackH: sl.size === "l" ? 52 : (sl.size === "m" ? 38 : (sl.size === "s" ? 22 : 14))
    property int handleH: sl.size === "l" ? 64 : (sl.size === "m" ? 50 : 36)
    property real outerR: sl.size === "l" ? 16 : (sl.size === "m" ? 12 : sl.trackH / 2)
    property int iconSize: sl.size === "l" ? 24 : 20
    // the pointer swells the control instead of just tinting it
    property int hoverGrow: 2
    readonly property bool hot: !sl.disabled && (sl.hovered || area.pressed)
    readonly property int trackHNow: sl.trackH + (sl.hot ? sl.hoverGrow : 0)
    readonly property int handleHNow: sl.handleH + (sl.hot ? sl.hoverGrow * 2 : 0)
    // a stadium cap has to stay a stadium while it grows
    readonly property real outerRNow: sl.outerR >= sl.trackH / 2 ? sl.trackHNow / 2 : sl.outerR
    readonly property int handleW: area.pressed ? 2 : (sl.hot ? 6 : 4)
    readonly property int gap: 5
    readonly property real innerR: 2
    readonly property real frac: sl.to > sl.from ? Math.max(0, Math.min(1, (sl.live - sl.from) / (sl.to - sl.from))) : 0
    readonly property real handleX: sl.handleW / 2 + sl.frac * (sl.width - sl.handleW)

    function snap(v) {
        var c = Math.max(sl.from, Math.min(sl.to, v));
        if (sl.stepSize > 0)
            c = sl.from + Math.round((c - sl.from) / sl.stepSize) * sl.stepSize;

        return c;
    }

    function valueAt(px) {
        var f = Math.max(0, Math.min(1, (px - sl.handleW / 2) / Math.max(1, sl.width - sl.handleW)));
        return sl.snap(sl.from + f * (sl.to - sl.from));
    }

    onValueChanged: {
        if (!area.pressed && !sl.held)
            sl.live = sl.value;

    }

    Behavior on live {
        enabled: sl.easeValue && !area.pressed && !sl.held

        NumberAnimation {
            duration: Theme.durFastSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

    }

    implicitWidth: 200
    implicitHeight: Math.max(sl.handleH, sl.trackH)
    opacity: sl.disabled ? Theme.disabledContent : 1

    Rectangle {
        id: active

        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, sl.handleX - sl.handleW / 2 - sl.gap)
        height: sl.trackHNow
        color: sl.activeColor
        visible: width > 0.5
        topLeftRadius: sl.outerRNow
        bottomLeftRadius: sl.outerRNow
        topRightRadius: sl.innerR
        bottomRightRadius: sl.innerR

        Behavior on height {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    Rectangle {
        id: inactive

        anchors.verticalCenter: parent.verticalCenter
        x: sl.handleX + sl.handleW / 2 + sl.gap
        width: Math.max(0, sl.width - x)
        height: sl.trackHNow
        color: sl.inactiveColor
        visible: width > 0.5
        topRightRadius: sl.outerRNow
        bottomRightRadius: sl.outerRNow
        topLeftRadius: sl.innerR
        bottomLeftRadius: sl.innerR

        Behavior on height {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Rectangle {
            anchors.fill: parent
            topRightRadius: sl.outerRNow
            bottomRightRadius: sl.outerRNow
            topLeftRadius: sl.innerR
            bottomLeftRadius: sl.innerR
            color: Theme.text
            opacity: sl.hot ? Theme.stateHover : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Math.max(3, (sl.trackHNow - 4) / 2)
            width: 4
            height: 4
            radius: 2
            color: sl.activeColor
            visible: parent.width > 14
        }

    }

    Rectangle {
        id: handle

        x: sl.handleX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: sl.handleW
        height: sl.handleHNow
        radius: width / 2
        color: sl.activeColor

        Behavior on width {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    Icon {
        id: inset

        readonly property bool fitsActive: active.width >= sl.trackH + 8
        // a stadium end centres the glyph on its cap, a squarer one needs the nudge
        readonly property int nudge: sl.outerR >= sl.trackH / 2 ? 0 : 2

        visible: sl.icon !== "" && sl.trackH >= 28
        name: sl.icon
        size: sl.iconSize
        fill: 1
        anchors.verticalCenter: parent.verticalCenter
        x: (inset.fitsActive ? 0 : inactive.x) + Math.round((sl.trackH - size) / 2) + inset.nudge
        color: inset.fitsActive ? Theme.fgPrimary : Theme.fgSecondaryContainer
    }

    // it steps over to the empty side once the fill is too short to hold it
    LText {
        id: valueLabel

        readonly property real pad: Math.max(8, sl.trackH / 4)
        readonly property real iconRoom: inset.visible ? sl.trackH : 0
        readonly property bool onActive: active.width - (inset.fitsActive ? valueLabel.iconRoom : 0) - valueLabel.pad * 2 >= valueLabel.implicitWidth

        visible: sl.inlineValue
        anchors.verticalCenter: parent.verticalCenter
        x: valueLabel.onActive ? active.width - valueLabel.pad - valueLabel.implicitWidth : inactive.x + (inset.fitsActive ? 0 : valueLabel.iconRoom) + valueLabel.pad
        role: "titleMedium"
        weight: 640
        rounded: 100
        tabular: true
        color: valueLabel.onActive ? Theme.fgPrimary : Theme.fgSecondaryContainer
        text: sl.valueText ? sl.valueText(sl.live) : Math.round(sl.frac * 100) + "%"
    }

    Rectangle {
        id: bubble

        visible: sl.showValue && opacity > 0.01
        opacity: area.pressed ? 1 : 0
        scale: area.pressed ? 1 : 0.6
        transformOrigin: Item.Bottom
        width: Math.max(36, label.implicitWidth + 20)
        height: 30
        radius: 15
        color: Theme.inverseSurface
        x: sl.handleX - width / 2
        y: -height - 8

        LText {
            id: label

            anchors.centerIn: parent
            role: "labelLarge"
            color: Theme.fgInverseSurface
            text: sl.valueText ? sl.valueText(sl.live) : Math.round(sl.frac * 100)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: !sl.disabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: (mouse) => {
            sl.live = sl.valueAt(mouse.x);
            sl.moved(sl.live);
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return ;

            sl.live = sl.valueAt(mouse.x);
            sl.moved(sl.live);
        }
        onReleased: sl.released(sl.live)
        onWheel: (wheel) => {
            var step = sl.stepSize > 0 ? sl.stepSize : (sl.to - sl.from) / 20;
            var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            sl.live = sl.snap(sl.value + (d > 0 ? step : -step));
            sl.moved(sl.live);
            sl.released(sl.live);
        }
    }


    MouseArea {
        visible: sl.iconClickable && inset.visible
        x: inset.x - 8
        y: 0
        width: inset.width + 16
        height: sl.height
        cursorShape: Qt.PointingHandCursor
        onClicked: sl.iconClicked()
    }

}
