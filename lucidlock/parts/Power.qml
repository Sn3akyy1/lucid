import QtQuick

// the ways out. bar is a pill whose buttons open into their own labels; round
// is a row of tonal buttons. either asks once before anything that ends a
// session or a boot, by turning into the question
WidgetBase {
    id: pw

    readonly property string style: pw.opts.style || "bar"
    readonly property var actions: {
        var all = pw.lock && pw.lock.powerActions ? pw.lock.powerActions : [];
        return all.filter((a) => {
            return pw.opts[a.id] !== false;
        });
    }
    property string pending: ""
    readonly property var pendingAction: {
        for (var i = 0; i < pw.actions.length; i++) {
            if (pw.actions[i].id === pw.pending)
                return pw.actions[i];

        }
        return null;
    }
    readonly property int morphMs: pw.theme.ms(380)
    // 0 the ways out, 1 asking about one of them
    property real morph: pw.pending !== "" ? 1 : 0
    readonly property real btn: pw.kp(pw.style === "round" ? 50 : 48)
    readonly property real barW: (1 - pw.morph) * (actions.implicitWidth + (pw.style === "round" ? 0 : pw.kp(24))) + pw.morph * (confirm.implicitWidth + pw.kp(28))
    readonly property real barH: pw.style === "round" ? Math.max(pw.btn, pw.kp(56) * pw.morph) : pw.kp(60)

    function choose(a) {
        if (pw.editing || pw.preview)
            return ;

        if (a.confirm) {
            pw.pending = a.id;
            recant.restart();
            return ;
        }
        pw.lock.runPower(a.id);
    }

    hasContent: pw.actions.length > 0
    implicitWidth: pw.barW
    implicitHeight: pw.barH
    onEnabledChanged: {
        if (!pw.enabled)
            pw.pending = "";

    }

    // a question nobody answers is a question withdrawn
    Timer {
        id: recant

        interval: 7000
        onTriggered: pw.pending = ""
    }

    Behavior on morph {
        NumberAnimation {
            duration: pw.morphMs
            easing.type: Easing.Bezier
            easing.bezierCurve: pw.theme.easeEmphasizedDecel
        }

    }

    Rectangle {
        id: bar

        x: pw.xFor(width, pw.width)
        width: pw.barW
        height: pw.barH
        radius: height / 2
        color: pw.carded || pw.onCard ? pw.theme.cardHigh : pw.theme.card
        opacity: pw.style === "round" ? pw.morph : 1
        visible: opacity > 0.01
    }

    // a bar button opens into its own label rather than floating a tooltip
    // over the wallpaper. the glyph never moves; the pill grows past it
    component BarButton: Item {
        id: pb

        required property var action
        readonly property bool hot: hover.hovered
        readonly property bool danger: pb.action.id === "shutdown"
        readonly property color tone: pb.danger ? pw.theme.error : pw.theme.text
        readonly property color rest: pb.danger ? pw.theme.alpha(pw.theme.error, 0.85) : pw.theme.subtext
        readonly property real shut: pw.btn
        readonly property real full: pw.btn + label.implicitWidth + pw.kp(16)
        // how far open, read back off the one animation, so nothing on the
        // button runs on a clock of its own
        readonly property real openK: Math.max(0, Math.min(1, (pb.width - pb.shut) / Math.max(1, pb.full - pb.shut)))

        width: pb.hot ? pb.full : pb.shut
        height: pw.btn
        clip: true
        scale: tap.pressed ? 0.92 : 1

        Behavior on width {
            NumberAnimation {
                duration: pw.morphMs
                easing.type: Easing.Bezier
                easing.bezierCurve: pw.theme.easeEmphasizedDecel
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: pw.theme.ms(110)
                easing.type: Easing.OutCubic
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: pb.danger ? pw.theme.alpha(pw.theme.error, 0.18) : pw.theme.alpha(pw.theme.text, 0.12)
            opacity: Math.min(1, pb.openK * 2.6)
        }

        Glyph {
            id: mark

            x: Math.round((pw.btn - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            name: pb.action.glyph
            size: pw.kp(21)
            color: pw.theme.mix(pb.rest, pb.tone, Math.min(1, pb.openK * 2.6))
        }

        Text {
            id: label

            x: pw.btn - pw.kp(4)
            anchors.verticalCenter: parent.verticalCenter
            text: pb.action.label
            color: pb.tone
            font.family: pw.theme.fontFamily
            font.pixelSize: Math.round(pw.theme.fontLabelLg * pw.k)
            font.variableAxes: pw.theme.axes(Math.round(pw.theme.fontLabelLg * pw.k), 520, 0)
            font.weight: Font.Medium
            opacity: Math.max(0, Math.min(1, (pb.openK - 0.12) / 0.5))
        }

        HoverHandler {
            id: hover

            enabled: pb.enabled && !pw.editing
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap

            enabled: !pw.editing
            onTapped: pw.choose(pb.action)
        }

    }

    // a round button: a tonal circle that squares off a little under the
    // pointer, its name in a small chip underneath
    component RoundButton: Item {
        id: rb

        required property var action
        readonly property bool danger: rb.action.id === "shutdown"

        width: pw.btn
        height: pw.btn
        scale: rtap.pressed ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: pw.theme.ms(110)
                easing.type: Easing.OutCubic
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: rhover.hovered ? pw.theme.shapeLg : width / 2
            color: rb.danger ? (rhover.hovered ? pw.theme.error : pw.theme.alpha(pw.theme.error, 0.2)) : (rhover.hovered ? pw.theme.accentContainer : (pw.carded || pw.onCard ? pw.theme.cardHigh : pw.theme.card))

            Behavior on radius {
                NumberAnimation {
                    duration: pw.theme.ms(220)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: pw.theme.ms(160)
                }

            }

        }

        Glyph {
            anchors.centerIn: parent
            name: rb.action.glyph
            size: pw.kp(22)
            color: rb.danger ? (rhover.hovered ? pw.theme.fgError : pw.theme.error) : (rhover.hovered ? pw.theme.fgAccentContainer : pw.theme.text)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + pw.kp(8)
            width: tip.implicitWidth + pw.kp(18)
            height: pw.kp(26)
            radius: height / 2
            color: pw.theme.cardHigh
            opacity: rhover.hovered ? 1 : 0
            visible: opacity > 0.01

            Text {
                id: tip

                anchors.centerIn: parent
                text: rb.action.label
                color: pw.theme.text
                font.family: pw.theme.fontFamily
                font.pixelSize: pw.theme.fontLabelMd
                font.variableAxes: pw.theme.axes(pw.theme.fontLabelMd, 520, 0)
                font.weight: Font.Medium
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: pw.theme.ms(140)
                }

            }

        }

        HoverHandler {
            id: rhover

            enabled: rb.enabled && !pw.editing
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: rtap

            enabled: !pw.editing
            onTapped: pw.choose(rb.action)
        }

    }

    Row {
        id: actions

        x: bar.x + (bar.width - implicitWidth) / 2
        anchors.verticalCenter: bar.verticalCenter
        spacing: pw.style === "round" ? pw.kp(10) : pw.dp(2)
        opacity: Math.max(0, 1 - pw.morph * 2.5)
        visible: opacity > 0.01

        Repeater {
            model: pw.actions

            Loader {
                id: slotLoader

                required property var modelData

                sourceComponent: pw.style === "round" ? roundC : barC

                Component {
                    id: barC

                    BarButton {
                        action: slotLoader.modelData
                    }

                }

                Component {
                    id: roundC

                    RoundButton {
                        action: slotLoader.modelData
                    }

                }

            }

        }

    }

    Row {
        id: confirm

        x: bar.x + (bar.width - implicitWidth) / 2
        anchors.verticalCenter: bar.verticalCenter
        spacing: pw.kp(10)
        opacity: Math.max(0, (pw.morph - 0.45) / 0.55)
        visible: opacity > 0.01

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: pw.kp(10)
            rightPadding: pw.kp(4)
            text: pw.pendingAction ? pw.pendingAction.label + "?" : ""
            color: pw.theme.text
            font.family: pw.theme.fontFamily
            font.pixelSize: Math.round(pw.theme.fontBodyMd * pw.k)
            font.variableAxes: pw.theme.axes(Math.round(pw.theme.fontBodyMd * pw.k), 520, 0)
            font.weight: Font.Medium
        }

        // m3 text button
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: cancelText.implicitWidth + pw.kp(28)
            height: pw.kp(40)
            radius: height / 2
            color: cancelHover.hovered ? pw.theme.alpha(pw.theme.text, pw.theme.stateHover) : "transparent"

            Text {
                id: cancelText

                anchors.centerIn: parent
                text: pw.lock ? pw.lock.tr("Cancel") : ""
                color: pw.theme.subtext
                font.family: pw.theme.fontFamily
                font.pixelSize: Math.round(pw.theme.fontLabelLg * pw.k)
                font.variableAxes: pw.theme.axes(Math.round(pw.theme.fontLabelLg * pw.k), 520, 0)
                font.weight: Font.Medium
            }

            HoverHandler {
                id: cancelHover

                enabled: pw.enabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: pw.pending = ""
            }

        }

        // m3 filled button, error-toned for the one that ends the session
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: goText.implicitWidth + pw.kp(32)
            height: pw.kp(40)
            radius: height / 2
            color: goHover.hovered ? pw.theme.errorHover : pw.theme.error
            scale: goTap.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: pw.theme.ms(110)
                    easing.type: Easing.OutCubic
                }

            }

            Text {
                id: goText

                anchors.centerIn: parent
                text: pw.pendingAction ? pw.pendingAction.label : ""
                color: pw.theme.fgError
                font.family: pw.theme.fontFamily
                font.pixelSize: Math.round(pw.theme.fontLabelLg * pw.k)
                font.variableAxes: pw.theme.axes(Math.round(pw.theme.fontLabelLg * pw.k), 520, 0)
                font.weight: Font.Medium
            }

            HoverHandler {
                id: goHover

                enabled: pw.enabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: goTap

                onTapped: {
                    var id = pw.pending;
                    pw.pending = "";
                    pw.lock.runPower(id);
                }
            }

        }

    }

}
