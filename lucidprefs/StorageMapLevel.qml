import QtQuick
import qs
import qs.lucidui

// the tiles of one folder. the view rect (zx, zy, zw, zh, fractions of the map)
// says where this folder's whole area sits, so the map zooms by moving it
Item {
    id: lvl

    property var node: null
    // { node, x, y, w, h }, fractions of the map
    property var tiles: []
    property var pal: null
    property var selected: null
    property var hovered: null
    property real zx: 0
    property real zy: 0
    property real zw: 1
    property real zh: 1
    property real tx: 0
    property real ty: 0
    property real tw: 1
    property real th: 1
    property real tOpacity: 1
    property int fadeMs: Theme.durShort
    readonly property real gap: Theme.dp(4)

    signal tileClicked(var tile)
    signal tileMenu(var tile)
    signal tileOpened(var tile)

    function place(x, y, w, h, o) {
        glide.stop();
        lvl.zx = x;
        lvl.zy = y;
        lvl.zw = w;
        lvl.zh = h;
        lvl.opacity = o;
    }

    function moveTo(x, y, w, h, o, fade) {
        glide.stop();
        lvl.tx = x;
        lvl.ty = y;
        lvl.tw = w;
        lvl.th = h;
        lvl.tOpacity = o;
        lvl.fadeMs = fade;
        glide.start();
    }

    visible: lvl.opacity > 0.01 && lvl.node !== null

    ParallelAnimation {
        id: glide

        onFinished: {
            if (lvl.opacity < 0.01)
                lvl.node = null;

        }

        NumberAnimation {
            target: lvl
            property: "zx"
            to: lvl.tx
            duration: Theme.durEnter
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: lvl
            property: "zy"
            to: lvl.ty
            duration: Theme.durEnter
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: lvl
            property: "zw"
            to: lvl.tw
            duration: Theme.durEnter
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: lvl
            property: "zh"
            to: lvl.th
            duration: Theme.durEnter
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: lvl
            property: "opacity"
            to: lvl.tOpacity
            duration: lvl.fadeMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveStandard
        }

    }

    Repeater {
        model: lvl.tiles

        Item {
            id: tile

            required property var modelData
            readonly property var n: tile.modelData.node
            readonly property bool other: tile.n.t === 2
            readonly property bool dir: tile.n.t === 1
            // the size this tile settles at, which decides what it can show
            readonly property real restW: tile.modelData.w * lvl.width
            readonly property real restH: tile.modelData.h * lvl.height
            readonly property bool roomy: tile.restW >= Theme.dp(74) && tile.restH >= Theme.dp(48)
            readonly property bool picked: lvl.selected === tile.n
            readonly property color fill: {
                if (!lvl.pal)
                    return Theme.bgHigh;

                if (tile.other || tile.n.u)
                    return Theme.bgHigh;

                return lvl.pal.kindColor(tile.n.k || 0);
            }
            readonly property color ink: {
                if (!lvl.pal || tile.other || tile.n.u)
                    return Theme.subtext;

                return lvl.pal.kindInk(tile.n.k || 0);
            }

            x: (lvl.zx + tile.modelData.x * lvl.zw) * lvl.width
            y: (lvl.zy + tile.modelData.y * lvl.zh) * lvl.height
            width: tile.modelData.w * lvl.zw * lvl.width
            height: tile.modelData.h * lvl.zh * lvl.height

            Rectangle {
                id: face

                anchors.fill: parent
                anchors.margins: lvl.gap / 2
                radius: Math.max(0, Math.min(Theme.dp(12), width / 3, height / 3))
                color: tile.fill
                border.width: tile.picked ? Theme.dp(2) : 0
                border.color: Theme.text

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: tile.ink
                    opacity: area.pressed ? Theme.statePressed * 1.6 : (area.containsMouse ? Theme.stateHover * 1.6 : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            Loader {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.dp(11)
                active: tile.roomy
                opacity: tile.width >= Theme.dp(60) && tile.height >= Theme.dp(40) ? 1 : 0

                sourceComponent: Column {
                    spacing: Theme.dp(2)

                    Row {
                        width: parent.width
                        spacing: Theme.dp(5)

                        Icon {
                            id: mark

                            anchors.verticalCenter: parent.verticalCenter
                            name: tile.other ? "more_horiz" : (tile.n.u ? "lock" : (tile.dir ? "folder" : (lvl.pal ? lvl.pal.kindIcon(tile.n.k || 0) : "category")))
                            size: Theme.dp(15)
                            color: tile.ink
                        }

                        Text {
                            width: parent.width - mark.width - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.other ? (tile.n.o === 1 ? "1 small item" : (tile.n.o || 0).toLocaleString(Qt.locale(), "f", 0) + " small items") : tile.n.n
                            color: tile.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                        }

                    }

                    Text {
                        width: parent.width
                        text: Storage.size(tile.n.s)
                        color: tile.ink
                        opacity: 0.78
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm
                        visible: tile.restH >= Theme.dp(54)
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: tile.dir && !tile.n.u ? Qt.PointingHandCursor : Qt.ArrowCursor
                onContainsMouseChanged: {
                    if (area.containsMouse)
                        lvl.hovered = tile.n;
                    else if (lvl.hovered === tile.n)
                        lvl.hovered = null;
                }
                onClicked: (m) => {
                    if (m.button === Qt.RightButton)
                        lvl.tileMenu(tile.modelData);
                    else
                        lvl.tileClicked(tile.modelData);
                }
                onDoubleClicked: (m) => {
                    if (m.button === Qt.LeftButton)
                        lvl.tileOpened(tile.modelData);

                }
            }

        }

    }

}
