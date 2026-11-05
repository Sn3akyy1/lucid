import "../lucidwidgets" as LW
import QtQuick
import qs
import qs.lucidui

// how fast the network moves, down and up, from the shell's one poller (Sys),
// held only while the panel is open. its looks: both rates over their last
// minute drawn as curves on one scale (graph); each rate on its own half with
// its own curve (split); the two rates on one line (line). a tap opens the
// Wi-Fi page
Item {
    id: nc

    // graph, split or line
    property string look: "graph"
    property bool live: false

    signal opened()

    // one tag per block, so two of them hold the poller apart
    readonly property string tag: "cc-net-" + Math.random().toString(36).slice(2, 8)
    readonly property bool line: nc.look === "line"
    readonly property bool split: nc.look === "split"
    // both curves on the scale of the busier, so they compare
    readonly property real peak: {
        let m = 0;
        for (const v of Sys.downHistory)
            m = Math.max(m, v);
        for (const v of Sys.upHistory)
            m = Math.max(m, v);
        return Math.max(m * 1.15, 65536);
    }

    function scaled(list, own) {
        let top = nc.peak;
        if (own) {
            top = 0;
            for (const v of list)
                top = Math.max(top, v);
            top = Math.max(top * 1.15, 16384);
        }
        return list.map((v) => {
            return v / top;
        });
    }

    onLiveChanged: Sys.hold(nc.tag, nc.live, 1000)
    Component.onCompleted: {
        if (nc.live)
            Sys.hold(nc.tag, true, 1000);

    }
    Component.onDestruction: Sys.hold(nc.tag, false)
    implicitHeight: nc.line ? Theme.dp(40) : Theme.dp(96)

    StateLayer {
        anchors.fill: parent
        anchors.margins: -Theme.dp(6)
        radius: Theme.shapeLg
        onClicked: nc.opened()
    }

    // on one line: down, then up, each after its arrow
    Row {
        visible: nc.line
        y: Math.round((parent.height - height) / 2)
        spacing: Theme.dp(16)

        Repeater {
            model: [["arrow_downward", Sys.netDown, Theme.primary], ["arrow_upward", Sys.netUp, Theme.tertiary]]

            Row {
                required property var modelData

                spacing: Theme.dp(4)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData[0]
                    size: Theme.dp(18)
                    color: modelData[2]
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "titleSmall"
                    weight: 620
                    tabular: true
                    text: Sys.rate(modelData[1])
                }

            }

        }

    }

    // a curve over the whole card: the two rates at its top, both lines under
    Item {
        visible: nc.look === "graph"
        anchors.fill: parent

        Row {
            id: rates

            spacing: Theme.dp(16)

            Repeater {
                model: [["arrow_downward", Sys.netDown, Theme.primary, "Down"], ["arrow_upward", Sys.netUp, Theme.tertiary, "Up"]]

                Column {
                    required property var modelData

                    spacing: -Theme.dp(2)

                    Row {
                        spacing: Theme.dp(2)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData[0]
                            size: Theme.dp(14)
                            color: modelData[2]
                        }

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelMedium"
                            color: Theme.subtext
                            text: modelData[3]
                        }

                    }

                    LText {
                        role: "titleMedium"
                        weight: 640
                        tabular: true
                        text: Sys.rate(modelData[1])
                    }

                }

            }

        }

        LW.Spark {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: rates.bottom
            anchors.topMargin: Theme.dp(6)
            anchors.bottom: parent.bottom
            samples: nc.scaled(Sys.downHistory, false)
            lineColor: Theme.primary
        }

        LW.Spark {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: rates.bottom
            anchors.topMargin: Theme.dp(6)
            anchors.bottom: parent.bottom
            samples: nc.scaled(Sys.upHistory, false)
            lineColor: Theme.tertiary
            filled: false
        }

    }

    // two halves, each its own rate over its own curve
    Row {
        visible: nc.split
        anchors.fill: parent
        spacing: Theme.dp(10)

        Repeater {
            model: [["arrow_downward", Sys.netDown, Theme.primary, "Down", Sys.downHistory], ["arrow_upward", Sys.netUp, Theme.tertiary, "Up", Sys.upHistory]]

            Rectangle {
                required property var modelData

                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: Theme.shapeMd
                color: Theme.alpha(modelData[2], 0.08)
                clip: true

                LW.Spark {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * 0.5
                    samples: nc.scaled(modelData[4], true)
                    lineColor: modelData[2]
                }

                Row {
                    x: Theme.dp(10)
                    y: Theme.dp(8)
                    spacing: Theme.dp(2)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData[0]
                        size: Theme.dp(14)
                        color: modelData[2]
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelMedium"
                        color: Theme.subtext
                        text: modelData[3]
                    }

                }

                LText {
                    x: Theme.dp(10)
                    y: Theme.dp(24)
                    role: "titleSmall"
                    weight: 640
                    tabular: true
                    text: Sys.rate(modelData[1])
                }

            }

        }

    }

}
