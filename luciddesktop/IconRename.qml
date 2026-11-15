import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs

// an icon's name edited in place: a filled field set exactly where the name sits,
// as wide as what is typed, inside the icon's selection. it needs the keyboard, so
// it has an overlay of its own while the edit lasts; a click elsewhere keeps the name
PanelWindow {
    id: ed

    readonly property var item: DesktopIcons.byKey[DesktopIcons.renaming] || null
    readonly property var spot: DesktopIcons.placed[DesktopIcons.renaming] || null
    readonly property string typed: field.text.trim()
    // what stops the name going in, and what is only worth knowing
    readonly property string problem: {
        if (!ed.item)
            return "";

        if (ed.typed === "." || ed.typed === "..")
            return I18n.tr("That name is reserved");

        if (ed.item.kind !== "app" && ed.typed !== ed.item.label && DesktopIcons.byKey[ed.typed] !== undefined)
            return I18n.tr("Something here is already called that");

        return "";
    }
    readonly property string note: ed.item && ed.item.kind !== "app" && ed.typed.charAt(0) === "." && ed.item.label.charAt(0) !== "." ? I18n.tr("A name starting with a dot hides it") : ""
    // the name's own spot under the icon, in screen coordinates
    readonly property real centreX: ed.spot ? DesktopIcons.tileX(ed.spot.c) + DesktopIcons.tileW / 2 : 0
    readonly property real labelY: ed.spot ? DesktopIcons.tileY(ed.spot.r) + DesktopIcons.labelTop : 0

    function begin() {
        if (!ed.visible || !ed.item)
            return ;

        field.text = ed.item.label;
        // the name without its extension, ready to type over
        var dot = ed.item.kind === "file" ? field.text.lastIndexOf(".") : -1;
        field.select(0, dot > 0 ? dot : field.text.length);
        field.forceActiveFocus();
        enter.restart();
    }

    function commit() {
        if (DesktopIcons.renaming === "")
            return ;

        if (ed.problem !== "" || ed.typed === "") {
            shake.restart();
            return ;
        }
        DesktopIcons.rename(DesktopIcons.renaming, field.text);
        DesktopIcons.armSoon();
    }

    // a click elsewhere keeps what was typed, unless it cannot go in
    function leave() {
        if (ed.problem !== "" || ed.typed === "")
            ed.cancel();
        else
            ed.commit();
    }

    function cancel() {
        DesktopIcons.renaming = "";
        DesktopIcons.armSoon();
    }

    screen: DesktopIcons.screen
    visible: DesktopIcons.live && ed.item !== null && ed.spot !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucid-desktop-rename"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: ed.begin()
    Component.onCompleted: ed.begin()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: ed.leave()
    }

    // the name at its natural width, so the field hugs it
    TextMetrics {
        id: natural

        font: field.font
        text: field.text === "" ? I18n.tr("M") : field.text
    }

    Item {
        id: box

        readonly property real minW: DesktopIcons.tileW - Theme.dp(12)
        readonly property real maxW: DesktopIcons.tileW * 2

        width: Math.round(Math.max(box.minW, Math.min(box.maxW, natural.advanceWidth + 2 * DesktopIcons.renamePadH + Theme.dp(4))))
        height: Math.round(field.contentHeight + 2 * DesktopIcons.renamePadV + 2)
        x: Math.round(Math.max(Theme.dp(4), Math.min(ed.width - box.width - Theme.dp(4), ed.centreX - box.width / 2)))
        y: Math.round(ed.labelY - DesktopIcons.renamePadV)
        // the icon's selection wraps it, see DesktopIcon
        onWidthChanged: DesktopIcons.renameW = box.width
        onHeightChanged: DesktopIcons.renameH = box.height
        Component.onCompleted: {
            DesktopIcons.renameW = box.width;
            DesktopIcons.renameH = box.height;
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.5
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowVerticalOffset: Theme.dp(1)
        }

        transform: Translate {
            id: nudge
        }

        // filled, rounded on top, with the active line along the bottom
        Rectangle {
            anchors.fill: parent
            topLeftRadius: Theme.radiusXs
            topRightRadius: Theme.radiusXs
            bottomLeftRadius: Theme.dp(3)
            bottomRightRadius: Theme.dp(3)
            color: Theme.surfaceHighest
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: ed.problem !== "" ? Theme.error : Theme.accent

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        TextInput {
            id: field

            x: DesktopIcons.renamePadH
            y: DesktopIcons.renamePadV
            width: box.width - 2 * DesktopIcons.renamePadH
            color: Theme.text
            selectionColor: Theme.alpha(Theme.accent, 0.4)
            selectedTextColor: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.weight: Font.Medium
            horizontalAlignment: TextInput.AlignHCenter
            wrapMode: TextInput.WrapAtWordBoundaryOrAnywhere
            selectByMouse: true
            Keys.onReturnPressed: ed.commit()
            Keys.onEnterPressed: ed.commit()
            Keys.onEscapePressed: ed.cancel()

            // a name cannot hold a slash
            validator: RegularExpressionValidator {
                regularExpression: /[^\/]*/
            }

            cursorDelegate: Rectangle {
                id: caret

                width: Theme.dp(2)
                radius: 1
                color: Theme.accent

                // solid while the caret moves, blinking once it rests
                Connections {
                    function onCursorPositionChanged() {
                        blink.restart();
                    }

                    target: field
                }

                SequentialAnimation {
                    id: blink

                    running: field.activeFocus && ed.visible
                    loops: Animation.Infinite

                    PropertyAction {
                        target: caret
                        property: "opacity"
                        value: 1
                    }

                    PauseAnimation {
                        duration: 530
                    }

                    PropertyAction {
                        target: caret
                        property: "opacity"
                        value: 0
                    }

                    PauseAnimation {
                        duration: 530
                    }

                }

            }

        }

    }

    // why enter did nothing, or what the new name will do
    Rectangle {
        readonly property string say: ed.problem !== "" ? ed.problem : ed.note

        x: Math.round(Math.max(Theme.dp(4), Math.min(ed.width - width - Theme.dp(4), ed.centreX - width / 2)))
        // clear of the selection wrapped round the field
        y: box.y + box.height + Theme.dp(12)
        width: Math.min(Theme.dp(240), hint.implicitWidth + Theme.dp(20))
        height: hint.implicitHeight + Theme.dp(10)
        radius: Theme.radiusXs
        color: ed.problem !== "" ? Theme.errorContainer : Theme.surfaceHigh
        opacity: say !== "" ? 1 : 0
        visible: opacity > 0.01

        Text {
            id: hint

            anchors.centerIn: parent
            width: Math.min(implicitWidth, Theme.dp(220))
            text: parent.say
            color: ed.problem !== "" ? Theme.fgErrorContainer : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    // it grows out of the name it replaces
    ParallelAnimation {
        id: enter

        NumberAnimation {
            target: box
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durShort
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: box
            property: "scale"
            from: 0.94
            to: 1
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    // enter with a name that cannot go in
    SequentialAnimation {
        id: shake

        NumberAnimation {
            target: nudge
            property: "x"
            to: -Theme.dp(6)
            duration: 50
        }

        NumberAnimation {
            target: nudge
            property: "x"
            to: Theme.dp(5)
            duration: 70
        }

        NumberAnimation {
            target: nudge
            property: "x"
            to: -Theme.dp(3)
            duration: 60
        }

        NumberAnimation {
            target: nudge
            property: "x"
            to: 0
            duration: 60
        }

    }

}
