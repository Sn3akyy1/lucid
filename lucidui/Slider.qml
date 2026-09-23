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
    property var valueText: null
    property color activeColor: Theme.primary
    property color inactiveColor: Theme.secondaryContainer
    readonly property bool dragging: area.pressed
    // the value while dragging, before it is committed
    property real live: sl.value

    property bool iconClickable: false

    signal moved(real value)
    signal released(real value)
    signal iconClicked()

    readonly property int trackH: sl.size === "l" ? 52 : (sl.size === "m" ? 38 : (sl.size === "s" ? 22 : 14))
    readonly property int handleH: sl.size === "l" ? 64 : (sl.size === "m" ? 50 : 36)
    readonly property int handleW: area.pressed ? 2 : 4
    readonly property int gap: 5
    readonly property real outerR: sl.size === "l" ? 16 : (sl.size === "m" ? 12 : sl.trackH / 2)
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
        if (!area.pressed)
            sl.live = sl.value;

    }
    implicitWidth: 200
    implicitHeight: Math.max(sl.handleH, sl.trackH)
    opacity: sl.disabled ? Theme.disabledContent : 1

    Rectangle {
        id: active

        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, sl.handleX - sl.handleW / 2 - sl.gap)
        height: sl.trackH
        color: sl.activeColor
        visible: width > 0.5
        topLeftRadius: sl.outerR
        bottomLeftRadius: sl.outerR
        topRightRadius: sl.innerR
        bottomRightRadius: sl.innerR
    }

    Rectangle {
        id: inactive

        anchors.verticalCenter: parent.verticalCenter
        x: sl.handleX + sl.handleW / 2 + sl.gap
        width: Math.max(0, sl.width - x)
        height: sl.trackH
        color: sl.inactiveColor
        visible: width > 0.5
        topRightRadius: sl.outerR
        bottomRightRadius: sl.outerR
        topLeftRadius: sl.innerR
        bottomLeftRadius: sl.innerR

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Math.max(3, (sl.trackH - 4) / 2)
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
        height: sl.handleH
        radius: width / 2
        color: sl.activeColor

        Behavior on width {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

    }

    Icon {
        id: inset

        readonly property bool fitsActive: active.width >= sl.trackH + 8

        visible: sl.icon !== "" && (sl.size === "m" || sl.size === "l")
        name: sl.icon
        size: sl.size === "l" ? 24 : 20
        fill: 1
        anchors.verticalCenter: parent.verticalCenter
        x: inset.fitsActive ? Math.round((sl.trackH - size) / 2) + 2 : inactive.x + Math.round((sl.trackH - size) / 2) + 2
        color: inset.fitsActive ? Theme.fgPrimary : Theme.fgSecondaryContainer
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
