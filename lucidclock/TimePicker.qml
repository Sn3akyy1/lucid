import QtQuick
import qs
import qs.lucidui
import "ClockMath.js" as CM

// material's time picker, as a dialog over the window: the time on two tiles,
// a dial to drag the hand round (hours, then minutes), or the keyboard.
// ask(hour, minute, title, cb) calls back cb(hour, minute) on OK
Item {
    id: tp

    property var app: null
    property bool shown: false
    property string title: "Select time"
    property int hour: 7
    property int minute: 0
    // "hour" | "minute"
    property string mode: "hour"
    property bool typing: false
    property var callback: null
    property bool dragging: false
    readonly property bool h24: tp.app ? tp.app.h24 : false
    readonly property bool pm: tp.hour >= 12
    readonly property real dialSize: Theme.dp(256)
    readonly property real outerR: tp.dialSize / 2 - Theme.dp(28)
    readonly property real innerR: tp.outerR - Theme.dp(38)
    // where the hand points, clockwise from the top, and how far out
    readonly property real handAngle: tp.mode === "minute" ? tp.minute * 6 : tp.hourSlot() * 30
    readonly property bool handInner: tp.mode === "hour" && tp.h24 && (tp.hour === 0 || tp.hour > 12)
    property real shownAngle: tp.handAngle

    function ask(h, m, title, cb) {
        tp.hour = h;
        tp.minute = m;
        tp.title = title || "Select time";
        tp.callback = cb;
        tp.mode = "hour";
        tp.typing = false;
        tp.shown = true;
        tp.forceActiveFocus();
    }

    function finish(ok) {
        tp.shown = false;
        const cb = tp.callback;
        tp.callback = null;
        if (ok && cb)
            cb(tp.hour, tp.minute);

    }

    function hourSlot() {
        if (tp.h24)
            return tp.hour === 0 ? 0 : (tp.hour > 12 ? tp.hour - 12 : tp.hour % 12);

        return tp.hour % 12;
    }

    function setPm(want) {
        if (want !== tp.pm)
            tp.hour = (tp.hour + 12) % 24;

    }

    // a point on the dial to a value, as the hand is pressed or dragged
    function pointTo(x, y, release) {
        const c = tp.dialSize / 2;
        const dx = x - c, dy = y - c;
        let deg = Math.atan2(dx, -dy) * 180 / Math.PI;
        if (deg < 0)
            deg += 360;

        if (tp.mode === "minute") {
            tp.minute = Math.round(deg / 6) % 60;
            return ;
        }
        const slot = Math.round(deg / 30) % 12;
        if (tp.h24) {
            const inner = Math.hypot(dx, dy) < (tp.outerR + tp.innerR) / 2;
            tp.hour = inner ? (slot === 0 ? 0 : slot + 12) : (slot === 0 ? 12 : slot);
        } else {
            tp.hour = slot + (tp.pm ? 12 : 0);
        }
        if (release)
            toMinutes.restart();

    }

    function typedHour(text) {
        let v = parseInt(text, 10);
        if (isNaN(v))
            return ;

        if (tp.h24) {
            tp.hour = Math.max(0, Math.min(23, v));
        } else {
            v = Math.max(1, Math.min(12, v));
            tp.hour = v % 12 + (tp.pm ? 12 : 0);
        }
    }

    visible: tp.shown || card.opacity > 0
    onHandAngleChanged: {
        // the short way round, never a lap of the dial
        let to = tp.handAngle;
        while (to - tp.shownAngle > 180)
            to -= 360;
        while (to - tp.shownAngle < -180)
            to += 360;
        if (tp.dragging || !tp.shown)
            tp.shownAngle = to;
        else
            sweep.go(to);
    }
    Keys.onPressed: (e) => {
        if (!tp.shown)
            return ;

        if (e.key === Qt.Key_Escape) {
            tp.finish(false);
            e.accepted = true;
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            tp.finish(true);
            e.accepted = true;
        } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            const by = e.key === Qt.Key_Up ? 1 : -1;
            if (tp.mode === "minute")
                tp.minute = (tp.minute + by + 60) % 60;
            else
                tp.hour = (tp.hour + by + 24) % 24;
            e.accepted = true;
        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
            tp.mode = tp.mode === "hour" ? "minute" : "hour";
            e.accepted = true;
        }
    }

    NumberAnimation {
        id: sweep

        function go(to) {
            sweep.stop();
            sweep.to = to;
            sweep.start();
        }

        target: tp
        property: "shownAngle"
        duration: Theme.durFastSpatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveFastSpatial
    }

    // an hour picked on the dial moves on to the minutes, as material's does
    Timer {
        id: toMinutes

        interval: 260
        onTriggered: tp.mode = "minute"
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: tp.shown ? 0.4 : 0

        MouseArea {
            anchors.fill: parent
            enabled: tp.shown
            onClicked: tp.finish(false)
            onWheel: (w) => {
                return w.accepted = true;
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Theme.dp(336)
        height: body.implicitHeight + Theme.dp(48)
        radius: Theme.shapeXl
        color: Theme.surfaceHigh
        opacity: tp.shown ? 1 : 0
        scale: tp.shown ? 1 : 0.92

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: body

            x: Theme.dp(24)
            y: Theme.dp(24)
            width: parent.width - Theme.dp(48)
            spacing: Theme.dp(20)

            LText {
                role: "labelMedium"
                color: Theme.subtext
                text: tp.typing ? "Enter time" : tp.title
            }

            // the time, as two tiles to pick which the dial sets
            Row {
                id: tiles

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.dp(6)

                TimeTile {
                    on: tp.mode === "hour"
                    text: CM.hourText(tp.hour, tp.h24)
                    hint: "Hour"
                    onPicked: tp.mode = "hour"
                    onTyped: (t) => {
                        return tp.typedHour(t);
                    }
                    onDone: tp.mode = "minute"
                }

                LText {
                    anchors.top: parent.top
                    height: Theme.dp(80)
                    verticalAlignment: Text.AlignVCenter
                    size: Theme.fs(52)
                    weight: 400
                    text: ":"
                }

                TimeTile {
                    on: tp.mode === "minute"
                    text: CM.pad(tp.minute)
                    hint: "Minute"
                    onPicked: tp.mode = "minute"
                    onTyped: (t) => {
                        const v = parseInt(t, 10);
                        if (!isNaN(v))
                            tp.minute = Math.max(0, Math.min(59, v));

                    }
                    onDone: tp.finish(true)
                }

                // am and pm, stacked, the way material sets them beside the time
                Rectangle {
                    visible: !tp.h24
                    width: Theme.dp(52)
                    height: Theme.dp(80)
                    radius: Theme.dp(8)
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.outline
                    clip: true

                    Column {
                        anchors.fill: parent

                        Repeater {
                            model: ["AM", "PM"]

                            Rectangle {
                                required property string modelData
                                required property int index
                                readonly property bool on: (index === 1) === tp.pm

                                width: parent.width
                                height: parent.height / 2
                                color: on ? Theme.tertiaryContainer : "transparent"

                                LText {
                                    anchors.centerIn: parent
                                    role: "titleSmall"
                                    color: parent.on ? Theme.fgTertiaryContainer : Theme.subtext
                                    text: modelData
                                }

                                StateLayer {
                                    onClicked: tp.setPm(index === 1)
                                }

                            }

                        }

                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                }

            }

            // the dial
            Item {
                id: dialBox

                visible: !tp.typing
                anchors.horizontalCenter: parent.horizontalCenter
                width: tp.dialSize
                height: tp.typing ? 0 : tp.dialSize

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.surfaceHighest
                }

                // the hand: a line from the middle, a dot there, a disc on the value
                Item {
                    id: hand

                    property real len: tp.handInner ? tp.innerR : tp.outerR

                    anchors.fill: parent
                    rotation: tp.shownAngle

                    Rectangle {
                        x: parent.width / 2 - width / 2
                        y: parent.height / 2 - hand.len
                        width: Theme.dp(2)
                        height: hand.len
                        color: Theme.primary
                    }

                    Rectangle {
                        id: knob

                        x: parent.width / 2 - width / 2
                        y: parent.height / 2 - hand.len - height / 2
                        width: Theme.dp(48)
                        height: Theme.dp(48)
                        radius: width / 2
                        color: Theme.primary

                        // a minute between the numbers shows as a dot on the disc
                        Rectangle {
                            anchors.centerIn: parent
                            visible: tp.mode === "minute" && tp.minute % 5 !== 0
                            width: Theme.dp(8)
                            height: Theme.dp(8)
                            radius: width / 2
                            color: Theme.fgPrimary
                        }

                    }

                    Behavior on len {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                        }

                    }

                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.dp(8)
                    height: Theme.dp(8)
                    radius: width / 2
                    color: Theme.primary
                }

                // the numbers: twelve round the edge, and the other twelve hours
                // inside them on a 24-hour clock
                Repeater {
                    model: tp.mode === "minute" ? 12 : (tp.h24 ? 24 : 12)

                    Item {
                        id: num

                        required property int index
                        readonly property bool inner: index >= 12
                        readonly property int slot: index % 12
                        readonly property real r: num.inner ? tp.innerR : tp.outerR
                        readonly property real a: num.slot * 30 * Math.PI / 180
                        readonly property int value: {
                            if (tp.mode === "minute")
                                return num.slot * 5;

                            if (tp.h24)
                                return num.inner ? (num.slot === 0 ? 0 : num.slot + 12) : (num.slot === 0 ? 12 : num.slot);

                            return num.slot === 0 ? 12 : num.slot;
                        }
                        readonly property bool picked: tp.mode === "minute" ? tp.minute === num.value : (tp.h24 ? tp.hour === num.value : (tp.hour % 12 === 0 ? 12 : tp.hour % 12) === num.value)
                        // the disc sits under this number, so its ink flips with the disc
                        readonly property real under: {
                            const d = Math.abs(((tp.shownAngle - num.slot * 30) % 360 + 540) % 360 - 180);
                            const sameRing = tp.mode === "minute" || num.inner === tp.handInner;
                            return sameRing && d < 8 ? 1 - d / 8 : 0;
                        }

                        x: tp.dialSize / 2 + num.r * Math.sin(num.a) - width / 2
                        y: tp.dialSize / 2 - num.r * Math.cos(num.a) - height / 2
                        width: Theme.dp(40)
                        height: Theme.dp(40)

                        LText {
                            anchors.centerIn: parent
                            role: num.inner ? "bodyMedium" : "bodyLarge"
                            weight: num.picked ? 600 : 400
                            color: num.under > 0.5 ? Theme.fgPrimary : (num.inner ? Theme.subtext : Theme.text)
                            text: tp.mode === "minute" ? CM.pad(num.value) : (tp.h24 && num.value === 0 ? "00" : String(num.value))
                        }

                    }

                }

                MouseArea {
                    objectName: "dial"
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (m) => {
                        tp.dragging = true;
                        tp.pointTo(m.x, m.y, false);
                    }
                    onPositionChanged: (m) => {
                        if (pressed)
                            tp.pointTo(m.x, m.y, false);

                    }
                    onReleased: (m) => {
                        tp.pointTo(m.x, m.y, true);
                        tp.dragging = false;
                    }
                    onCanceled: tp.dragging = false
                    onWheel: (w) => {
                        const by = w.angleDelta.y > 0 ? 1 : -1;
                        if (tp.mode === "minute")
                            tp.minute = (tp.minute + by + 60) % 60;
                        else
                            tp.hour = (tp.hour + by + 24) % 24;
                    }
                }

            }

            Item {
                width: parent.width
                height: Theme.dp(40)

                IconButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    icon: tp.typing ? "schedule" : "keyboard"
                    tooltip: tp.typing ? "Pick on the dial" : "Type the time"
                    onClicked: tp.typing = !tp.typing
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(8)

                    Button {
                        variant: "text"
                        text: "Cancel"
                        onClicked: tp.finish(false)
                    }

                    Button {
                        objectName: "pickerOk"
                        variant: "text"
                        text: "OK"
                        onClicked: tp.finish(true)
                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

    // one of the two big numbers: a tile to click, and with the keyboard
    // picked, a field to type into
    component TimeTile: Rectangle {
        id: tile

        property bool on: false
        property string text: ""
        property string hint: ""

        signal picked()
        signal typed(string t)
        signal done()

        width: Theme.dp(96)
        height: Theme.dp(80)
        radius: Theme.dp(8)
        color: tile.on ? Theme.primaryContainer : Theme.surfaceHighest
        border.width: tp.typing && tile.on ? 2 : 0
        border.color: Theme.primary

        LText {
            visible: !tp.typing
            anchors.centerIn: parent
            size: Theme.fs(52)
            weight: 400
            tabular: true
            color: tile.on ? Theme.fgPrimaryContainer : Theme.text
            text: tile.text
        }

        TextInput {
            id: field

            visible: tp.typing
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLength: 2
            inputMethodHints: Qt.ImhDigitsOnly
            selectByMouse: true
            color: tile.on ? Theme.fgPrimaryContainer : Theme.text
            selectionColor: Theme.alpha(Theme.primary, 0.35)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(48)
            font.features: ({
                "tnum": 1
            })
            text: tile.text
            onActiveFocusChanged: {
                if (activeFocus) {
                    tile.picked();
                    Qt.callLater(field.selectAll);
                } else {
                    field.text = Qt.binding(() => {
                        return tile.text;
                    });
                }
            }
            onTextEdited: {
                tile.typed(field.text);
                if (field.text.length === 2)
                    tile.done();

            }
            onAccepted: tp.finish(true)
            Keys.onEscapePressed: tp.finish(false)

            validator: RegularExpressionValidator {
                regularExpression: /[0-9]{0,2}/
            }

        }

        LText {
            visible: tp.typing
            anchors.top: parent.bottom
            anchors.topMargin: Theme.dp(6)
            role: "bodySmall"
            color: Theme.subtext
            text: tile.hint
        }

        StateLayer {
            visible: !tp.typing
            radius: tile.radius
            onClicked: tile.picked()
        }

    }

}
