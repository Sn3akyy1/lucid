import QtQuick

// where a preset keeps the sign-in. the host draws the sign-in itself (pam on
// the lock, sddm on the login screen); this only places it, tells it how to
// dress, lets the editor pick it, and glides it when a preset moves it
Item {
    id: ah

    property var stage: null
    // card: on a surface of its own; bare: straight on the wallpaper; sheet:
    // inside the panel preset's side sheet
    property string authStyle: "card"
    // 1 while resting, for a preset that keeps only a hint of it until typing
    property real collapse: 0
    // at rest, the hint alone: no face and no name until typing starts
    property bool quiet: false
    readonly property bool editing: !!ah.stage && ah.stage.editing
    readonly property bool picked: ah.editing && ah.stage.selected === "auth"
    readonly property real cs: ah.stage ? ah.stage.chromeScale : 1
    readonly property var theme: ah.stage ? ah.stage.theme : null
    readonly property real lit: ah.editing ? (ah.picked ? 1 : (pick.containsMouse ? 0.6 : 0)) * ah.stage.editK : 0
    readonly property real ring: ah.dp(10) / ah.cs
    // steps back while a widget is picked, like every other widget does
    property real dimK: ah.editing && !!ah.stage.selected && ah.stage.selected !== "auth" && ah.stage.dragType === "" ? 0.45 : 1
    property real settle: 0

    onPickedChanged: {
        if (ah.picked)
            settleIn.restart();

    }

    Behavior on dimK {
        NumberAnimation {
            duration: ah.theme ? ah.theme.ms(240) : 240
            easing.type: Easing.BezierSpline
            easing.bezierCurve: ah.theme ? ah.theme.curveEffects : [0.31, 0.94, 0.34, 1, 1, 1]
        }

    }

    NumberAnimation {
        id: settleIn

        target: ah
        property: "settle"
        from: 1
        to: 0
        duration: ah.theme ? ah.theme.ms(420) : 420
        easing.type: Easing.BezierSpline
        easing.bezierCurve: ah.theme ? ah.theme.curveFastSpatial : [0.42, 1.67, 0.21, 0.9, 1, 1]
    }

    function dp(px) {
        return ah.stage ? ah.stage.dp(px) : px;
    }

    function focusInput() {
        if (body.item && body.item.focusInput)
            body.item.focusInput();

    }

    function discard() {
        if (body.item && body.item.discard)
            body.item.discard();

    }

    implicitHeight: body.item ? body.item.implicitHeight : 0

    Flip {
        id: flip

        stage: ah.stage
        key: "auth"
        home: ah
    }

    Item {
        id: visual

        width: ah.width
        height: ah.height
        opacity: flip.fade * ah.dimK
        transform: [
            Scale {
                origin.x: visual.width / 2
                origin.y: visual.height / 2
                xScale: flip.ps
                yScale: flip.ps
            },
            Scale {
                xScale: flip.ds
                yScale: flip.ds
            },
            Translate {
                x: flip.dx
                y: flip.dy
            }
        ]

        Loader {
            id: body

            width: ah.width
            height: item ? item.implicitHeight : 0
            sourceComponent: ah.stage ? ah.stage.auth : null
            // the editor's preview must not take the keyboard
            enabled: !ah.editing
            onLoaded: {
                body.item.authStyle = Qt.binding(() => {
                    return ah.authStyle;
                });
                body.item.collapse = Qt.binding(() => {
                    return ah.collapse;
                });
                body.item.quiet = Qt.binding(() => {
                    return ah.quiet;
                });
            }
        }

        Rectangle {
            id: frame

            x: -ah.ring
            y: -ah.ring
            width: ah.width + ah.ring * 2
            height: ah.height + ah.ring * 2
            visible: ah.lit > 0.01
            opacity: Math.min(1, ah.lit * 1.6)
            scale: 1 + 0.03 * ah.settle
            radius: (ah.theme ? ah.theme.shapeXl : 24) + ah.ring
            color: ah.theme ? ah.theme.alpha(ah.theme.accent, ah.picked ? 0.1 : 0.07) : "transparent"
            border.width: ah.picked ? 2.5 / ah.cs : 0
            border.color: ah.theme ? ah.theme.accent : "white"

            Behavior on opacity {
                NumberAnimation {
                    duration: ah.theme ? ah.theme.ms(160) : 160
                    easing.type: Easing.OutCubic
                }

            }

        }

        // its name on a tag on the frame's top edge; the lock says it is
        // the preset's to place, not the pointer's
        Rectangle {
            x: frame.x + frame.radius * 0.7
            y: frame.y - height / 2
            width: tagRow.implicitWidth + ah.dp(16) / ah.cs
            height: ah.dp(24) / ah.cs
            radius: height / 2
            visible: frame.visible
            opacity: frame.opacity
            scale: 1 + 0.08 * ah.settle
            transformOrigin: Item.Left
            color: ah.theme ? (ah.picked ? ah.theme.accent : ah.theme.cardHigh) : "black"

            Row {
                id: tagRow

                anchors.centerIn: parent
                spacing: ah.dp(4) / ah.cs

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "lock"
                    size: ah.dp(13) / ah.cs
                    color: ah.theme ? (ah.picked ? ah.theme.fgAccent : ah.theme.subtext) : "white"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: ah.dp(2) / ah.cs
                    text: ah.stage && ah.stage.lock ? ah.stage.lock.tr("Sign-in") : ""
                    color: ah.theme ? (ah.picked ? ah.theme.fgAccent : ah.theme.text) : "white"
                    font.family: ah.theme ? ah.theme.fontFamily : ""
                    font.pixelSize: Math.round((ah.theme ? ah.theme.fontLabelMd : 12) / ah.cs)
                    font.weight: Font.DemiBold
                }

            }

        }

    }

    MouseArea {
        id: pick

        anchors.fill: parent
        anchors.margins: -ah.dp(8) / ah.cs
        visible: ah.editing
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ah.stage.picked("auth")
    }

}
