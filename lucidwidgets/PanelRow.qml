import QtQuick
import Quickshell
import qs
import qs.lucidui

// a card that is out on the desktop, as a row in the panel's list. hovering it
// outlines the card, a click opens the card's own sheet
Item {
    id: row

    required property string uid
    required property string wtype
    required property string wvariant
    required property bool pinned
    required property string screenName
    required property bool closing

    property Item panel: null
    property bool first: false
    property bool last: false

    readonly property var typeInfo: Widgets.typeAt(row.wtype)
    readonly property var variantInfo: Widgets.variantAt(row.wtype, row.wvariant)
    readonly property string where: {
        if (Quickshell.screens.length < 2)
            return "";

        if (row.screenName !== "")
            return row.screenName;

        var scr = Monitors.mainScreen;
        return scr ? scr.name : "";
    }

    function unspot() {
        if (Widgets.spotUid === row.uid)
            Widgets.spotUid = "";

    }

    width: parent ? parent.width : 0
    height: row.visible ? 64 : 0
    visible: !row.closing && row.panel !== null && row.panel.cardMatches(row.wtype, row.wvariant)
    Component.onDestruction: row.unspot()
    onVisibleChanged: {
        if (!row.visible)
            row.unspot();

    }

    Rectangle {
        id: plate

        anchors.fill: parent
        topLeftRadius: row.first ? 20 : 4
        topRightRadius: row.first ? 20 : 4
        bottomLeftRadius: row.last ? 20 : 4
        bottomRightRadius: row.last ? 20 : 4
        color: Theme.withBlur(Theme.surfaceHigh)

        Rectangle {
            anchors.fill: parent
            topLeftRadius: plate.topLeftRadius
            topRightRadius: plate.topRightRadius
            bottomLeftRadius: plate.bottomLeftRadius
            bottomRightRadius: plate.bottomRightRadius
            color: Theme.text
            opacity: rowArea.pressed ? Theme.statePressed : (rowArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.panel)
                    row.panel.openCardMenu(row.uid);

            }
        }

    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                Widgets.spotUid = row.uid;
            else
                row.unspot();
        }
    }

    MaterialShape {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        shape: "cookie9"
        color: row.pinned ? Theme.surfaceHighest : Theme.primaryContainer

        WidgetGlyph {
            anchors.centerIn: parent
            name: row.wtype
            size: 19
            color: row.pinned ? Theme.subtext : Theme.fgPrimaryContainer
        }

    }

    Column {
        anchors.left: mark.right
        anchors.leftMargin: 14
        anchors.right: actions.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        LText {
            width: parent.width
            role: "titleSmall"
            text: row.typeInfo ? row.typeInfo.name : row.wtype
            elide: Text.ElideRight
        }

        LText {
            width: parent.width
            role: "bodySmall"
            color: Theme.subtext
            text: [row.variantInfo ? row.variantInfo.name : "", row.pinned ? "Locked" : "", row.where].filter((s) => {
                return s !== "";
            }).join("  ·  ")
            elide: Text.ElideRight
        }

    }

    Row {
        id: actions

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        IconButton {
            size: "s"
            icon: "keep"
            checkable: true
            checked: row.pinned
            onClicked: Widgets.togglePinned(row.uid)
        }

        IconButton {
            size: "s"
            icon: "delete"
            onClicked: Widgets.close(row.uid)
        }

    }

}
