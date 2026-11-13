import QtQuick
import qs
import qs.lucidui

// one app in the tray's panel, a grouped row as on the settings pages: its icon,
// its name and what it says about itself. a click opens the app; the more
// button (or a right click) grows the row into the app's menu, which comes
// away from the group with its corners rounding out
Item {
    id: row

    required property int index
    required property int serial
    required property bool leaving
    property var tray: null
    readonly property var item: row.tray ? row.tray.itemOf(row.serial) : null
    readonly property int rank: row.tray ? row.tray.rankOf(row.serial) : -1
    readonly property bool first: row.rank === 0
    readonly property bool last: !!row.tray && row.rank === row.tray.trayCount - 1
    readonly property bool open: !!row.tray && row.tray.openSerial === row.serial && !row.leaving
    readonly property bool wants: !row.leaving && Tray.wantsYou(row.item)
    readonly property bool hasMenu: !!row.item && row.item.hasMenu
    readonly property string name: row.item ? Tray.nameOf(row.item) : row.keptName
    readonly property string detail: row.item ? Tray.detailOf(row.item) : row.keptDetail
    property string keptName: ""
    property string keptDetail: ""
    readonly property real outer: Theme.shapeLgInc
    readonly property real inner: Theme.dp(6)
    readonly property real headH: Theme.dp(60)
    // an open row stands apart from the group
    readonly property real apart: Theme.dp(6)
    // 0 shut, 1 with its menu grown out; run from onOpenChanged, so the curve
    // for each way is the one read
    property real reveal: 0
    // set once as it is made: a binding would empty every row as the panel comes up
    property real born: 1
    property real gone: 0
    // an index change arms a slide to wherever the column then puts it
    property bool flipArmed: false
    property real flipFrom: 0

    function corner(top) {
        return (row.open || (top ? row.first : row.last)) ? row.outer : row.inner;
    }

    width: parent ? parent.width : 0
    height: Math.round((topGap.height + card.height + bottomGap.height + (row.last || !row.tray ? 0 : row.tray.rowGap)) * (1 - row.gone))
    opacity: row.born * (1 - row.gone)
    clip: row.gone > 0
    onNameChanged: {
        if (row.item)
            row.keptName = row.name;

    }
    onDetailChanged: {
        if (row.item)
            row.keptDetail = row.detail;

    }
    onOpenChanged: {
        revealAnim.stop();
        revealAnim.to = row.open ? 1 : 0;
        revealAnim.duration = row.open ? Theme.durMedium : Theme.durShort;
        revealAnim.easing.bezierCurve = row.open ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel;
        revealAnim.start();
    }
    onLeavingChanged: {
        if (row.leaving)
            goneAnim.start();

    }
    onIndexChanged: {
        if (!row.tray || !row.tray.slotsReady)
            return ;

        row.flipFrom = row.y;
        row.flipArmed = true;
        flipDisarm.restart();
    }
    onYChanged: {
        if (!row.flipArmed)
            return ;

        row.flipArmed = false;
        flip.y += row.flipFrom - row.y;
        flipAnim.restart();
    }
    Component.onCompleted: {
        row.keptName = row.name;
        row.keptDetail = row.detail;
        row.reveal = row.open ? 1 : 0;
        if (!row.tray || !row.tray.slotsReady)
            return ;

        row.born = 0;
        bornAnim.start();
    }

    NumberAnimation {
        id: revealAnim

        target: row
        property: "reveal"
        easing.type: Easing.Bezier
    }

    NumberAnimation {
        id: bornAnim

        target: row
        property: "born"
        to: 1
        duration: Theme.durMedium
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    NumberAnimation {
        id: goneAnim

        target: row
        property: "gone"
        to: 1
        duration: Theme.durMedium
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedAccel
    }

    NumberAnimation {
        id: flipAnim

        target: flip
        property: "y"
        to: 0
        duration: Theme.durMedium
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    // a renumbering that moved nothing (a row gone above, already flat) arms nothing
    Timer {
        id: flipDisarm

        interval: 100
        onTriggered: row.flipArmed = false
    }

    Item {
        id: topGap

        width: 1
        height: row.open && !row.first ? row.apart : 0

        Behavior on height {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    Rectangle {
        id: card

        y: topGap.height
        width: row.width
        height: row.headH + menuBox.height
        color: row.open ? Theme.withBlur(Theme.surfaceHighest) : Theme.withBlur(Theme.bgTile)
        topLeftRadius: row.corner(true)
        topRightRadius: row.corner(true)
        bottomLeftRadius: row.corner(false)
        bottomRightRadius: row.corner(false)
        scale: 0.96 + 0.04 * row.born

        Item {
            id: head

            width: card.width
            height: row.headH

            // the header's pointer feedback; the menu's rows have their own
            Rectangle {
                anchors.fill: parent
                topLeftRadius: card.topLeftRadius
                topRightRadius: card.topRightRadius
                bottomLeftRadius: row.reveal > 0 ? 0 : card.bottomLeftRadius
                bottomRightRadius: row.reveal > 0 ? 0 : card.bottomRightRadius
                color: Theme.text
                // only while the panel is out: a hover left over from the last
                // time it was open must not greet the next one
                opacity: !row.tray || !row.tray.expanded || row.leaving ? 0 : (headArea.pressed ? Theme.statePressed : (headHover.hovered ? Theme.stateHover : 0))

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            HoverHandler {
                id: headHover
            }

            MouseArea {
                id: headArea

                anchors.fill: parent
                enabled: !row.leaving
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (!row.item)
                        return ;

                    if (mouse.button === Qt.RightButton) {
                        if (row.hasMenu)
                            row.tray.toggleRow(row.serial);

                        return ;
                    }
                    if (mouse.button === Qt.MiddleButton) {
                        row.item.secondaryActivate();
                        return ;
                    }
                    // an app that is only a menu opens it here
                    if (row.item.onlyMenu && row.hasMenu) {
                        row.tray.toggleRow(row.serial);
                        return ;
                    }
                    row.item.activate();
                    row.tray.expanded = false;
                }
                onWheel: (wheel) => {
                    // the panel's to scroll while it overflows; the app's otherwise
                    if (row.tray && row.tray.panelScrolls) {
                        wheel.accepted = false;
                        return ;
                    }
                    if (row.item) {
                        if (wheel.angleDelta.y !== 0)
                            row.item.scroll(wheel.angleDelta.y, false);

                        if (wheel.angleDelta.x !== 0)
                            row.item.scroll(wheel.angleDelta.x, true);

                    }
                    wheel.accepted = true;
                }
            }

            TrayIcon {
                id: icon

                x: Theme.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                item: row.item
                size: Theme.dp(32)
                hovered: headHover.hovered || row.open
            }

            // wanting attention: m3's small badge on the icon's corner
            Rectangle {
                visible: row.wants
                x: icon.x + icon.width - width * 0.7
                y: icon.y - height * 0.3
                width: Theme.dp(9)
                height: width
                radius: width / 2
                color: Theme.error
            }

            Column {
                anchors.left: icon.right
                anchors.leftMargin: Theme.dp(14)
                anchors.right: more.visible ? more.left : parent.right
                anchors.rightMargin: more.visible ? Theme.dp(4) : Theme.dp(16)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(1)

                LText {
                    width: parent.width
                    role: "titleSmall"
                    weight: 600
                    text: row.name
                    color: Theme.text
                    elide: Text.ElideRight
                }

                LText {
                    readonly property string line: row.detail !== "" ? row.detail : (row.wants ? "Wants your attention" : "")

                    width: parent.width
                    visible: line !== ""
                    role: "bodySmall"
                    text: line
                    color: row.wants ? Theme.error : Theme.subtext
                    elide: Text.ElideRight
                }

            }

            IconButton {
                id: more

                visible: row.hasMenu
                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                icon: row.open ? "expand_less" : "more_vert"
                size: "s"
                onClicked: row.tray.toggleRow(row.serial)
            }

        }

        // the app's menu, grown out of the row
        Item {
            id: menuBox

            y: row.headH
            width: card.width
            height: Math.round(row.reveal * (menuHolder.item ? menuHolder.item.implicitHeight + Theme.dp(10) : 0))
            clip: true

            Rectangle {
                x: Theme.dp(16)
                width: parent.width - Theme.dp(32)
                height: 1
                color: Theme.alpha(Theme.text, 0.1)
            }

            Loader {
                id: menuHolder

                x: Theme.dp(4)
                y: Theme.dp(4)
                width: parent.width - Theme.dp(8)
                active: row.open || row.reveal > 0

                sourceComponent: TrayMenu {
                    width: menuHolder.width
                    handle: row.item ? row.item.menu : null
                    minW: 0
                    maxW: menuHolder.width
                    onChosen: row.tray.chosen()
                    onOpenRequested: {
                        if (row.item)
                            row.item.activate();

                        row.tray.chosen();
                    }
                }

            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

        Behavior on topLeftRadius {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on topRightRadius {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on bottomLeftRadius {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on bottomRightRadius {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    Item {
        id: bottomGap

        y: card.y + card.height
        width: 1
        height: row.open && !row.last ? row.apart : 0

        Behavior on height {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    transform: Translate {
        id: flip
    }

}
