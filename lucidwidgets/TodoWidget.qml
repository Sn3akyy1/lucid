import QtQuick
import qs
import qs.lucidui

WidgetBody {
    id: w

    readonly property bool focusOnly: w.variant === "focus"
    readonly property bool hideDone: w.focusOnly || w.opt("hideDone") === true
    readonly property var items: {
        try {
            var raw = w.opt("items");
            var parsed = JSON.parse(raw === undefined ? "[]" : String(raw));
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }
    // carries each row's index in the unfiltered list, so a duplicate title
    // cannot toggle its twin
    readonly property var shown: {
        var out = [];
        for (var i = 0; i < w.items.length; i++) {
            if (w.hideDone && w.items[i].d)
                continue;

            out.push({
                "t": w.items[i].t,
                "d": w.items[i].d,
                "at": i
            });
        }
        return out;
    }
    readonly property int doneCount: w.items.filter((it) => {
        return it.d;
    }).length
    readonly property var nextUp: {
        for (var i = 0; i < w.items.length; i++) {
            if (!w.items[i].d)
                return {
                "t": w.items[i].t,
                "at": i
            };

        }
        return null;
    }
    readonly property int openCount: w.items.length - w.doneCount

    function write(next) {
        w.setOpt("items", JSON.stringify(next));
    }

    function addItem(text) {
        var t = text.trim();
        if (t === "")
            return ;

        w.write(w.items.concat([{
            "t": t,
            "d": false
        }]));
    }

    function toggleAt(at) {
        var next = w.items.slice();
        if (at < 0 || at >= next.length)
            return ;

        next[at] = ({
            "t": next[at].t,
            "d": !next[at].d
        });
        w.write(next);
    }

    function removeAt(at) {
        var next = w.items.slice();
        if (at < 0 || at >= next.length)
            return ;

        next.splice(at, 1);
        w.write(next);
    }

    // push the first open item to the back of the list
    function later(at) {
        var next = w.items.slice();
        if (at < 0 || at >= next.length)
            return ;

        var it = next.splice(at, 1)[0];
        next.push(it);
        w.write(next);
    }

    function clearDone() {
        w.write(w.items.filter((it) => {
            return !it.d;
        }));
    }

    onEditingChanged: {
        if (w.editing)
            adder.forceActiveFocus();
        else if (adder.activeFocus)
            adder.focus = false;
    }

    // an m3 checkbox: a rounded square that fills and ticks
    component Check: Item {
        id: ck

        property bool on: false

        signal toggled()

        width: 40
        height: 40

        Rectangle {
            anchors.centerIn: parent
            width: 20
            height: 20
            radius: 6
            color: ck.on ? w.inkAccent : "transparent"
            border.width: ck.on ? 0 : 2
            border.color: w.inkDim
            scale: ckTap.pressed ? 0.86 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

            Icon {
                anchors.centerIn: parent
                name: "check"
                size: 16
                weight: 700
                color: w.fgInkAccent
                opacity: ck.on ? 1 : 0
                scale: ck.on ? 1 : 0.4

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durDefaultEffects
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

            }

        }

        StateLayer {
            id: ckTap

            radius: 20
            tint: w.inkAccent
            onClicked: ck.toggled()
        }

    }

    Item {
        id: head

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 18
        anchors.rightMargin: 12
        anchors.topMargin: 12
        height: 36

        Item {
            id: headRing

            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28

            CircularProgress {
                anchors.fill: parent
                thickness: 3.5
                value: w.items.length ? w.doneCount / w.items.length : 0
                color: w.inkAccent
                trackColor: Theme.alpha(w.ink, 0.12)
            }

            Icon {
                anchors.centerIn: parent
                name: w.focusOnly ? "flag" : "checklist"
                size: 15
                fill: 1
                color: w.inkAccent
            }

        }

        Column {
            anchors.left: headRing.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: -3

            LText {
                role: "titleMedium"
                weight: 620
                color: w.ink
                text: w.focusOnly ? "Up next" : "To-do"
            }

            LText {
                visible: w.items.length > 0
                role: "labelSmall"
                color: w.inkDim
                text: w.focusOnly ? (w.openCount === 0 ? "all done" : w.openCount + " left") : w.doneCount + " of " + w.items.length + " done"
            }

        }

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: w.hovered && w.doneCount > 0 && !w.focusOnly
            variant: "text"
            size: "xs"
            icon: "done_all"
            text: "Clear"
            contentOverride: w.inkAccent
            onClicked: w.clearDone()
        }

    }

    // list: grouped rows, a checkbox each, the adder underneath
    Flickable {
        id: list

        visible: !w.focusOnly
        anchors.top: head.bottom
        anchors.topMargin: 8
        anchors.bottom: addBox.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: rows

            width: list.width
            spacing: 2

            Repeater {
                model: w.shown

                Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool hot: rowHover.hovered

                    width: rows.width
                    height: 44
                    topLeftRadius: row.index === 0 ? 16 : 4
                    topRightRadius: row.index === 0 ? 16 : 4
                    bottomLeftRadius: row.index === w.shown.length - 1 ? 16 : 4
                    bottomRightRadius: row.index === w.shown.length - 1 ? 16 : 4
                    color: Theme.alpha(w.ink, row.hot ? 0.1 : 0.06)

                    HoverHandler {
                        id: rowHover
                    }

                    Check {
                        id: rowCheck

                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        on: row.modelData.d
                        onToggled: w.toggleAt(row.modelData.at)
                    }

                    LText {
                        anchors.left: rowCheck.right
                        anchors.leftMargin: 2
                        anchors.right: rowDel.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyMedium"
                        color: row.modelData.d ? w.inkFaint : w.ink
                        font.strikeout: row.modelData.d
                        text: row.modelData.t
                        elide: Text.ElideRight
                    }

                    IconButton {
                        id: rowDel

                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: row.hot ? 1 : 0
                        size: "xs"
                        icon: "close"
                        tintOverride: w.inkDim
                        onClicked: w.removeAt(row.modelData.at)
                    }

                }

            }

        }

        Column {
            visible: w.shown.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, (list.height - height) / 2)
            spacing: 6

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: w.items.length ? "task_alt" : "edit_note"
                size: 30
                color: w.inkFaint
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "bodyMedium"
                color: w.inkDim
                text: w.items.length ? "Everything's done" : "Nothing on the list"
            }

        }

    }

    // focus: the next thing, big, with done and later
    Item {
        visible: w.focusOnly
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: addBox.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18
        anchors.rightMargin: 18

        LText {
            id: bigTask

            width: parent.width
            anchors.top: parent.top
            anchors.bottom: focusBtns.top
            anchors.bottomMargin: 6
            role: "headlineSmall"
            weight: 560
            color: w.nextUp ? w.ink : w.inkDim
            text: w.nextUp ? w.nextUp.t : (w.items.length ? "All clear." : "Add the one thing that matters next.")
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.VerticalFit
            minimumPixelSize: 14
        }

        Row {
            id: focusBtns

            visible: w.nextUp !== null
            anchors.bottom: parent.bottom
            spacing: 8

            Button {
                variant: "filled"
                size: "xs"
                icon: "check"
                text: "Done"
                containerOverride: w.inkAccent
                contentOverride: w.fgInkAccent
                onClicked: w.toggleAt(w.nextUp.at)
            }

            Button {
                visible: w.openCount > 1
                variant: "tonal"
                size: "xs"
                icon: "schedule"
                text: "Later"
                containerOverride: Theme.alpha(w.ink, 0.1)
                contentOverride: w.ink
                onClicked: w.later(w.nextUp.at)
            }

        }

    }

    // the adder: a pill field that takes keys only once clicked
    Rectangle {
        id: addBox

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        height: 44
        radius: 22
        color: w.editing ? Theme.alpha(w.inkAccent, 0.14) : Theme.alpha(w.ink, 0.06)
        border.width: w.editing ? 2 : 0
        border.color: w.inkAccent

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: {
                w.beginEdit();
                adder.forceActiveFocus();
            }
        }

        Icon {
            id: addMark

            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: "add"
            size: 20
            color: w.editing ? w.inkAccent : w.inkDim
        }

        TextInput {
            id: adder

            anchors.left: addMark.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: w.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.variableAxes: Theme.axes(Theme.typeSize("bodyMedium"), 420, 0)
            selectByMouse: true
            selectionColor: w.inkAccent
            selectedTextColor: w.fgInkAccent
            clip: true
            onActiveFocusChanged: {
                if (adder.activeFocus)
                    w.beginEdit();

            }
            onAccepted: {
                w.addItem(adder.text);
                adder.text = "";
            }
            Keys.onEscapePressed: {
                adder.text = "";
                w.endEdit();
            }
        }

        LText {
            anchors.left: addMark.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            role: "bodyMedium"
            color: w.inkFaint
            text: w.editing ? "Type, then Enter" : "Add a task"
            visible: adder.text === ""
        }

    }

}
