import QtQuick
import qs
import qs.lucidui

// one item in the grid: its picture over a two-line name, on a plate that lights
// when selected. presses select, a drag carries the selection out as uris, and a
// folder takes drops (and opens itself if one hovers long enough)
Item {
    id: cell

    required property int index
    required property string name
    required property string label
    required property string uri
    required property string path
    required property string kind
    required property string slot
    required property string icon
    required property string thumb
    required property bool hidden
    required property bool link
    readonly property var pane: GridView.view ? GridView.view.pane : null
    readonly property var tab: cell.pane ? cell.pane.tab : null
    readonly property bool selected: cell.tab !== null && cell.tab.rev >= 0 && cell.tab.isSelected(cell.uri)
    readonly property bool isCurrent: cell.tab !== null && cell.tab.current === cell.index && cell.pane.keyboardFocus
    readonly property real iconSize: cell.pane ? cell.pane.iconSize : Theme.dp(64)
    property bool dropping: false
    property url dragImage

    width: GridView.view ? GridView.view.cellWidth : Theme.dp(120)
    height: GridView.view ? GridView.view.cellHeight : Theme.dp(120)
    // what the view's transitions animate as an item comes and goes
    property real enter: 1
    property real pop: 1
    // where the view last put it, and for which index
    property real lastX: 0
    property real lastY: 0
    property int lastIndex: -1
    property bool placed: false

    // the view's add transition hands its arrival here, n beats late
    function arrive(n) {
        cell.enter = 0;
        cell.pop = 0.86;
        wait.duration = n * Math.round(16 * Theme.motionScale);
        arrival.restart();
    }

    // a new index glides there; a resize lands at once
    function moved() {
        var dx = cell.lastX - cell.x, dy = cell.lastY - cell.y;
        // setPosition moves both before either signal: the second sees nothing new
        if (dx === 0 && dy === 0)
            return ;

        var glide = cell.placed && cell.index !== cell.lastIndex && Theme.motionScale > 0;
        cell.lastX = cell.x;
        cell.lastY = cell.y;
        cell.lastIndex = cell.index;
        cell.placed = true;
        if (!glide) {
            slideAnim.stop();
            slide.x = 0;
            slide.y = 0;
            return ;
        }
        slide.x += dx;
        slide.y += dy;
        slideAnim.restart();
    }

    onXChanged: cell.moved()
    onYChanged: cell.moved()
    Component.onCompleted: {
        cell.lastIndex = cell.index;
        // buffer cells and ones a growing window reveals get no add transition
        if (cell.pane && cell.pane.cascading)
            cell.arrive(cell.pane.beatsFor(cell.index));

        Qt.callLater(function() {
            cell.placed = true;
        });
    }
    transform: Translate {
        id: slide
    }

    opacity: (cell.hidden ? 0.62 : 1) * (cell.pane && cell.pane.isCut(cell.uri) ? 0.5 : 1) * cell.enter
    scale: cell.pop
    // a delegate taken back from the pool starts whole, whatever it left as
    GridView.onReused: {
        cell.enter = 1;
        cell.pop = 1;
    }

    Rectangle {
        id: plate

        anchors.fill: parent
        anchors.margins: Theme.dp(4)
        radius: Theme.dp(18)
        color: cell.dropping ? Theme.alpha(Theme.accent, 0.22) : cell.selected ? Theme.accentContainer : "transparent"
        border.width: cell.isCurrent && !cell.selected ? Theme.dp(2) : 0
        border.color: Theme.alpha(Theme.accent, 0.6)
        // picked, the plate springs up to size; let go, it settles back as it fades
        scale: cell.selected || cell.dropping ? 1 : 0.92

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

        HoverLayer {
            area: area
            tint: cell.selected ? Theme.fgAccentContainer : Theme.text
        }

    }

    FileGlyph {
        id: glyph

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.dp(10)
        size: cell.iconSize
        slot: cell.slot
        icon: cell.icon
        thumb: cell.thumb
        kind: cell.kind
        legacy: cell.pane ? cell.pane.legacy : false
        hovered: area.containsMouse || cell.dropping
        scale: area.pressed && !cell.pane.dragging ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    Icon {
        visible: cell.link
        anchors.right: glyph.right
        anchors.bottom: glyph.bottom
        name: "link"
        size: Math.max(Theme.dp(14), cell.iconSize * 0.26)
        color: Theme.text
        animateColor: false
    }

    LText {
        anchors.top: glyph.bottom
        anchors.topMargin: Theme.dp(6)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.dp(10)
        anchors.rightMargin: Theme.dp(10)
        role: "bodySmall"
        text: cell.label
        color: cell.selected ? Theme.fgAccentContainer : Theme.text
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        maximumLineCount: 2
        elide: Text.ElideRight
    }

    MouseArea {
        id: area

        anchors.fill: plate
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        // past a few pixels with the button down, the pane carries the drag
        property point pressAt

        onPositionChanged: (mouse) => {
            if (!area.pressed || !(mouse.buttons & Qt.LeftButton) || cell.pane.dragging)
                return ;

            if (Math.abs(mouse.x - area.pressAt.x) + Math.abs(mouse.y - area.pressAt.y) < Theme.dp(8))
                return ;

            cell.pane.startDrag(cell.pane.dragUris(cell.uri), cell.dragImage);
        }
        onPressed: (mouse) => {
            area.pressAt = Qt.point(mouse.x, mouse.y);
            cell.pane.takeFocus();
            if (mouse.button === Qt.LeftButton) {
                if (!cell.selected && !(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)))
                    cell.tab.selectOnly(cell.index);

                glyph.grabToImage(function(r) {
                    cell.dragImage = r.url;
                });
            }
        }
        onClicked: (mouse) => {
            return cell.pane.itemClicked(cell.index, mouse, area);
        }
        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                cell.pane.itemActivated(cell.index, false);

        }
    }

    DropArea {
        anchors.fill: plate
        enabled: cell.kind === "dir"
        keys: ["text/uri-list"]
        onEntered: (drag) => {
            if (cell.selected && drag.source === cell.pane.dragSource) {
                drag.accepted = false;
                return ;
            }
            cell.dropping = true;
            spring.restart();
        }
        onExited: {
            cell.dropping = false;
            spring.stop();
        }
        onDropped: (drop) => {
            cell.dropping = false;
            spring.stop();
            cell.pane.dropInto(cell.path, drop);
        }
    }

    // a folder held under a drag opens, so it can go deeper
    Timer {
        id: spring

        interval: 900
        onTriggered: {
            if (cell.dropping)
                cell.tab.go(cell.path);

        }
    }

    ParallelAnimation {
        id: slideAnim

        NumberAnimation {
            target: slide
            property: "x"
            to: 0
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

        NumberAnimation {
            target: slide
            property: "y"
            to: 0
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    SequentialAnimation {
        id: arrival

        PauseAnimation {
            id: wait
        }

        ParallelAnimation {
            NumberAnimation {
                target: cell
                property: "enter"
                to: 1
                duration: Theme.durShort
            }

            NumberAnimation {
                target: cell
                property: "pop"
                to: 1
                duration: Theme.durFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

}
