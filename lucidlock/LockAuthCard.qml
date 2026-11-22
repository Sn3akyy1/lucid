import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidui
import "parts"

// who is being asked, the field they answer in, and the one line that tells
// them how it went. the preset says how it dresses: on a card of its own,
// bare on the wallpaper, inside the panel preset's sheet, or as one line, a
// small face beside the field
Item {
    id: card

    // card | bare | sheet | row, set by the preset's AuthHost
    property string authStyle: "card"
    // 1 at rest where the preset keeps only a hint of the field
    property real collapse: 0
    // at rest the hint alone: the face and the name wait for typing
    property bool quiet: false
    readonly property real who: card.quiet ? Math.max(0, 1 - card.collapse * 1.6) : 1
    // the settings' preview of the login screen: the account and session
    // pickers the greeter has, drawn but going nowhere
    property bool greeterLook: false
    // the parts' theme (LockTokens), for the keyboard's chip
    property var keyTokens: null
    readonly property bool boxed: card.authStyle === "card"
    // the face beside the field, and no name: the deck preset's corner
    readonly property bool inline: card.authStyle === "row"
    readonly property real mini: Theme.dp(52)
    readonly property real pad: card.boxed ? Theme.dp(24) : 0
    readonly property real face: card.authStyle === "sheet" ? Theme.dp(96) : (card.authStyle === "bare" ? Theme.dp(76) : Theme.dp(84))
    // the status line only takes room when it has something to say
    readonly property bool hasStatus: card.collapse < 0.5 && (Lockscreen.statusText !== "" || Lockscreen.layoutShort !== "" || Lockscreen.capsLock || Lockscreen.focused)

    function focusInput() {
        pw.focusInput();
    }

    // a click off the card forgets what was half-typed
    function discard() {
        pw.reveal = false;
        pw.clear();
    }

    implicitHeight: body.implicitHeight + card.pad * 2

    Rectangle {
        anchors.fill: parent
        visible: card.boxed
        radius: Theme.shapeXl
        color: Lockscreen.card
    }

    // the card counts as inside the field: clicking it aims the keyboard at the
    // pill rather than dropping back to the glance
    MouseArea {
        anchors.fill: parent
        onClicked: {
            Lockscreen.engage();
            card.focusInput();
        }
    }

    Column {
        id: body

        x: card.pad
        y: card.pad
        width: card.width - card.pad * 2
        spacing: Theme.dp(14)

        Item {
            id: avatarBox

            visible: !card.inline
            anchors.horizontalCenter: parent.horizontalCenter
            width: card.face
            height: card.face
            opacity: card.who
            scale: 0.85 + 0.15 * card.who

            // a ring in the avatar's own shape: accent while typing, red on refusal
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width + Theme.dp(10)
                height: parent.height + Theme.dp(10)
                shape: "cookie12"
                spin: avatar.spin
                color: Lockscreen.granted ? Theme.accent : (Lockscreen.phase === "failed" || Lockscreen.phase === "error" ? Theme.wrong : Theme.alpha(Theme.accent, 0.7))
                opacity: Lockscreen.focused ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(240)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(200)
                    }

                }

            }

            ShapedImage {
                id: avatar

                anchors.fill: parent
                shape: "cookie12"
                source: Lockscreen.avatar
                fallbackColor: Theme.accentContainer
                decode: 192
                // the scallops turn a little while the password is checked
                spin: Lockscreen.phase === "checking" ? 30 : 0

                Behavior on spin {
                    NumberAnimation {
                        duration: Theme.durSlowSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

                LText {
                    anchors.centerIn: parent
                    role: card.face > Theme.dp(90) ? "headlineLarge" : "headlineMedium"
                    weight: 560
                    rounded: 100
                    text: Lockscreen.initials
                    color: Theme.fgAccentContainer
                }

            }

        }

        Column {
            visible: !card.inline
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.dp(2)
            opacity: card.who

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.dp(4)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lockscreen.displayName
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: card.authStyle === "sheet" ? Theme.fontHeadlineMd : Theme.fontHeadlineSm
                    font.variableAxes: Theme.axes(card.authStyle === "sheet" ? Theme.fontHeadlineMd : Theme.fontHeadlineSm, 520, 0)
                    font.weight: Font.Medium
                }

                // the login screen's name doubles as the way to another account
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "expand_more"
                    size: Theme.dp(22)
                    color: Theme.subtext
                    visible: card.greeterLook
                }

            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lockscreen.userName
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                visible: Lockscreen.userName !== "" && Lockscreen.userName !== Lockscreen.displayName
            }

        }

        Item {
            visible: !card.inline
            width: parent.width
            height: Theme.dp(4)
        }

        Item {
            width: parent.width
            height: Math.max(pw.height, card.inline ? card.mini : 0)

            // the row's own face: small, its ring the same tell as the big one's
            Item {
                id: miniFace

                visible: card.inline
                y: (parent.height - height) / 2
                width: card.mini
                height: card.mini

                MaterialShape {
                    anchors.centerIn: parent
                    width: parent.width + Theme.dp(8)
                    height: parent.height + Theme.dp(8)
                    shape: "cookie12"
                    spin: miniAvatar.spin
                    color: Lockscreen.granted ? Theme.accent : (Lockscreen.phase === "failed" || Lockscreen.phase === "error" ? Theme.wrong : Theme.alpha(Theme.accent, 0.7))
                    opacity: Lockscreen.focused ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(240)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                ShapedImage {
                    id: miniAvatar

                    anchors.fill: parent
                    shape: "cookie12"
                    source: card.inline ? Lockscreen.avatar : ""
                    fallbackColor: Theme.accentContainer
                    decode: 128
                    spin: avatar.spin

                    LText {
                        anchors.centerIn: parent
                        role: "titleMedium"
                        weight: 600
                        rounded: 100
                        text: Lockscreen.initials
                        color: Theme.fgAccentContainer
                    }

                }

            }

            LockField {
                id: pw

                x: card.inline ? card.mini + Theme.dp(12) : 0
                y: (parent.height - height) / 2
                width: parent.width - x
                collapse: card.collapse
            }

        }

        // the status line: pam's verdict, the keyboard's warnings, or nothing
        Item {
            width: parent.width
            height: card.hasStatus ? Theme.dp(22) : 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.ms(260)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            Text {
                id: status

                anchors.left: parent.left
                anchors.right: marks.left
                anchors.rightMargin: Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                text: Lockscreen.statusText
                elide: Text.ElideRight
                horizontalAlignment: card.boxed || card.inline ? Text.AlignLeft : Text.AlignHCenter
                color: {
                    switch (Lockscreen.statusKind) {
                    case "error":
                        return Theme.wrong;
                    case "good":
                        return Theme.accent;
                    case "info":
                        return Theme.subtext;
                    }
                    return Theme.subtextDim;
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                font.variableAxes: Theme.axes(Theme.fontBodySm, Lockscreen.statusKind === "error" ? 520 : 420, 0)
                font.weight: Lockscreen.statusKind === "error" ? Font.Medium : Font.Normal
                transform: Translate {
                    id: statusShift
                }

                // every new verdict arrives rather than simply being there
                onTextChanged: {
                    if (status.text !== "")
                        statusIn.restart();

                }

                ParallelAnimation {
                    id: statusIn

                    NumberAnimation {
                        target: status
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.ms(220)
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: statusShift
                        property: "y"
                        from: 7
                        to: 0
                        duration: Theme.ms(300)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            Row {
                id: marks

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(6)

                // the commonest reason a password is refused, said where it
                // cannot be pushed aside by the refusal itself
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: capsRow.implicitWidth + Theme.dp(16)
                    height: Theme.dp(20)
                    radius: height / 2
                    color: Theme.alpha(Theme.warning, 0.18)
                    visible: Lockscreen.capsLock

                    Row {
                        id: capsRow

                        anchors.centerIn: parent
                        spacing: Theme.dp(4)

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "caps"
                            size: Theme.dp(13)
                            color: Theme.warning
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Caps Lock")
                            color: Theme.warning
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelSm
                            font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                            font.weight: Font.Medium
                        }

                    }

                }

                // which keymap is live
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: layoutText.implicitWidth + Theme.dp(18)
                    height: Theme.dp(20)
                    radius: height / 2
                    color: card.boxed ? Lockscreen.cardHigh : Lockscreen.card
                    visible: Lockscreen.layoutShort !== "" && Lockscreen.focused

                    Text {
                        id: layoutText

                        anchors.centerIn: parent
                        text: Lockscreen.layoutShort
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm
                        font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                        font.weight: Font.Medium
                    }

                }

                KeysChip {
                    anchors.verticalCenter: parent.verticalCenter
                    theme: card.keyTokens
                    base: card.boxed ? Lockscreen.cardHigh : Lockscreen.card
                    on: Lockscreen.keysOpen
                    visible: Lockscreen.focused && !card.greeterLook && card.keyTokens !== null
                    onToggled: Lockscreen.toggleKeys()
                }

            }

        }

        // the login screen's session chip, in the preview of it, dressed as the
        // greeter's: an m3 outlined chip, the name and a chevron; like the
        // greeter's, it waits for the field to open
        Item {
            width: parent.width
            height: Theme.dp(40)
            visible: card.greeterLook
            opacity: 1 - card.collapse

            Rectangle {
                anchors.centerIn: parent
                width: sessionRow.implicitWidth + Theme.dp(24)
                height: Theme.dp(32)
                radius: Theme.shapeSm
                color: "transparent"
                border.width: 1
                border.color: Theme.outline

                Row {
                    id: sessionRow

                    x: Theme.dp(16)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(8)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Hyprland")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        font.variableAxes: Theme.axes(Theme.fontLabelLg, 500, 0)
                        font.weight: Font.Medium
                    }

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "expand_more"
                        size: Theme.dp(18)
                        color: Theme.subtext
                    }

                }

            }

        }

    }

}
