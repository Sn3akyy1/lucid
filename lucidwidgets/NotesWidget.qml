import QtQuick
import qs
import qs.lucidui

WidgetBody {
    id: w

    // the old tint choice still counts until a colour is picked
    readonly property string legacyTint: {
        var v = w.opt("tint");
        return v === undefined ? "" : String(v);
    }
    readonly property bool movable: !w.preview && w.host !== null && !w.host.locked
    readonly property bool hostDragging: !w.preview && w.host !== null && w.host.dragging === true
    readonly property string stored: {
        var v = w.opt("text");
        return v === undefined ? "" : String(v);
    }
    readonly property real edited: Number(w.opt("edited")) || 0
    readonly property int words: {
        var t = editor.text.trim();
        return t === "" ? 0 : t.split(/\s+/).length;
    }
    readonly property bool headline: w.variant === "headline"
    readonly property bool lined: w.variant === "lined"

    function commit() {
        if (editor.text === w.stored)
            return ;

        w.setOpt("text", editor.text);
        w.setOpt("edited", Date.now());
    }

    function ago(ms) {
        if (ms <= 0)
            return "";

        var s = (Date.now() - ms) / 1000;
        if (s < 60)
            return "edited just now";

        if (s < 3600)
            return "edited " + Math.floor(s / 60) + " min ago";

        if (s < 86400)
            return "edited " + Math.floor(s / 3600) + " h ago";

        return "edited " + new Date(ms).toLocaleDateString(Qt.locale(), "d MMM");
    }

    defaultTone: w.legacyTint === "accent" ? "primary" : (w.legacyTint === "tertiary" ? "tertiary" : (w.variant === "sticky" ? "secondary" : (w.headline ? "primary" : "surface")))
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

    // lined: a header with the word count, rules under the text
    Item {
        id: linedHead

        visible: w.lined
        x: 20
        y: 14
        width: parent.width - 40
        height: 26

        Icon {
            id: noteIcon

            anchors.verticalCenter: parent.verticalCenter
            name: "sticky_note_2"
            size: 18
            fill: 1
            color: w.inkAccent
        }

        LText {
            anchors.left: noteIcon.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            role: "titleSmall"
            color: w.ink
            text: "Note"
        }

        LText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            role: "labelSmall"
            color: w.inkFaint
            text: w.words > 0 ? w.words + (w.words === 1 ? " word" : " words") : ""
        }

    }

    Flickable {
        id: scroller

        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: w.lined ? 48 : 20
        anchors.bottomMargin: w.lined ? 30 : 20
        contentWidth: width
        contentHeight: w.headline ? height : editor.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !w.headline && contentHeight > height

        FontMetrics {
            id: fm

            font: editor.font
        }

        // rules sit under each line of text and scroll with it
        Repeater {
            model: w.lined ? Math.ceil(Math.max(scroller.height, editor.implicitHeight) / fm.lineSpacing) : 0

            Rectangle {
                required property int index

                y: (index + 1) * fm.lineSpacing + 1
                width: scroller.width
                height: 1
                color: Theme.alpha(w.ink, 0.1)
            }

        }

        TextEdit {
            id: editor

            // the headline shrinks to fit the card, the others scroll
            readonly property int basePx: w.headline ? 40 : (w.variant === "sticky" ? 17 : 14)
            readonly property int px: w.headline ? fit.px : editor.basePx

            width: scroller.width
            height: w.headline ? scroller.height : implicitHeight
            text: w.stored
            color: w.ink
            font.family: Theme.fontFamily
            font.pixelSize: editor.px
            font.variableAxes: Theme.axes(editor.px, w.headline ? 620 : (w.variant === "sticky" ? 480 : 420), w.lined ? 0 : 100)
            wrapMode: TextEdit.Wrap
            horizontalAlignment: w.headline ? TextEdit.AlignHCenter : TextEdit.AlignLeft
            verticalAlignment: w.headline ? TextEdit.AlignVCenter : TextEdit.AlignTop
            selectByMouse: true
            selectionColor: w.inkAccent
            selectedTextColor: w.fgInkAccent
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

        // steps the headline down until the wrapped text fits the card
        Text {
            id: fit

            property int px: 40

            function measure() {
                if (!w.headline || scroller.width <= 0)
                    return ;

                var t = editor.text === "" ? "M" : editor.text;
                fit.text = t;
                for (var p = 64; p >= 14; p -= 2) {
                    fit.font.pixelSize = p;
                    fit.font.variableAxes = Theme.axes(p, 620, 100);
                    if (fit.implicitHeight <= scroller.height && fit.contentWidth <= scroller.width + 0.5) {
                        fit.px = p;
                        return ;
                    }
                }
                fit.px = 14;
            }

            visible: false
            width: scroller.width
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            Component.onCompleted: Qt.callLater(fit.measure)

            Connections {
                function onTextChanged() {
                    Qt.callLater(fit.measure);
                }

                function onWidthChanged() {
                    Qt.callLater(fit.measure);
                }

                function onHeightChanged() {
                    Qt.callLater(fit.measure);
                }

                target: editor
            }

        }

        LText {
            anchors.fill: parent
            visible: editor.text === ""
            role: w.headline ? "headlineSmall" : "bodyMedium"
            color: Theme.alpha(w.ink, 0.36)
            horizontalAlignment: w.headline ? Text.AlignHCenter : Text.AlignLeft
            verticalAlignment: w.headline ? Text.AlignVCenter : Text.AlignTop
            wrapMode: Text.Wrap
            text: w.headline ? "One line, big" : (w.lined ? "Type here. It stays put across reboots." : "Write something…")
        }

    }

    LText {
        visible: w.lined
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 20
        anchors.bottomMargin: 10
        role: "labelSmall"
        color: w.inkFaint
        text: w.editing ? "Esc to finish" : w.ago(w.edited)
    }

    // while the note is closed the whole card is a drag surface: a click opens the
    // editor, a press that travels moves the widget
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

    LText {
        visible: w.editing && !w.lined
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        role: "labelSmall"
        color: Theme.alpha(w.ink, 0.45)
        text: "Esc to finish"
    }

}
