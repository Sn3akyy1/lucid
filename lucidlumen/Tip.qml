import QtQuick
import QtQuick.Window
import qs

// a tooltip for the control it sits in, in the dock's own style: rest the
// pointer on it and a small label shows under it. the label lives on the
// window's root item, so no parent clips it. text defaults to the control's
// tooltip property, so `Tip {}` inside an IconButton is enough
Item {
    id: tip

    property string text: tip.parent && tip.parent.tooltip !== undefined ? tip.parent.tooltip : ""

    anchors.fill: parent

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered && tip.text !== "") {
                wait.restart();
            } else {
                wait.stop();
                bubble.shown = false;
            }
        }
    }

    // once the control is used the label goes: it would sit over what opened
    Connections {
        function onClicked() {
            wait.stop();
            bubble.shown = false;
        }

        target: tip.parent
        ignoreUnknownSignals: true
    }

    Timer {
        id: wait

        interval: 550
        onTriggered: {
            bubble.place();
            bubble.shown = true;
        }
    }

    Rectangle {
        id: bubble

        property bool shown: false

        // under the control, or over it near the bottom edge; never past a side
        function place() {
            var root = bubble.parent;
            if (!root)
                return ;

            var p = tip.mapToItem(root, tip.width / 2, 0);
            var x = Math.round(p.x - bubble.width / 2);
            bubble.x = Math.max(Theme.dp(6), Math.min(x, root.width - bubble.width - Theme.dp(6)));
            var below = p.y + tip.height + Theme.dp(6);
            bubble.y = below + bubble.height < root.height - Theme.dp(4) ? below : Math.round(p.y - bubble.height - Theme.dp(6));
        }

        parent: tip.Window.window ? tip.Window.window.contentItem : tip
        z: 1000
        width: label.implicitWidth + Theme.dp(20)
        height: label.implicitHeight + Theme.dp(12)
        radius: Theme.radiusXs
        color: Theme.bgHigh
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.08)
        opacity: bubble.shown ? 1 : 0
        scale: bubble.shown ? 1 : 0.92
        visible: opacity > 0.01

        Text {
            id: label

            anchors.centerIn: parent
            text: tip.text
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.variableAxes: Theme.axes(Theme.fontBody, 520, 0)
            font.weight: Font.Medium
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

}
