import QtQuick
import qs
import qs.lucidui

// what the osd card shows: the level track, a keyboard light's steps, or a
// switch's badge and state. the card draws it, and so does the dock while it
// stands in for the card
Item {
    id: face

    // the Osd window, whose state this shows
    required property var osd
    // eases while it is on screen; a face out of sight jumps
    property bool live: true

    readonly property bool dragging: levelTrack.dragging
    readonly property bool hovered: levelTrack.hovered
    readonly property int toggleWidth: face.osd.cardPadX * 2 + face.osd.badgeSize + face.osd.cardGap + Math.ceil(Math.max(labelMetrics.advanceWidth, stateFlip.width)) + Theme.dp(6)

    // the reading answers the keypress
    function pulse() {
        if (face.osd.isLevelType) {
            if (!levelTrack.dragging)
                levelPulseAnim.restart();

        } else if (face.osd.isSegmentType) {
            segmentPulseAnim.restart();
        } else if (face.osd.oscType === "mic") {
            pulseAnim.restart();
        } else {
            nudgeAnim.restart();
        }
    }

    TextMetrics {
        id: labelMetrics

        text: face.osd.currentLabel
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeSize("labelSmall")
        font.variableAxes: Theme.axes(Theme.typeSize("labelSmall"), 560, 0)
    }

    Slider {
        id: levelTrack

        visible: face.osd.isLevelType
        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(10)
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        size: "m"
        trackH: face.osd.levelTrackH
        handleH: face.osd.levelHandleH
        // a full stadium cap, as round as the card behind it, squaring
        // off with it under Corner rounding
        outerR: Theme.pill(face.osd.levelTrackH)
        iconSize: Theme.dp(18)
        from: 0
        to: 100
        value: face.osd.levelMuted ? 0 : face.osd.levelValue
        icon: face.osd.levelIcon
        showValue: false
        inlineValue: true
        valueText: (v) => {
            return face.osd.levelMuted ? "Off" : Math.round(v) + "%";
        }
        activeColor: face.osd.levelMuted ? Theme.outlineStrong : Theme.primary
        inactiveColor: Theme.withBlur(Theme.surfaceHighest)
        easeValue: face.live
        onMoved: (v) => {
            return face.osd.applyLevel(v);
        }
        onReleased: face.osd.keepUp()
        onHoveredChanged: {
            if (!levelTrack.hovered)
                face.osd.keepUp();

        }

    }

    // a keyboard light with a few whole steps: one block per step. only the
    // steps that are on have a full body, the rest are a thin rail, since
    // blocks of one thickness side by side read as a bar cut in pieces
    Item {
        id: segmentRow

        readonly property int steps: Math.max(1, face.osd.kbdMax)
        readonly property int gap: Theme.dp(4)

        visible: face.osd.isSegmentType
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(16)
        anchors.rightMargin: Theme.dp(16)

        Icon {
            id: segmentIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: "keyboard"
            size: Theme.dp(18)
            fill: face.osd.kbdLevel > 0 ? 1 : 0
            color: face.osd.kbdLevel > 0 ? Theme.primary : Theme.subtextDim
        }

        LText {
            id: segmentReadout

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            role: "labelLarge"
            tabular: true
            color: face.osd.kbdLevel > 0 ? Theme.text : Theme.subtextDim
            text: face.osd.kbdLevel > 0 ? face.osd.kbdLevel + "/" + segmentRow.steps : "Off"
        }

        Row {
            id: segmentBlocks

            readonly property real blockW: (segmentBlocks.width - segmentRow.gap * (segmentRow.steps - 1)) / segmentRow.steps

            anchors.left: segmentIcon.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: segmentReadout.left
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            height: face.osd.levelTrackH / 2
            spacing: segmentRow.gap

            Repeater {
                model: segmentRow.steps

                Item {
                    required property int index
                    readonly property bool lit: index < face.osd.kbdLevel

                    width: segmentBlocks.blockW
                    height: segmentBlocks.height

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: parent.lit ? parent.height : Theme.dp(4)
                        radius: Theme.pill(height)
                        color: parent.lit ? Theme.primary : Theme.withBlur(Theme.surfaceHighest)

                        Behavior on height {
                            enabled: face.live

                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.easeEmphasizedDecel
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                }

            }

        }

    }

    Item {
        id: iconBadge

        visible: !face.osd.isLevelType && !face.osd.isSegmentType
        anchors.left: parent.left
        anchors.leftMargin: face.osd.cardPadX
        anchors.verticalCenter: parent.verticalCenter
        width: face.osd.badgeSize
        height: face.osd.badgeSize

        readonly property color fillColor: face.osd.badgeActive ? Theme.accent : Theme.withBlur(Theme.surfaceHighest)

        MaterialShape {
            id: badgeShape

            anchors.fill: parent
            shape: "cookie9"
            color: iconBadge.fillColor
            rotation: face.osd.badgeActive ? 20 : 0

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.durSlowSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

        }

        Icon {
            id: toggleGlyph

            anchors.centerIn: parent
            name: face.osd.toggleIcon
            size: face.osd.glyphSize + Theme.dp(2)
            fill: face.osd.badgeActive ? 1 : 0
            color: face.osd.badgeActive ? Theme.fgAccent : Theme.text
        }

    }

    Column {
        visible: !face.osd.isLevelType && !face.osd.isSegmentType
        anchors.left: iconBadge.right
        anchors.leftMargin: face.osd.cardGap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(2)

        LText {
            role: "labelSmall"
            color: Theme.subtext
            text: face.osd.currentLabel
        }

        // off sits above on, so flipping rolls the column up one line
        Item {
            id: stateFlip

            readonly property int lineHeight: Math.ceil(offMetrics.height)

            width: Math.ceil(Math.max(onMetrics.advanceWidth, offMetrics.advanceWidth))
            height: stateFlip.lineHeight
            clip: true

            TextMetrics {
                id: onMetrics

                text: face.osd.toggleOnText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeSize("titleMedium")
                font.variableAxes: Theme.axes(Theme.typeSize("titleMedium"), 640, 60)
            }

            TextMetrics {
                id: offMetrics

                text: face.osd.toggleOffText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeSize("titleMedium")
                font.variableAxes: Theme.axes(Theme.typeSize("titleMedium"), 640, 60)
            }

            Column {
                width: parent.width
                y: face.osd.toggleState ? -stateFlip.lineHeight : 0

                LText {
                    width: parent.width
                    height: stateFlip.lineHeight
                    role: "titleMedium"
                    weight: 640
                    rounded: 60
                    text: face.osd.toggleOffText
                    color: face.osd.toggleOffColor
                }

                LText {
                    width: parent.width
                    height: stateFlip.lineHeight
                    role: "titleMedium"
                    weight: 640
                    rounded: 60
                    text: face.osd.toggleOnText
                    color: Theme.accent
                }

                Behavior on y {
                    enabled: face.live

                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

        }

    }

    NumberAnimation {
        id: nudgeAnim

        target: toggleGlyph
        property: "anchors.verticalCenterOffset"
        from: face.osd.toggleState ? 6 : -6
        to: 0
        duration: Theme.durLong
        easing.type: Easing.OutBack
        easing.overshoot: 2.4
    }

    SequentialAnimation {
        id: pulseAnim

        NumberAnimation {
            target: iconBadge
            property: "scale"
            to: 1.12
            duration: Theme.durQuick
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: iconBadge
            property: "scale"
            to: 1
            duration: Theme.durShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    SequentialAnimation {
        id: segmentPulseAnim

        NumberAnimation {
            target: segmentReadout
            property: "scale"
            to: 1.12
            duration: Theme.durQuick
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: segmentReadout
            property: "scale"
            to: 1
            duration: Theme.durMedium
            easing.type: Easing.OutBack
            easing.overshoot: Theme.emphasizedOvershoot
        }

    }

    SequentialAnimation {
        id: levelPulseAnim

        NumberAnimation {
            target: levelTrack.valueItem
            property: "scale"
            to: 1.12
            duration: Theme.durQuick
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: levelTrack.valueItem
            property: "scale"
            to: 1
            duration: Theme.durMedium
            easing.type: Easing.OutBack
            easing.overshoot: Theme.emphasizedOvershoot
        }

    }

}
