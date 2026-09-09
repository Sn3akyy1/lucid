import QtQuick
import qs

Rectangle {
    id: rail

    // the start node plus whatever steps are turned on
    readonly property var nodes: [{
        "name": "You stop typing",
        "time": "",
        "start": true
    }].concat(Idle.stages.map((s) => {
        return {
            "name": s.name,
            "time": Idle.durationText(s.after),
            "start": false
        };
    }))
    readonly property bool empty: Idle.stages.length === 0
    readonly property string note: {
        if (rail.empty)
            return "Nothing happens when you walk away. Turn a step on below.";

        if (!Prefs.idleEnabled)
            return "Idle management is off, so none of this runs.";

        if (Idle.paused)
            return "Paused. This machine will not dim, lock or sleep on its own.";

        return "";
    }

    implicitHeight: 36 + (rail.empty ? 0 : block.height) + (rail.note !== "" ? noteText.implicitHeight + (rail.empty ? 0 : 12) : 0)
    radius: Theme.radiusMd
    color: Theme.bgSunken
    clip: true

    Item {
        id: block

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 18
        height: 76
        visible: !rail.empty
        opacity: rail.note !== "" ? 0.4 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Rectangle {
            id: line

            readonly property real inset: rail.nodes.length > 0 ? parent.width / rail.nodes.length / 2 : 0

            x: line.inset
            width: Math.max(0, parent.width - line.inset * 2)
            y: 4
            height: 2
            radius: 1
            color: Theme.alpha(Theme.outline, 0.8)
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: rail.nodes

                Item {
                    id: node

                    required property var modelData

                    width: rail.nodes.length > 0 ? parent.width / rail.nodes.length : 0
                    height: parent.height

                    Rectangle {
                        width: node.modelData.start ? 9 : 11
                        height: width
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 5 - height / 2
                        color: node.modelData.start ? Theme.bgSunken : Theme.accent
                        border.width: node.modelData.start ? 2 : 0
                        border.color: Theme.subtextDim
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 22
                        width: parent.width - 8
                        spacing: 3

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: node.modelData.name
                            color: node.modelData.start ? Theme.subtextDim : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.bold: !node.modelData.start
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: node.modelData.time
                            color: Theme.accentMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            visible: node.modelData.time !== ""
                        }

                    }

                }

            }

        }

    }

    Text {
        id: noteText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.top: rail.empty ? parent.top : block.bottom
        anchors.topMargin: rail.empty ? 18 : 12
        horizontalAlignment: Text.AlignHCenter
        text: rail.note
        visible: rail.note !== ""
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        wrapMode: Text.WordWrap
    }

}
