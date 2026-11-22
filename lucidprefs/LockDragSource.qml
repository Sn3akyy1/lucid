import QtQuick
import qs

// a press on something in the lock editor's side panel that names a widget:
// a click is a click, and a drag carries the widget out over the preview,
// where it can be let go into any slot
MouseArea {
    id: ds

    property string type: ""
    property var editor: null
    property point press: Qt.point(0, 0)
    property bool carrying: false
    // a press that turned into a drag is not a click
    property bool travelled: false

    signal tapped()

    hoverEnabled: true
    // the panel scrolls; a drag here is for the widget, not the list
    preventStealing: true
    cursorShape: ds.carrying ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    onPressed: (mouse) => {
        ds.press = Qt.point(mouse.x, mouse.y);
        ds.carrying = false;
        ds.travelled = false;
    }
    onPositionChanged: (mouse) => {
        if (!ds.pressed || !ds.editor)
            return ;

        var q = ds.mapToItem(ds.editor, mouse.x, mouse.y);
        if (!ds.carrying) {
            var o = ds.mapToItem(ds.editor, ds.press.x, ds.press.y);
            if (Math.hypot(q.x - o.x, q.y - o.y) < Theme.dp(6))
                return ;

            ds.carrying = true;
            ds.travelled = true;
            ds.editor.beginOutside(ds.type, q);
        }
        ds.editor.moveOutside(q);
    }
    // a drop reshapes the list this sits in, so it is made once the release
    // is over, from locals
    onReleased: (mouse) => {
        if (ds.carrying) {
            ds.carrying = false;
            var ed = ds.editor;
            var at = ds.mapToItem(ed, mouse.x, mouse.y);
            Qt.callLater(() => {
                return ed.endOutside(at);
            });
        }
    }
    onCanceled: {
        if (ds.carrying) {
            ds.carrying = false;
            ds.editor.cancelOutside();
        }
    }
    onClicked: {
        if (!ds.travelled)
            ds.tapped();

    }
}
