import QtQuick
import QtQuick.Window
import qs

// the crop over the whole frame: the rest dimmed, thirds while it moves, a
// handle at each corner and edge. the crop is kept as fractions of the frame,
// so it holds through a turn and at any zoom
Item {
    id: tool

    required property var win
    required property var stage
    property bool active: false
    readonly property rect frame: tool.stage.picRect
    readonly property var c: tool.win.edits.crop || ({
        "x": 0,
        "y": 0,
        "w": 1,
        "h": 1
    })
    readonly property real fw: tool.stage.current ? tool.stage.current.frameW : 1
    readonly property real fh: tool.stage.current ? tool.stage.current.frameH : 1
    // the crop on screen
    readonly property rect box: Qt.rect(tool.frame.x + tool.c.x * tool.frame.width, tool.frame.y + tool.c.y * tool.frame.height, tool.c.w * tool.frame.width, tool.c.h * tool.frame.height)
    // the shape it keeps, as width over height in pixels; 0 when free
    readonly property real ratio: {
        var r = tool.win.app.prefs.cropRatio, k = 0;
        if (r === "original")
            k = tool.fw / Math.max(1, tool.fh);
        else if (r === "screen")
            k = Screen.width / Math.max(1, Screen.height);
        else if (r.indexOf(":") > 0)
            k = Number(r.split(":")[0]) / Number(r.split(":")[1]);
        if (k > 0 && r !== "1:1" && tool.win.cropPortrait !== (k < 1))
            k = 1 / k;

        return k;
    }
    property bool dragging: false
    property bool keepShape: false
    property var _start: null
    property point _from

    // the biggest crop of a shape that fits the frame, round the crop's middle
    function conform() {
        if (!tool.active || tool.ratio <= 0)
            return ;

        var k = tool.ratio * tool.fh / tool.fw;
        var w = 1, h = 1 / k;
        if (h > 1) {
            h = 1;
            w = k;
        }
        var cx = tool.c.x + tool.c.w / 2, cy = tool.c.y + tool.c.h / 2;
        var x = Math.max(0, Math.min(1 - w, cx - w / 2)), y = Math.max(0, Math.min(1 - h, cy - h / 2));
        tool.put({
            "x": x,
            "y": y,
            "w": w,
            "h": h
        }, false);
    }

    function put(r, live) {
        var whole = r.x < 0.0005 && r.y < 0.0005 && r.w > 0.9995 && r.h > 0.9995;
        var v = whole ? null : {
            "x": r.x,
            "y": r.y,
            "w": r.w,
            "h": r.h
        };
        if (live) {
            tool.win.live({
                "crop": v
            });
        } else {
            tool.win.live({
                "crop": v
            });
            tool.win.settled();
        }
    }

    function begin(mx, my) {
        tool._start = {
            "x": tool.c.x,
            "y": tool.c.y,
            "w": tool.c.w,
            "h": tool.c.h
        };
        tool._from = Qt.point(mx, my);
        tool.dragging = true;
    }

    // a handle dragged: which edges it holds, as -1, 0 or 1 across and down
    function drag(hx, hy, mx, my, shift) {
        var s = tool._start;
        if (!s)
            return ;

        var dx = (mx - tool._from.x) / Math.max(1, tool.frame.width), dy = (my - tool._from.y) / Math.max(1, tool.frame.height);
        var minW = Math.max(Theme.dp(40) / Math.max(1, tool.frame.width), 16 / tool.fw), minH = Math.max(Theme.dp(40) / Math.max(1, tool.frame.height), 16 / tool.fh);
        var x0 = s.x, y0 = s.y, x1 = s.x + s.w, y1 = s.y + s.h;
        if (hx === 0 && hy === 0) {
            var nx = Math.max(0, Math.min(1 - s.w, s.x + dx)), ny = Math.max(0, Math.min(1 - s.h, s.y + dy));
            tool.put({
                "x": nx,
                "y": ny,
                "w": s.w,
                "h": s.h
            }, true);
            return ;
        }
        if (hx < 0)
            x0 = Math.max(0, Math.min(x1 - minW, s.x + dx));

        if (hx > 0)
            x1 = Math.min(1, Math.max(x0 + minW, s.x + s.w + dx));

        if (hy < 0)
            y0 = Math.max(0, Math.min(y1 - minH, s.y + dy));

        if (hy > 0)
            y1 = Math.min(1, Math.max(y0 + minH, s.y + s.h + dy));

        var r = tool.ratio > 0 ? tool.ratio : (shift ? (s.w * tool.fw) / (s.h * tool.fh) : 0);
        if (r > 0) {
            // k turns a width in frame fractions into the height that keeps the shape
            var k = tool.fw / (r * tool.fh);
            var w = x1 - x0, h = y1 - y0;
            if (hx !== 0 && hy !== 0) {
                // a corner: whichever way it went further leads
                if (Math.abs(dx) * tool.frame.width >= Math.abs(dy) * tool.frame.height)
                    h = w * k;
                else
                    w = h / k;
                var ax = hx < 0 ? s.x + s.w : s.x, ay = hy < 0 ? s.y + s.h : s.y;
                var roomW = hx < 0 ? ax : 1 - ax, roomH = hy < 0 ? ay : 1 - ay;
                if (w > roomW) {
                    w = roomW;
                    h = w * k;
                }
                if (h > roomH) {
                    h = roomH;
                    w = h / k;
                }
                x0 = hx < 0 ? ax - w : ax;
                y0 = hy < 0 ? ay - h : ay;
            } else if (hx !== 0) {
                // a side edge: the height follows, about the middle
                h = w * k;
                var cy = s.y + s.h / 2;
                var maxH = 2 * Math.min(cy, 1 - cy);
                if (h > maxH) {
                    h = maxH;
                    w = h / k;
                    if (hx < 0)
                        x0 = x1 - w;

                }
                y0 = cy - h / 2;
                if (hx > 0)
                    x0 = s.x;

            } else {
                w = h / k;
                var cx = s.x + s.w / 2;
                var maxW = 2 * Math.min(cx, 1 - cx);
                if (w > maxW) {
                    w = maxW;
                    h = w * k;
                    if (hy < 0)
                        y0 = y1 - h;

                }
                x0 = cx - w / 2;
                if (hy > 0)
                    y0 = s.y;

            }
            tool.put({
                "x": x0,
                "y": y0,
                "w": w,
                "h": h
            }, true);
            return ;
        }
        tool.put({
            "x": x0,
            "y": y0,
            "w": x1 - x0,
            "h": y1 - y0
        }, true);
    }

    function end() {
        tool.dragging = false;
        tool._start = null;
        tool.win.settled();
    }

    onRatioChanged: Qt.callLater(tool.conform)
    onActiveChanged: {
        if (tool.active)
            Qt.callLater(tool.conform);

    }
    visible: opacity > 0.01
    opacity: tool.active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    // the rest of the frame, dimmed
    Rectangle {
        x: 0
        y: 0
        width: tool.width
        height: Math.max(0, tool.box.y)
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Rectangle {
        x: 0
        y: tool.box.y + tool.box.height
        width: tool.width
        height: Math.max(0, tool.height - y)
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Rectangle {
        x: 0
        y: tool.box.y
        width: Math.max(0, tool.box.x)
        height: tool.box.height
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Rectangle {
        x: tool.box.x + tool.box.width
        y: tool.box.y
        width: Math.max(0, tool.width - x)
        height: tool.box.height
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Item {
        id: boxItem

        x: tool.box.x
        y: tool.box.y
        width: tool.box.width
        height: tool.box.height

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Theme.dp(1)
            border.color: Qt.rgba(1, 1, 1, 0.9)
        }

        // thirds while it moves, or a finer grid while straightening
        Repeater {
            model: tool.win.straightening ? 7 : 2

            delegate: Item {
                required property int index
                readonly property real f: (index + 1) / (tool.win.straightening ? 8 : 3)

                anchors.fill: parent
                opacity: tool.dragging || tool.win.straightening ? 1 : 0

                Rectangle {
                    x: Math.round(parent.width * parent.f)
                    width: 1
                    height: parent.height
                    color: Qt.rgba(1, 1, 1, 0.45)
                }

                Rectangle {
                    y: Math.round(parent.height * parent.f)
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.45)
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

        }

        // the move: anywhere inside
        MouseArea {
            anchors.fill: parent
            anchors.margins: Theme.dp(20)
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: (mouse) => {
                var p = mapToItem(tool, mouse.x, mouse.y);
                tool.begin(p.x, p.y);
            }
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return ;

                var p = mapToItem(tool, mouse.x, mouse.y);
                tool.drag(0, 0, p.x, p.y, false);
            }
            onReleased: tool.end()
            onDoubleClicked: tool.win.tab = "adjust"

            HeldPointer {
                held: parent.pressed
                cursor: parent.cursorShape
            }

        }

        Repeater {
            // corners and edges, as which way each holds the crop
            model: [[-1, -1], [1, -1], [-1, 1], [1, 1], [0, -1], [0, 1], [-1, 0], [1, 0]]

            delegate: Item {
                id: handle

                required property var modelData
                readonly property int hx: handle.modelData[0]
                readonly property int hy: handle.modelData[1]
                readonly property bool corner: handle.hx !== 0 && handle.hy !== 0
                readonly property real reach: Theme.dp(44)
                readonly property real len: Theme.dp(22)
                readonly property real thick: Theme.dp(4)
                // an edge takes the whole of its side between the corners
                readonly property real along: handle.corner ? handle.reach : Math.max(0, (handle.hx === 0 ? boxItem.width : boxItem.height) - handle.reach)

                x: handle.hx === 0 ? (boxItem.width - handle.along) / 2 : (handle.hx < 0 ? 0 : boxItem.width) - handle.reach / 2
                y: handle.hy === 0 ? (boxItem.height - handle.along) / 2 : (handle.hy < 0 ? 0 : boxItem.height) - handle.reach / 2
                width: handle.hx === 0 ? handle.along : handle.reach
                height: handle.hy === 0 ? handle.along : handle.reach

                // an l for a corner, a bar for an edge (gone on a small crop)
                Rectangle {
                    visible: handle.corner
                    x: handle.reach / 2 - (handle.hx < 0 ? handle.thick / 2 : handle.len - handle.thick / 2)
                    y: handle.reach / 2 - handle.thick / 2
                    width: handle.len
                    height: handle.thick
                    radius: handle.thick / 2
                    color: "white"
                }

                Rectangle {
                    visible: handle.corner
                    x: handle.reach / 2 - handle.thick / 2
                    y: handle.reach / 2 - (handle.hy < 0 ? handle.thick / 2 : handle.len - handle.thick / 2)
                    width: handle.thick
                    height: handle.len
                    radius: handle.thick / 2
                    color: "white"
                }

                Rectangle {
                    visible: !handle.corner && handle.along > Theme.dp(60)
                    anchors.centerIn: parent
                    width: handle.hx === 0 ? Theme.dp(30) : handle.thick
                    height: handle.hx === 0 ? handle.thick : Theme.dp(30)
                    radius: handle.thick / 2
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: handle.corner ? (handle.hx === handle.hy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : (handle.hx === 0 ? Qt.SizeVerCursor : Qt.SizeHorCursor)
                    preventStealing: true
                    onPressed: (mouse) => {
                        var p = mapToItem(tool, mouse.x, mouse.y);
                        tool.begin(p.x, p.y);
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed)
                            return ;

                        var p = mapToItem(tool, mouse.x, mouse.y);
                        tool.drag(handle.hx, handle.hy, p.x, p.y, (mouse.modifiers & Qt.ShiftModifier) !== 0);
                    }
                    onReleased: tool.end()

                    HeldPointer {
                        held: parent.pressed
                        cursor: parent.cursorShape
                    }

                }

            }

        }

    }

}
