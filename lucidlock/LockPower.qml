import QtQuick
import qs

// the five ways out, each destructive one asking once before it takes them
Rectangle {
    id: bar

    property string pending: ""
    readonly property int morphMs: Theme.ms(380)
    readonly property var pendingAction: {
        for (var i = 0; i < Lockscreen.powerActions.length; i++) {
            if (Lockscreen.powerActions[i].id === bar.pending)
                return Lockscreen.powerActions[i];

        }
        return null;
    }

    function choose(a) {
        if (a.confirm) {
            bar.pending = a.id;
            recant.restart();
            return ;
        }
        Lockscreen.runPower(a.id);
    }

    // 0 showing the five ways out, 1 asking about one of them
    property real morph: bar.pending !== "" ? 1 : 0

    height: 60
    radius: 999
    color: Lockscreen.card
    // no Behavior here on purpose: actions.implicitWidth is already a live,
    // animating number, and easing it again is what put the bar out of step
    width: (1 - bar.morph) * (actions.implicitWidth + 24) + bar.morph * (confirm.implicitWidth + 28)

    // a question nobody answers is a question withdrawn
    Timer {
        id: recant

        interval: 7000
        onTriggered: bar.pending = ""
    }

    Behavior on morph {
        NumberAnimation {
            duration: bar.morphMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    // a button that opens into its own label rather than floating a tooltip
    // over the wallpaper. the glyph never moves; the pill grows past it
    component PowerButton: Item {
        id: pb

        required property var action
        readonly property bool hot: hover.hovered
        readonly property bool danger: pb.action.id === "shutdown"
        readonly property color tone: pb.danger ? Theme.error : Theme.text
        readonly property color rest: pb.danger ? Theme.alpha(Theme.error, 0.85) : Theme.subtext
        readonly property real shut: 48
        readonly property real full: 48 + label.implicitWidth + 16
        // how far open this pill actually is, read back off the one animation.
        // everything else on the button is a function of this, so nothing can
        // run on a clock of its own
        readonly property real openK: Math.max(0, Math.min(1, (pb.width - pb.shut) / Math.max(1, pb.full - pb.shut)))

        width: pb.hot ? pb.full : pb.shut
        height: 48
        clip: true
        scale: tap.pressed ? 0.92 : 1

        Behavior on width {
            NumberAnimation {
                duration: bar.morphMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.ms(110)
                easing.type: Easing.OutCubic
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: 999
            color: pb.danger ? Theme.alpha(Theme.error, 0.18) : Theme.alpha(Theme.text, 0.12)
            // ahead of the opening, so the container is there to grow into
            opacity: Math.min(1, pb.openK * 2.6)
        }

        LockGlyph {
            id: mark

            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: pb.action.glyph
            size: 21
            color: Theme._mix(pb.rest, pb.tone, Math.min(1, pb.openK * 2.6))
        }

        Text {
            id: label

            anchors.left: mark.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: pb.action.label
            color: pb.tone
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.weight: Font.Medium
            // the pill's own clip does the wiping; this only keeps the first
            // letter from appearing before there is room for it
            opacity: Math.max(0, Math.min(1, (pb.openK - 0.12) / 0.5))
        }

        HoverHandler {
            id: hover

            // a pointer handler ignores Item.enabled unless told to
            enabled: pb.enabled
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap

            onTapped: bar.choose(pb.action)
        }

    }

    Row {
        id: actions

        anchors.centerIn: parent
        spacing: 2
        opacity: Math.max(0, 1 - bar.morph * 2.5)
        visible: opacity > 0.01

        Repeater {
            model: Lockscreen.powerActions

            PowerButton {
                required property var modelData

                action: modelData
            }

        }

    }

    Row {
        id: confirm

        anchors.centerIn: parent
        spacing: 10
        opacity: Math.max(0, (bar.morph - 0.45) / 0.55)
        visible: opacity > 0.01

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 10
            rightPadding: 4
            text: bar.pendingAction ? bar.pendingAction.label + "?" : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            font.weight: Font.Medium
        }

        // m3 text button
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: cancelText.implicitWidth + 28
            height: 40
            radius: 999
            color: cancelHover.hovered ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent"

            Text {
                id: cancelText

                anchors.centerIn: parent
                text: "Cancel"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Medium
            }

            HoverHandler {
                id: cancelHover

                enabled: bar.enabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: bar.pending = ""
            }

        }

        // m3 filled button, error-toned for the one that ends the session
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: goText.implicitWidth + 32
            height: 40
            radius: 999
            color: goHover.hovered ? Theme.atTone(Theme.error, Theme.toneOf(Theme.error) + (Theme.isLight ? -6 : 6)) : Theme.error
            scale: goTap.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(110)
                    easing.type: Easing.OutCubic
                }

            }

            Text {
                id: goText

                anchors.centerIn: parent
                text: bar.pendingAction ? bar.pendingAction.label : ""
                color: Theme.fgError
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Medium
            }

            HoverHandler {
                id: goHover

                enabled: bar.enabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: goTap

                onTapped: {
                    var id = bar.pending;
                    bar.pending = "";
                    Lockscreen.runPower(id);
                }
            }

        }

    }

}
