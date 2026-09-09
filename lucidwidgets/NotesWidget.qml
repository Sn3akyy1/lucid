import QtQuick
import qs

WidgetBody {
    id: w

    readonly property string tint: {
        var v = w.opt("tint");
        return v === undefined ? "neutral" : String(v);
    }
    readonly property color paper: {
        if (w.tint === "accent")
            return Theme.accentContainer;

        if (w.tint === "tertiary")
            return Theme.tertiaryContainer;

        return "transparent";
    }
    readonly property color ink: {
        if (w.tint === "accent")
            return Theme.fgAccentContainer;

        if (w.tint === "tertiary")
            return Theme.fgTertiaryContainer;

        return Theme.text;
    }
    readonly property color faded: Theme.alpha(w.ink, 0.45)
    readonly property bool movable: !w.preview && w.host !== null && !w.host.locked
    readonly property bool hostDragging: !w.preview && w.host !== null && w.host.dragging === true
    readonly property string stored: {
        var v = w.opt("text");
        return v === undefined ? "" : String(v);
    }

    function commit() {
        w.setOpt("text", editor.text);
    }

    onEditingChanged: {
        if (w.editing)
            editor.forceActiveFocus();
        else if (editor.activeFocus)
            editor.focus = false;
    }

    Timer {
        id: saveDelay

        interval: 500
        onTriggered: w.commit()
    }

    Rectangle {
        anchors.fill: parent
        radius: w.corner
        color: w.paper
        visible: w.tint !== "neutral"
    }

    // faint rules behind the text, drawn on the editor's own line grid
    Item {
        id: rules

        anchors.fill: parent
        anchors.margins: 18
        anchors.topMargin: 44
        clip: true
        visible: w.variant === "lined"

        Repeater {
            model: Math.max(0, Math.floor(rules.height / Math.max(1, metrics.height)))

            Rectangle {
                required property int index

                width: rules.width
                height: 1
                y: (index + 1) * metrics.height - 1
                color: Theme.alpha(w.ink, 0.12)
            }

        }

    }

    FontMetrics {
        id: metrics

        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    Text {
        id: linedTitle

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 16
        text: "Note"
        color: w.faded
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1.4
        visible: w.variant === "lined"
    }

    // clicks on the margins still land in the text; the editor itself handles its own
    MouseArea {
        anchors.fill: parent
        enabled: w.editing
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.IBeamCursor
        onPressed: {
            w.beginEdit();
            editor.forceActiveFocus();
            editor.cursorPosition = editor.length;
        }
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        anchors.margins: w.variant === "lined" ? 18 : 20
        anchors.topMargin: w.variant === "lined" ? 44 : 20
        contentWidth: width
        contentHeight: editor.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        TextEdit {
            id: editor

            width: scroller.width
            text: w.stored
            color: w.ink
            font.family: Theme.fontFamily
            font.pixelSize: 13
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.fgAccent
            persistentSelection: true
            onTextChanged: {
                if (editor.text !== w.stored)
                    saveDelay.restart();

            }
            onActiveFocusChanged: {
                if (editor.activeFocus) {
                    w.beginEdit();
                } else {
                    saveDelay.stop();
                    w.commit();
                }
            }
            Keys.onEscapePressed: {
                w.commit();
                w.endEdit();
            }

            Connections {
                function onStoredChanged() {
                    if (!editor.activeFocus && editor.text !== w.stored)
                        editor.text = w.stored;

                }

                target: w
            }

        }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: w.variant === "lined" ? "Type here. It stays put across reboots." : "Write something…"
            color: Theme.alpha(w.ink, 0.32)
            font.family: Theme.fontFamily
            font.pixelSize: 13
            visible: editor.text === ""
        }

    }

    // while the note is closed the whole card is a drag surface: a click opens the
    // editor, a press that travels moves the widget. taking focus on press meant a
    // left-drag could never start, since the editor swallowed the gesture
    MouseArea {
        id: grab

        property real pressX: 0
        property real pressY: 0
        property bool moved: false

        function frameXY(x, y) {
            return grab.mapToItem(w.host, x, y);
        }

        anchors.fill: parent
        enabled: !w.editing
        acceptedButtons: Qt.LeftButton
        cursorShape: w.hostDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (mouse) => {
            grab.pressX = mouse.x;
            grab.pressY = mouse.y;
            grab.moved = false;
        }
        onPositionChanged: (mouse) => {
            if (!w.movable)
                return ;

            if (!grab.moved) {
                if (Math.abs(mouse.x - grab.pressX) < 4 && Math.abs(mouse.y - grab.pressY) < 4)
                    return ;

                grab.moved = true;
                const from = grab.frameXY(grab.pressX, grab.pressY);
                w.host.beginDrag(from.x, from.y);
            }
            const at = grab.frameXY(mouse.x, mouse.y);
            w.host.moveDrag(at.x, at.y);
        }
        onReleased: {
            if (grab.moved) {
                w.host.endDrag();
                grab.moved = false;
                return ;
            }
            w.beginEdit();
            editor.forceActiveFocus();
            editor.cursorPosition = editor.length;
        }
        onCanceled: {
            if (grab.moved && w.movable)
                w.host.endDrag();

            grab.moved = false;
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        text: w.editing ? "esc to finish" : ""
        color: Theme.alpha(w.ink, 0.4)
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.bold: true
        visible: w.editing
    }

}
