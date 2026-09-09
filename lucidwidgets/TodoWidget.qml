import QtQuick
import qs

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

    Item {
        id: head

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 18
        anchors.rightMargin: 14
        anchors.topMargin: 15
        height: 22

        Text {
            id: headTitle

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: w.focusOnly ? "UP NEXT" : "TO-DO"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.4
        }

        Text {
            anchors.left: headTitle.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: w.items.length === 0 ? "" : (w.focusOnly ? w.shown.length + " left" : w.doneCount + " of " + w.items.length + " done")
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
        }

        WidgetButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "trash"
            diameter: 24
            iconSize: 13
            visible: w.hovered && w.doneCount > 0 && !w.focusOnly
            onClicked: w.clearDone()
        }

    }

    Flickable {
        id: scroller

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: addRow.top
        anchors.topMargin: 6
        contentWidth: width
        contentHeight: list.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: list

            width: scroller.width

            Repeater {
                model: w.shown

                Item {
                    id: row

                    required property var modelData

                    width: list.width
                    height: 32

                    HoverHandler {
                        id: rowHover
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        radius: Theme.radiusXs
                        color: rowHover.hovered ? Theme.alpha(Theme.text, 0.05) : "transparent"
                    }

                    Tick {
                        id: rowTick

                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        done: row.modelData.d === true
                        onToggled: w.toggleAt(row.modelData.at)
                    }

                    Text {
                        anchors.left: rowTick.right
                        anchors.leftMargin: 11
                        anchors.right: rowKill.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.t
                        color: row.modelData.d ? Theme.subtextDim : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: w.focusOnly ? 14 : 13
                        font.strikeout: row.modelData.d === true
                        elide: Text.ElideRight
                    }

                    WidgetButton {
                        id: rowKill

                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        diameter: 22
                        iconSize: 12
                        opacity: rowHover.hovered ? 1 : 0
                        visible: opacity > 0.01
                        onClicked: w.removeAt(row.modelData.at)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        anchors.rightMargin: 34
                        anchors.leftMargin: 40
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: w.toggleAt(row.modelData.at)
                    }

                }

            }

        }

    }

    Text {
        anchors.centerIn: scroller
        width: scroller.width - 40
        text: w.items.length === 0 ? "Nothing on the list yet." : "All done."
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        visible: w.shown.length === 0
    }

    Item {
        id: addRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.rightMargin: 14
        anchors.bottomMargin: 12
        height: 32

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -4
            radius: height / 2
            color: w.editing ? Theme.alpha(Theme.accent, 0.1) : (addArea.containsMouse ? Theme.alpha(Theme.text, 0.05) : "transparent")

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        MouseArea {
            id: addArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            onClicked: {
                w.beginEdit();
                adder.forceActiveFocus();
            }
        }

        WidgetGlyph {
            id: addMark

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: "add"
            size: 17
            color: w.editing ? Theme.accent : Theme.subtextDim
        }

        TextInput {
            id: adder

            anchors.left: addMark.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.fgAccent
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

        Text {
            anchors.left: addMark.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "Add an item"
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 13
            visible: adder.text === "" && !w.editing
        }

    }

    component Tick: Item {
        id: tick

        property bool done: false

        signal toggled()

        implicitWidth: 20
        implicitHeight: 20

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: tick.done ? Theme.accent : "transparent"
            border.width: tick.done ? 0 : 1.8
            border.color: tickArea.containsMouse ? Theme.accent : Theme.alpha(Theme.text, 0.35)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        WidgetGlyph {
            anchors.centerIn: parent
            name: "check"
            size: 13
            color: Theme.fgAccent
            opacity: tick.done ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        MouseArea {
            id: tickArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tick.toggled()
        }

    }

}
