import QtQuick
import qs
import qs.lucidui

// one item as a row: icon and name, then size, date and type in their columns
Item {
    id: row

    required property int index
    required property string name
    required property string label
    required property string uri
    required property string path
    required property string kind
    required property string slot
    required property string icon
    required property string thumb
    required property string desc
    required property double size
    required property double mtime
    required property bool hidden
    required property bool link
    required property string orig
    required property string deleted
    required property string where
    readonly property var pane: ListView.view ? ListView.view.pane : null
    readonly property var tab: row.pane ? row.pane.tab : null
    readonly property bool selected: row.tab !== null && row.tab.rev >= 0 && row.tab.isSelected(row.uri)
    readonly property bool isCurrent: row.tab !== null && row.tab.current === row.index && row.pane.keyboardFocus
    // a run of selected rows reads as one block: the corners they share go square
    readonly property bool joinUp: row.selected && row.neighbourSelected(-1)
    readonly property bool joinDown: row.selected && row.neighbourSelected(1)
    property bool dropping: false
    property url dragImage

    function neighbourSelected(d) {
        var t = row.tab, i = row.index + d;
        return t !== null && t.rev >= 0 && i >= 0 && i < t.model.count && t.isSelected(t.model.get(i).uri);
    }

    width: ListView.view ? ListView.view.width : Theme.dp(600)
    height: Theme.dp(42)
    // what the view's transitions animate as an item comes and goes
    property real enter: 1
    property real pop: 1

    opacity: (row.hidden ? 0.62 : 1) * (row.pane && row.pane.isCut(row.uri) ? 0.5 : 1) * row.enter
    scale: row.pop
    // a delegate taken back from the pool starts whole, whatever it left as
    ListView.onReused: {
        row.enter = 1;
        row.pop = 1;
    }

    Rectangle {
        id: plate

        anchors.fill: parent
        anchors.leftMargin: Theme.dp(8)
        anchors.rightMargin: Theme.dp(8)
        anchors.topMargin: Theme.dp(1)
        anchors.bottomMargin: Theme.dp(1)
        radius: height / 2
        topLeftRadius: row.joinUp ? Theme.dp(6) : height / 2
        topRightRadius: row.joinUp ? Theme.dp(6) : height / 2
        bottomLeftRadius: row.joinDown ? Theme.dp(6) : height / 2
        bottomRightRadius: row.joinDown ? Theme.dp(6) : height / 2
        color: row.dropping ? Theme.alpha(Theme.accent, 0.22) : row.selected ? Theme.accentContainer : "transparent"
        // picked, the row's plate swells out from its middle
        scale: row.selected || row.dropping ? 1 : 0.97

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }
        border.width: row.isCurrent && !row.selected ? Theme.dp(2) : 0
        border.color: Theme.alpha(Theme.accent, 0.6)

        HoverLayer {
            area: area
            radius: row.joinUp || row.joinDown ? Theme.dp(6) : parent.radius
            tint: row.selected ? Theme.fgAccentContainer : Theme.text
        }

    }

    Row {
        id: cols

        anchors.fill: plate
        anchors.leftMargin: Theme.dp(14)
        anchors.rightMargin: Theme.dp(14)
        spacing: Theme.dp(12)

        Item {
            width: cols.width - row.pane.colSize - row.pane.colDate - row.pane.colType - 3 * cols.spacing
            height: cols.height

            FileGlyph {
                id: glyph

                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(26)
                slot: row.slot
                icon: row.icon
                thumb: row.thumb
                kind: row.kind
                legacy: row.pane ? row.pane.legacy : false
                hovered: area.containsMouse || row.dropping
                scale: area.pressed && !row.pane.dragging ? 0.9 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

            }

            Icon {
                visible: row.link
                anchors.right: glyph.right
                anchors.bottom: glyph.bottom
                anchors.rightMargin: -Theme.dp(3)
                anchors.bottomMargin: -Theme.dp(3)
                name: "link"
                size: Theme.dp(13)
                color: Theme.text
                animateColor: false
            }

            LText {
                anchors.left: glyph.right
                anchors.leftMargin: Theme.dp(12)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                role: "bodyMedium"
                text: row.label
                color: row.selected ? Theme.fgAccentContainer : Theme.text
                elide: Text.ElideMiddle
            }

        }

        LText {
            width: row.pane.colSize
            anchors.verticalCenter: parent.verticalCenter
            role: "bodySmall"
            horizontalAlignment: Text.AlignRight
            text: row.kind === "dir" ? "" : row.pane.app.sizeText(row.size)
            color: row.selected ? Theme.fgAccentContainer : Theme.subtext
            elide: Text.ElideRight
        }

        LText {
            width: row.pane.colDate
            anchors.verticalCenter: parent.verticalCenter
            role: "bodySmall"
            text: row.tab && row.tab.isTrash ? row.pane.app.deletedText(row.deleted) : row.pane.app.dateText(row.mtime)
            color: row.selected ? Theme.fgAccentContainer : Theme.subtext
            elide: Text.ElideRight
        }

        LText {
            width: row.pane.colType
            anchors.verticalCenter: parent.verticalCenter
            role: "bodySmall"
            text: row.tab && row.tab.isTrash ? row.pane.app.parentOf(row.orig).replace(row.pane.app.home, "~") : row.where !== "" ? row.where.replace(row.pane.app.home, "~") : row.desc
            color: row.selected ? Theme.fgAccentContainer : Theme.subtext
            elide: row.where !== "" || row.orig !== "" ? Text.ElideLeft : Text.ElideRight
        }

    }

    MouseArea {
        id: area

        anchors.fill: plate
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        // past a few pixels with the button down, the pane carries the drag
        property point pressAt

        onPositionChanged: (mouse) => {
            if (!area.pressed || !(mouse.buttons & Qt.LeftButton) || row.pane.dragging)
                return ;

            if (Math.abs(mouse.x - area.pressAt.x) + Math.abs(mouse.y - area.pressAt.y) < Theme.dp(8))
                return ;

            row.pane.startDrag(row.pane.dragUris(row.uri), row.dragImage);
        }
        onPressed: (mouse) => {
            area.pressAt = Qt.point(mouse.x, mouse.y);
            row.pane.takeFocus();
            if (mouse.button === Qt.LeftButton) {
                if (!row.selected && !(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)))
                    row.tab.selectOnly(row.index);

                glyph.grabToImage(function(r) {
                    row.dragImage = r.url;
                });
            }
        }
        onClicked: (mouse) => {
            return row.pane.itemClicked(row.index, mouse, area);
        }
        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                row.pane.itemActivated(row.index, false);

        }
    }

    DropArea {
        anchors.fill: plate
        enabled: row.kind === "dir"
        keys: ["text/uri-list"]
        onEntered: (drag) => {
            if (row.selected && drag.source === row.pane.dragSource) {
                drag.accepted = false;
                return ;
            }
            row.dropping = true;
            spring.restart();
        }
        onExited: {
            row.dropping = false;
            spring.stop();
        }
        onDropped: (drop) => {
            row.dropping = false;
            spring.stop();
            row.pane.dropInto(row.path, drop);
        }
    }

    Timer {
        id: spring

        interval: 900
        onTriggered: {
            if (row.dropping)
                row.tab.go(row.path);

        }
    }

}
