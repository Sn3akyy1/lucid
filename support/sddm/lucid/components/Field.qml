import QtQuick

// the one field that matters: an m3 pill that owns the keyboard for the whole
// surface, whatever face the greeter is currently wearing
Item {
    id: field

    readonly property alias text: input.text
    property bool reveal: false
    // an account without a password logs in on an empty field, and so does a fingerprint
    readonly property bool canSubmit: (input.text.length > 0 || !Lock.needsPassword || Lock.fingerprint) && Lock.acceptsInput && Lock.userName !== ""
    readonly property bool bad: Lock.phase === "failed"
    readonly property bool good: Lock.granted
    // the placeholder waits for the last beads to fade before it comes back
    property bool vacant: true
    // 1 at rest on a preset that keeps only a hint of the field: the pill
    // shrinks to the hint, and opens back into the field as typing starts
    property real collapse: 0
    // the hint pill: the lock's mark at the field's own inset, the words, a margin
    readonly property real hintW: Math.min(field.width, Theme.dp(50) + hintText.implicitWidth + Theme.dp(22))
    readonly property real pillW: field.width - (field.width - field.hintW) * field.collapse
    readonly property real openK: 1 - field.collapse
    // the hint pill sits a little lower than the field and grows into it
    readonly property real pillH: field.height - Theme.dp(10) * field.collapse
    // the outline: there while the field has the keyboard or a verdict
    property real ringK: Lock.focused || field.bad || field.good ? 1 : 0
    // at rest, a nudge now and then: a while after the field settles, and every
    // few seconds after that, the pill lights up the way a hover lights it and
    // grows a little, and the lock hops and rocks, so it reads as something to use
    property real swell: 0
    property real rattle: 0
    property real glow: 0
    // the swell in whole pixels, on the pill alone: the words and the lock are
    // never scaled, or they shimmer as they re-render at every fraction
    readonly property int grow: Math.round(Theme.dp(4) * field.swell)
    // the lock's own motion: a hop in the nudge, a pop as it opens
    property real hop: 0
    property real pop: 1
    readonly property bool resting: !Lock.focused && input.text.length === 0 && !Lock.busy && !field.bad && !field.good

    // how far the opening is through the stretch from a to b, eased at both ends
    function span(a, b) {
        const t = Math.max(0, Math.min(1, (field.openK - a) / (b - a)));
        return t * t * (3 - 2 * t);
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    function pin() {
        if (input.selectionStart === input.selectionEnd && input.cursorPosition !== input.length)
            input.cursorPosition = input.length;

    }

    function clear() {
        input.text = "";
    }

    function submit() {
        if (!field.canSubmit)
            return ;

        Lock.submit(input.text);
        field.reveal = false;
    }

    implicitHeight: Theme.dp(56)

    Timer {
        id: nudgeClock

        // never while motion is off: a nudge is only motion
        running: field.resting && field.visible && true && Theme.ms(100) > 0
        repeat: true
        interval: 2600
        onRunningChanged: {
            if (nudgeClock.running)
                nudgeClock.interval = 2600;

        }
        onTriggered: {
            nudgeClock.interval = 6500;
            nudge.restart();
        }
    }

    ParallelAnimation {
        id: nudge

        // up quickly, then back on a spring that dips below and settles
        SequentialAnimation {
            NumberAnimation {
                target: field
                property: "swell"
                to: 1
                duration: Theme.ms(170)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: field
                property: "swell"
                to: 0
                duration: Theme.ms(520)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveStandard
            }

        }

        // the lock rocks on its shackle, a little less each way
        SequentialAnimation {
            PauseAnimation {
                duration: Theme.ms(60)
            }

            NumberAnimation {
                target: field
                property: "rattle"
                to: -10
                duration: Theme.ms(130)
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                target: field
                property: "rattle"
                to: 7
                duration: Theme.ms(160)
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                target: field
                property: "rattle"
                to: -3
                duration: Theme.ms(150)
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                target: field
                property: "rattle"
                to: 0
                duration: Theme.ms(170)
                easing.type: Easing.InOutSine
            }

        }

        // the pill lights as a hover would, then lets it go
        SequentialAnimation {
            NumberAnimation {
                target: field
                property: "glow"
                to: 1
                duration: Theme.ms(200)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEffects
            }

            NumberAnimation {
                target: field
                property: "glow"
                to: 0
                duration: Theme.ms(700)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEffects
            }

        }

        // the lock hops as it rattles, and lands on a spring
        SequentialAnimation {
            NumberAnimation {
                target: field
                property: "hop"
                to: 1
                duration: Theme.ms(150)
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: field
                property: "hop"
                to: 0
                duration: Theme.ms(460)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    // the right password: the lock springs open, turning as it goes
    ParallelAnimation {
        id: opened

        NumberAnimation {
            target: field
            property: "pop"
            from: 0.55
            to: 1
            duration: Theme.ms(520)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveFastSpatial
        }

        NumberAnimation {
            target: field
            property: "rattle"
            from: -24
            to: 0
            duration: Theme.ms(560)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    // a wrong one: the lock rattles while the field shakes
    SequentialAnimation {
        id: refused

        NumberAnimation {
            target: field
            property: "rattle"
            to: -16
            duration: Theme.ms(60)
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: field
            property: "rattle"
            to: 13
            duration: Theme.ms(90)
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: field
            property: "rattle"
            to: -9
            duration: Theme.ms(90)
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: field
            property: "rattle"
            to: 5
            duration: Theme.ms(80)
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: field
            property: "rattle"
            to: 0
            duration: Theme.ms(110)
            easing.type: Easing.OutQuad
        }

    }

    onGoodChanged: {
        if (field.good) {
            nudge.stop();
            opened.restart();
        }
    }

    Behavior on ringK {
        NumberAnimation {
            duration: Theme.ms(200)
            easing.type: Easing.OutCubic
        }

    }

    Timer {
        id: vacate

        interval: Theme.durDefaultEffects
        onTriggered: field.vacant = true
    }

    // sddm refusing, drawn as the door not giving
    SequentialAnimation {
        id: shake

        NumberAnimation {
            target: shift
            property: "x"
            to: -9
            duration: Theme.ms(45)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: shift
            property: "x"
            to: 9
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: shift
            property: "x"
            to: -5
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: shift
            property: "x"
            to: 5
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: shift
            property: "x"
            to: 0
            duration: Theme.ms(60)
            easing.type: Easing.OutCubic
        }

    }

    Connections {
        function onFailed() {
            field.clear();
            field.reveal = false;
            shake.restart();
            nudge.stop();
            refused.restart();
            field.focusInput();
        }

        function onSwitched() {
            field.clear();
            field.reveal = false;
        }

        target: Lock
    }

    transform: Translate {
        id: shift
    }

    Rectangle {
        id: pill

        x: (field.width - width) / 2
        y: (field.height - height) / 2
        width: field.pillW + field.grow * 2
        height: field.pillH + field.grow * 2
        radius: Theme.pill(height)
        color: field.good ? Theme.accentContainer : (field.bad ? Theme.wrongContainer : Theme.cardHigh)

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(180)
            }

        }

        // the nudge's light: the accent as a state layer, at a hover's strength
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.accent
            opacity: Theme.stateHover * 1.5 * field.glow
            visible: field.glow > 0.001
        }

    }

    // the outline, which comes in with the field rather than at a step
    Rectangle {
        x: pill.x
        y: pill.y
        width: pill.width
        height: pill.height
        radius: pill.radius
        color: "transparent"
        border.width: 2
        border.color: field.good ? Theme.accent : (field.bad ? Theme.wrong : Theme.accent)
        opacity: field.ringK * field.span(0.5, 1)
        visible: opacity > 0.01

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.ms(180)
            }

        }

    }

    // the field proper, riding the pill's edges as it opens: the mark on the
    // left, the words after it, the button on the right. never hidden: the
    // input inside keeps the keyboard even while only the hint shows
    Item {
        id: inner

        x: (field.width - field.pillW) / 2
        width: field.pillW
        height: field.height

    // the mark: the hint's and the field's in one place, one fading into the
    // other as the pill opens. the lock turns over when the password is accepted
    Item {
        id: leading

        x: Theme.dp(20)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(20)
        height: Theme.dp(20)
        // the pop grows from the middle; the rattle swings on the shackle
        scale: field.pop
        transform: [
            Rotation {
                origin.x: leading.width / 2
                origin.y: 0
                angle: field.rattle
            },
            Translate {
                y: -Theme.dp(4) * field.hop
            }
        ]

        Glyph {
            anchors.centerIn: parent
            name: Lock.fingerprint ? "finger" : "lock"
            size: Theme.dp(18)
            color: Theme.accent
            opacity: 1 - field.span(0.1, 0.6)
            visible: opacity > 0.01
        }

        Glyph {
            anchors.centerIn: parent
            size: Theme.dp(20)
            name: field.good ? "lockOpen" : "lock"
            color: field.good ? Theme.fgAccentContainer : (field.bad ? Theme.fgWrongContainer : (Lock.focused ? Theme.accent : Theme.subtext))
            opacity: field.span(0.1, 0.6)
            visible: opacity > 0.01

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(180)
                }

            }

        }

    }

    // at rest: what to do, in the pill's own words. it rolls up and away
    Text {
        id: hintText

        anchors.left: leading.right
        anchors.leftMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        text: !Lock.needsPassword ? "Press Enter to sign in" : (Lock.fingerprint ? "Touch the sensor or type" : "Type to sign in")
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyMd
        font.variableAxes: Theme.axes(Theme.fontBodyMd, 480, 0)
        font.weight: Font.Medium
        opacity: 1 - field.span(0, 0.45)
        visible: opacity > 0.01

        transform: Translate {
            y: -Theme.dp(8) * field.span(0, 0.45)
        }

    }

    // what to type, when nothing has been
    Text {
        anchors.left: leading.right
        anchors.leftMargin: Theme.dp(14)
        anchors.right: trailing.left
        anchors.rightMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        transformOrigin: Item.Left
        text: !Lock.needsPassword ? "No password needed" : (Lock.fingerprint ? "Password or fingerprint" : "Password")
        color: Lock.focused ? Theme.subtext : Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        elide: Text.ElideRight
        // there while nothing is typed, and only as far as the field is open
        property real shownK: field.vacant && !Lock.busy ? 1 : 0

        opacity: shownK * field.span(0.35, 1)
        scale: 0.94 + 0.06 * shownK
        visible: opacity > 0.01

        transform: Translate {
            y: Theme.dp(8) * (1 - field.span(0.35, 1))
        }

        Behavior on shownK {
            NumberAnimation {
                duration: Theme.durDefaultEffects
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(180)
            }

        }

    }

    // the typed secret: each character lands as a turning shape and melts
    // into a dot
    PasswordEcho {
        id: echo

        anchors.left: leading.right
        anchors.leftMargin: Theme.dp(14)
        anchors.right: trailing.left
        anchors.rightMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.dp(30)
        text: input.text
        reveal: field.reveal
        busy: Lock.busy
        selectionStart: input.selectionStart
        selectionEnd: input.selectionEnd
        color: field.good ? Theme.fgAccentContainer : (field.bad ? Theme.fgWrongContainer : Theme.text)
        edge: pill.color
        font: input.font
    }

    TextInput {
        id: input

        anchors.left: leading.right
        anchors.leftMargin: Theme.dp(14)
        anchors.right: trailing.left
        anchors.rightMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        readOnly: !Lock.acceptsInput
        echoMode: TextInput.Password
        passwordCharacter: " "
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        selectByMouse: false
        clip: true
        // on, qt opens sddm's own floating keyboard (InputMethod=qtvirtualkeyboard)
        // on every focus, touchscreen or not. the pill's MouseArea focuses instead
        activeFocusOnPress: false
        // in the tab chain with the typed-in account name, for the on-screen keyboard's Tab too
        activeFocusOnTab: true
        cursorDelegate: Item {
        }

        // the beads have no caret: the password is typed at its end, and only a
        // selection grown back from there may hold the cursor anywhere else
        onCursorPositionChanged: Qt.callLater(field.pin)
        onAccepted: field.submit()
        onTextChanged: {
            Lock.typing = input.text.length > 0;
            if (input.text.length === 0) {
                vacate.restart();
                return ;
            }
            vacate.stop();
            field.vacant = false;
            Lock.engage();
            if (Lock.phase === "failed")
                Lock.phase = "idle";

        }
        Keys.onEscapePressed: {
            input.text = "";
            field.reveal = false;
        }
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Backspace:
            case Qt.Key_Delete:
            case Qt.Key_Left:
            case Qt.Key_Right:
            case Qt.Key_Home:
            case Qt.Key_End:
                Lock.engage();
                break;
            }
        }
    }

    Row {
        id: trailing

        enabled: field.openK > 0.6
        opacity: field.span(0.45, 1)
        scale: 0.6 + 0.4 * field.span(0.45, 1)
        transformOrigin: Item.Right
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(2)

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            diameter: Theme.dp(40)
            glyphSize: Theme.dp(19)
            glyph: field.reveal ? "eyeOff" : "eye"
            glyphColor: Theme.subtext
            visible: input.text.length > 0 && !Lock.busy
            onClicked: {
                field.reveal = !field.reveal;
                field.focusInput();
            }
        }

        Rectangle {
            id: submit

            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(44)
            height: Theme.dp(44)
            radius: Theme.pill(width)
            color: field.good ? Theme.accent : (field.canSubmit || Lock.busy ? (submitArea.hovered ? Theme.accentHover : Theme.accent) : Theme.alpha(Theme.outlineStrong, 0.35))
            scale: submitTap.pressed ? 0.9 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(180)
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(110)
                    easing.type: Easing.OutCubic
                }

            }

            Glyph {
                anchors.centerIn: parent
                size: Theme.dp(20)
                name: field.good ? "check" : (Lock.fingerprint && input.text.length === 0 ? "finger" : "arrow")
                color: field.good ? Theme.fgAccent : (field.canSubmit ? Theme.fgAccent : Theme.subtextDim)
                opacity: Lock.busy ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(120)
                    }

                }

            }

            Spinner {
                anchors.centerIn: parent
                diameter: Theme.dp(22)
                color: Theme.fgAccent
                running: Lock.busy
            }

            HoverHandler {
                id: submitArea

                enabled: field.canSubmit
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: submitTap

                enabled: field.canSubmit
                onTapped: field.submit()
            }

        }

    }

    }

    // the TextInput only covers the text line, and it takes that press
    // exclusively — which is why a handler on the pill never saw a click there.
    // this sits over the whole pill, engages, then declines so the press still
    // reaches the input underneath. the trailing buttons are left alone
    MouseArea {
        anchors.left: pill.left
        anchors.right: pill.right
        anchors.rightMargin: field.openK > 0.6 ? trailing.width + Theme.dp(6) : 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            Lock.engage();
            field.focusInput();
            if (finger.active)
                Lock.openKeys();

            mouse.accepted = false;
        }

        // a finger on the field brings up the on-screen keyboard
        PointHandler {
            id: finger

            acceptedDevices: PointerDevice.TouchScreen
        }

    }

}
